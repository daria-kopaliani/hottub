#!/usr/bin/env swift

import CryptoKit
import Foundation

// Reusable App Store Connect API client.
// Reads credentials from ~/.appstoreconnect/config + AuthKey_<KEY_ID>.p8.
//
// Subcommands:
//   list-apps                       — print Bundle ID + App ID for each app
//   list-versions <appId>           — print versions for an app
//   list-localizations <versionId>  — print locales for an app store version
//   upload-screenshots <bundleId>   — upload screenshots/<lang>/{iphone,ipad}/*.png
//                                     for the current editable version of the app

// MARK: - Config

let configDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".appstoreconnect")

func readConfig() -> (issuerID: String, keyID: String, p8Path: URL) {
    let configURL = configDir.appendingPathComponent("config")
    guard let content = try? String(contentsOf: configURL, encoding: .utf8) else {
        die("Missing config at \(configURL.path)")
    }
    var issuer: String?
    var keyID: String?
    for line in content.split(separator: "\n") {
        let kv = line.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard kv.count == 2 else { continue }
        switch kv[0] {
        case "ISSUER_ID": issuer = kv[1]
        case "KEY_ID": keyID = kv[1]
        default: break
        }
    }
    guard let iss = issuer, let kid = keyID else {
        die("config must define ISSUER_ID and KEY_ID")
    }
    let p8 = configDir.appendingPathComponent("AuthKey_\(kid).p8")
    guard FileManager.default.fileExists(atPath: p8.path) else {
        die("Missing private key at \(p8.path)")
    }
    return (iss, kid, p8)
}

// MARK: - JWT

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func generateJWT(issuerID: String, keyID: String, privateKey: P256.Signing.PrivateKey) throws -> String {
    let header: [String: String] = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
    let now = Int(Date().timeIntervalSince1970)
    let payload: [String: Any] = [
        "iss": issuerID,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1"
    ]
    let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
    let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let signingInput = "\(base64URL(headerData)).\(base64URL(payloadData))"
    let signature = try privateKey.signature(for: Data(signingInput.utf8))
    return "\(signingInput).\(base64URL(signature.rawRepresentation))"
}

func loadPrivateKey(p8Path: URL) throws -> P256.Signing.PrivateKey {
    let pem = try String(contentsOf: p8Path, encoding: .utf8)
    return try P256.Signing.PrivateKey(pemRepresentation: pem)
}

// MARK: - HTTP

let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!

func ascRequest(method: String, path: String, jwt: String, query: [String: String] = [:], body: Data? = nil) -> (Int, Data) {
    var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    if !query.isEmpty {
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    var request = URLRequest(url: components.url!)
    request.httpMethod = method
    request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    if body != nil {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
    }

    let semaphore = DispatchSemaphore(value: 0)
    var responseData = Data()
    var statusCode = 0
    let task = URLSession.shared.dataTask(with: request) { data, response, _ in
        if let http = response as? HTTPURLResponse { statusCode = http.statusCode }
        if let data { responseData = data }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    return (statusCode, responseData)
}

// MARK: - Util

func die(_ msg: String) -> Never {
    FileHandle.standardError.write("\(msg)\n".data(using: .utf8)!)
    exit(1)
}

func printJSON(_ data: Data) {
    if let obj = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
        print(String(data: pretty, encoding: .utf8) ?? "")
    } else {
        print(String(data: data, encoding: .utf8) ?? "<binary>")
    }
}

// MARK: - Subcommands

let (issuerID, keyID, p8Path) = readConfig()
let privateKey = try loadPrivateKey(p8Path: p8Path)
let jwt = try generateJWT(issuerID: issuerID, keyID: keyID, privateKey: privateKey)

guard CommandLine.arguments.count >= 2 else {
    die("Usage: asc-client.swift <list-apps|list-versions|list-localizations|upload-screenshots|upload-listing|create-locales|set-review-notes> [args...]")
}

let subcommand = CommandLine.arguments[1]

// MARK: - Upload helpers

struct VersionInPrep {
    let appID: String
    let versionID: String
    let versionString: String
}

func findVersionInPrep(bundleID: String) -> VersionInPrep {
    // 1. Look up app by bundleId
    let (s1, b1) = ascRequest(method: "GET", path: "/v1/apps", jwt: jwt,
                              query: ["filter[bundleId]": bundleID, "fields[apps]": "bundleId,name"])
    guard s1 == 200 else { printJSON(b1); die("Failed to list apps: HTTP \(s1)") }
    guard let json = try? JSONSerialization.jsonObject(with: b1) as? [String: Any],
          let data = json["data"] as? [[String: Any]],
          let first = data.first,
          let appID = first["id"] as? String else {
        die("Could not find app with bundle id \(bundleID)")
    }
    // 2. List versions, find the one in PREPARE_FOR_SUBMISSION
    let (s2, b2) = ascRequest(
        method: "GET",
        path: "/v1/apps/\(appID)/appStoreVersions",
        jwt: jwt,
        query: ["fields[appStoreVersions]": "versionString,appStoreState"]
    )
    guard s2 == 200 else { printJSON(b2); die("Failed to list versions: HTTP \(s2)") }
    guard let json2 = try? JSONSerialization.jsonObject(with: b2) as? [String: Any],
          let versions = json2["data"] as? [[String: Any]] else {
        die("Could not parse versions response")
    }
    for v in versions {
        if let attrs = v["attributes"] as? [String: Any],
           let state = attrs["appStoreState"] as? String,
           state == "PREPARE_FOR_SUBMISSION",
           let id = v["id"] as? String,
           let vstr = attrs["versionString"] as? String {
            return VersionInPrep(appID: appID, versionID: id, versionString: vstr)
        }
    }
    die("No version in PREPARE_FOR_SUBMISSION state")
}

struct LocalizationInfo {
    let id: String
    let locale: String
}

func listLocalizations(versionID: String) -> [LocalizationInfo] {
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations",
        jwt: jwt,
        query: ["fields[appStoreVersionLocalizations]": "locale", "limit": "50"]
    )
    guard status == 200 else { printJSON(body); die("Failed to list locales: HTTP \(status)") }
    guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let data = json["data"] as? [[String: Any]] else { die("Bad locales response") }
    return data.compactMap { item -> LocalizationInfo? in
        guard let id = item["id"] as? String,
              let attrs = item["attributes"] as? [String: Any],
              let locale = attrs["locale"] as? String else { return nil }
        return LocalizationInfo(id: id, locale: locale)
    }
}

// Map an ASC locale code to the local screenshots directory under apps/soak/screenshots/.
func localeToDir(_ locale: String) -> String {
    switch locale {
    case "en-US": return "en"
    case "de-DE": return "de"
    case "es-ES": return "es"
    case "es-MX": return "es"  // same content as es-ES per v1.1 decision
    case "fr-FR": return "fr"
    case "it": return "it"
    case "ja": return "ja"
    case "zh-Hans": return "zh-Hans"
    default: return locale  // fallback
    }
}

// Reverse of localeToDir: given a listings/ directory prefix, return the ASC locale code to create.
func dirToLocale(_ dir: String) -> String {
    switch dir {
    case "en": return "en-US"
    case "de": return "de-DE"
    case "es": return "es-ES"
    case "fr": return "fr-FR"
    case "it": return "it"
    case "ja": return "ja"
    case "zh-Hans": return "zh-Hans"
    default: return dir
    }
}

// ASC screenshotDisplayType enum values.
// 6.7" Pro Max bucket accepts 1320×2868 (iPhone 6.9") screenshots.
let iphoneDisplayType = "APP_IPHONE_67"
let ipadDisplayType = "APP_IPAD_PRO_3GEN_129"

// MARK: - Upload primitives

func md5Hex(_ data: Data) -> String {
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

// Existing screenshot set IDs for (localization, displayType)
func existingScreenshotSetIDs(localizationID: String, displayType: String) -> [String] {
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/appStoreVersionLocalizations/\(localizationID)/appScreenshotSets",
        jwt: jwt,
        query: ["fields[appScreenshotSets]": "screenshotDisplayType"]
    )
    guard status == 200,
          let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let data = json["data"] as? [[String: Any]] else { return [] }
    return data.compactMap { item -> String? in
        guard let attrs = item["attributes"] as? [String: Any],
              let dt = attrs["screenshotDisplayType"] as? String,
              dt == displayType,
              let id = item["id"] as? String else { return nil }
        return id
    }
}

func deleteScreenshotSet(_ id: String) -> Bool {
    let (status, _) = ascRequest(method: "DELETE", path: "/v1/appScreenshotSets/\(id)", jwt: jwt)
    return status == 204 || status == 200
}

func createScreenshotSet(localizationID: String, displayType: String) -> String {
    let payload: [String: Any] = [
        "data": [
            "type": "appScreenshotSets",
            "attributes": ["screenshotDisplayType": displayType],
            "relationships": [
                "appStoreVersionLocalization": [
                    "data": ["type": "appStoreVersionLocalizations", "id": localizationID]
                ]
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "POST", path: "/v1/appScreenshotSets", jwt: jwt, body: body)
    guard status == 201,
          let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String else {
        printJSON(resp); die("Failed to create screenshot set: HTTP \(status)")
    }
    return id
}

// POST /v1/appScreenshots with metadata; returns the new id + uploadOperations + sourceFileChecksum key
struct UploadOperation {
    let method: String
    let url: String
    let offset: Int
    let length: Int
    let headers: [(String, String)]
}

func reserveScreenshot(setID: String, fileName: String, fileSize: Int) -> (id: String, ops: [UploadOperation]) {
    let payload: [String: Any] = [
        "data": [
            "type": "appScreenshots",
            "attributes": [
                "fileSize": fileSize,
                "fileName": fileName
            ],
            "relationships": [
                "appScreenshotSet": [
                    "data": ["type": "appScreenshotSets", "id": setID]
                ]
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "POST", path: "/v1/appScreenshots", jwt: jwt, body: body)
    guard status == 201,
          let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String,
          let attrs = data["attributes"] as? [String: Any],
          let opsRaw = attrs["uploadOperations"] as? [[String: Any]] else {
        printJSON(resp); die("Failed to reserve screenshot: HTTP \(status)")
    }
    let ops: [UploadOperation] = opsRaw.compactMap { op in
        guard let m = op["method"] as? String,
              let u = op["url"] as? String,
              let off = op["offset"] as? Int,
              let len = op["length"] as? Int else { return nil }
        let headers = (op["requestHeaders"] as? [[String: String]] ?? []).compactMap { h -> (String, String)? in
            guard let name = h["name"], let value = h["value"] else { return nil }
            return (name, value)
        }
        return UploadOperation(method: m, url: u, offset: off, length: len, headers: headers)
    }
    return (id, ops)
}

func executeUpload(op: UploadOperation, fileData: Data) {
    var req = URLRequest(url: URL(string: op.url)!)
    req.httpMethod = op.method
    for (k, v) in op.headers { req.setValue(v, forHTTPHeaderField: k) }
    let slice = fileData.subdata(in: op.offset..<(op.offset + op.length))
    req.httpBody = slice
    let semaphore = DispatchSemaphore(value: 0)
    var status = 0
    var respData: Data = Data()
    let task = URLSession.shared.dataTask(with: req) { data, response, _ in
        if let http = response as? HTTPURLResponse { status = http.statusCode }
        respData = data ?? Data()
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    guard status >= 200 && status < 300 else {
        printJSON(respData)
        die("Upload op failed: HTTP \(status) for \(op.url)")
    }
}

func commitScreenshot(id: String, checksum: String) {
    let payload: [String: Any] = [
        "data": [
            "type": "appScreenshots",
            "id": id,
            "attributes": [
                "uploaded": true,
                "sourceFileChecksum": checksum
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "PATCH", path: "/v1/appScreenshots/\(id)", jwt: jwt, body: body)
    guard status == 200 else {
        printJSON(resp); die("Commit screenshot \(id) failed: HTTP \(status)")
    }
}

func screenshotsForLocale(_ loc: LocalizationInfo, dryRun: Bool) {
    let dir = localeToDir(loc.locale)
    let baseDir = "screenshots/\(dir)"

    print("---")
    print("[\(loc.locale)] (loc id=\(loc.id)) → \(baseDir)/")

    for (device, displayType) in [("iphone", iphoneDisplayType), ("ipad", ipadDisplayType)] {
        let devDir = "\(baseDir)/\(device)"
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: devDir).filter({ $0.hasSuffix(".png") }).sorted() else {
            print("  [\(device)] no files at \(devDir)")
            continue
        }
        print("  [\(device)] \(files.count) PNGs → \(displayType)")
        if dryRun {
            for f in files { print("    (dry-run) \(f)") }
            continue
        }

        // 1. Delete existing screenshot sets for this (locale, displayType)
        let existing = existingScreenshotSetIDs(localizationID: loc.id, displayType: displayType)
        for sid in existing {
            print("    delete existing set \(sid)")
            _ = deleteScreenshotSet(sid)
        }
        // 2. Create new screenshot set
        let setID = createScreenshotSet(localizationID: loc.id, displayType: displayType)
        print("    created set \(setID)")
        // 3. Upload each PNG
        for f in files {
            let path = "\(devDir)/\(f)"
            guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                print("    skip \(f) (unreadable)")
                continue
            }
            let checksum = md5Hex(fileData)
            let (ssID, ops) = reserveScreenshot(setID: setID, fileName: f, fileSize: fileData.count)
            for op in ops {
                executeUpload(op: op, fileData: fileData)
            }
            commitScreenshot(id: ssID, checksum: checksum)
            print("    uploaded \(f) (\(fileData.count) bytes, id=\(ssID))")
        }
    }
}

// MARK: - Listing text upload

func readListingFile(lang: String, field: String) -> String? {
    let path = "listings/\(lang)-\(field).txt"
    return try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
}

struct AppInfoLoc {
    let id: String
    let locale: String
}

func findEditableAppInfoID(appID: String) -> String {
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/apps/\(appID)/appInfos",
        jwt: jwt,
        query: ["fields[appInfos]": "appStoreState"]
    )
    guard status == 200,
          let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let data = json["data"] as? [[String: Any]] else {
        printJSON(body); die("Failed to list appInfos: HTTP \(status)")
    }
    for item in data {
        if let id = item["id"] as? String,
           let attrs = item["attributes"] as? [String: Any],
           let state = attrs["appStoreState"] as? String,
           state != "READY_FOR_SALE" {
            return id
        }
    }
    if let id = data.first?["id"] as? String { return id }
    die("No editable appInfo found")
}

func listAppInfoLocalizations(appInfoID: String) -> [AppInfoLoc] {
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/appInfos/\(appInfoID)/appInfoLocalizations",
        jwt: jwt,
        query: ["fields[appInfoLocalizations]": "locale", "limit": "50"]
    )
    guard status == 200,
          let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let data = json["data"] as? [[String: Any]] else {
        printJSON(body); die("Failed to list appInfoLocalizations: HTTP \(status)")
    }
    return data.compactMap { item -> AppInfoLoc? in
        guard let id = item["id"] as? String,
              let attrs = item["attributes"] as? [String: Any],
              let locale = attrs["locale"] as? String else { return nil }
        return AppInfoLoc(id: id, locale: locale)
    }
}

func patchAppInfoLocalization(id: String, attributes: [String: String]) {
    let payload: [String: Any] = [
        "data": [
            "type": "appInfoLocalizations",
            "id": id,
            "attributes": attributes
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "PATCH", path: "/v1/appInfoLocalizations/\(id)", jwt: jwt, body: body)
    guard status == 200 else { printJSON(resp); die("PATCH appInfoLocalization \(id) failed: HTTP \(status)") }
}

func patchVersionLocalization(id: String, attributes: [String: String]) {
    let payload: [String: Any] = [
        "data": [
            "type": "appStoreVersionLocalizations",
            "id": id,
            "attributes": attributes
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "PATCH", path: "/v1/appStoreVersionLocalizations/\(id)", jwt: jwt, body: body)
    guard status == 200 else { printJSON(resp); die("PATCH appStoreVersionLocalization \(id) failed: HTTP \(status)") }
}

// MARK: - Locale creation

// Scan ./listings/ for <dir>-name.txt files and return the unique dir prefixes ("en", "de", "es"...).
func listingLangDirs() -> [String] {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: "listings") else { return [] }
    var langs = Set<String>()
    for f in files {
        if f.hasSuffix("-name.txt") {
            let lang = String(f.dropLast("-name.txt".count))
            langs.insert(lang)
        }
    }
    return langs.sorted()
}

func createAppInfoLocalization(appInfoID: String, locale: String, name: String? = nil, subtitle: String? = nil) -> String? {
    var attributes: [String: String] = ["locale": locale]
    if let n = name, !n.isEmpty { attributes["name"] = n }
    if let s = subtitle, !s.isEmpty { attributes["subtitle"] = s }
    let payload: [String: Any] = [
        "data": [
            "type": "appInfoLocalizations",
            "attributes": attributes,
            "relationships": [
                "appInfo": ["data": ["type": "appInfos", "id": appInfoID]]
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "POST", path: "/v1/appInfoLocalizations", jwt: jwt, body: body)
    if status == 409 { return nil }  // already exists (from a partial earlier run) — skip
    guard status == 201,
          let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String else {
        printJSON(resp); die("POST appInfoLocalization \(locale) failed: HTTP \(status)")
    }
    return id
}

func createVersionLocalization(versionID: String, locale: String) -> String? {
    let payload: [String: Any] = [
        "data": [
            "type": "appStoreVersionLocalizations",
            "attributes": ["locale": locale],
            "relationships": [
                "appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "POST", path: "/v1/appStoreVersionLocalizations", jwt: jwt, body: body)
    if status == 409 { return nil }
    guard status == 201,
          let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String else {
        printJSON(resp); die("POST appStoreVersionLocalization \(locale) failed: HTTP \(status)")
    }
    return id
}

// MARK: - Review notes

// Read REVIEW_NOTES.md, strip the markdown header (everything up through the first "---" line),
// return the trimmed body.
func readReviewNotes(path: String = "REVIEW_NOTES.md") -> String {
    guard let content = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8) else {
        die("Missing \(path) in current directory")
    }
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    if let sepIdx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
        let body = lines[(sepIdx + 1)...].joined(separator: "\n")
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
}

// Get the existing appStoreReviewDetail id linked to a version, or nil.
func findReviewDetailID(versionID: String) -> String? {
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/appStoreVersions/\(versionID)/appStoreReviewDetail",
        jwt: jwt
    )
    guard status == 200,
          let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String else {
        return nil
    }
    return id
}

func patchReviewDetail(id: String, notes: String) {
    let payload: [String: Any] = [
        "data": [
            "type": "appStoreReviewDetails",
            "id": id,
            "attributes": ["notes": notes]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "PATCH", path: "/v1/appStoreReviewDetails/\(id)", jwt: jwt, body: body)
    guard status == 200 else { printJSON(resp); die("PATCH appStoreReviewDetail \(id) failed: HTTP \(status)") }
}

func createReviewDetail(versionID: String, notes: String) -> String {
    let payload: [String: Any] = [
        "data": [
            "type": "appStoreReviewDetails",
            "attributes": ["notes": notes],
            "relationships": [
                "appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]
            ]
        ]
    ]
    let body = try! JSONSerialization.data(withJSONObject: payload)
    let (status, resp) = ascRequest(method: "POST", path: "/v1/appStoreReviewDetails", jwt: jwt, body: body)
    guard status == 201,
          let json = try? JSONSerialization.jsonObject(with: resp) as? [String: Any],
          let data = json["data"] as? [String: Any],
          let id = data["id"] as? String else {
        printJSON(resp); die("POST appStoreReviewDetail failed: HTTP \(status)")
    }
    return id
}

// MARK: - Subcommands

switch subcommand {
case "list-apps":
    let (status, body) = ascRequest(method: "GET", path: "/v1/apps", jwt: jwt,
                                    query: ["fields[apps]": "bundleId,name", "limit": "100"])
    print("HTTP \(status)")
    printJSON(body)

case "list-versions":
    guard CommandLine.arguments.count >= 3 else { die("Usage: list-versions <appId>") }
    let appID = CommandLine.arguments[2]
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/apps/\(appID)/appStoreVersions",
        jwt: jwt,
        query: ["fields[appStoreVersions]": "versionString,appStoreState,platform", "limit": "10"]
    )
    print("HTTP \(status)")
    printJSON(body)

case "list-localizations":
    guard CommandLine.arguments.count >= 3 else { die("Usage: list-localizations <versionId>") }
    let versionID = CommandLine.arguments[2]
    let (status, body) = ascRequest(
        method: "GET",
        path: "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations",
        jwt: jwt,
        query: ["fields[appStoreVersionLocalizations]": "locale", "limit": "50"]
    )
    print("HTTP \(status)")
    printJSON(body)

case "upload-screenshots":
    guard CommandLine.arguments.count >= 3 else { die("Usage: upload-screenshots <bundleId> [--dry-run] [--only <locale>]") }
    let bundleID = CommandLine.arguments[2]
    let dryRun = CommandLine.arguments.contains("--dry-run")
    var onlyLocale: String? = nil
    if let i = CommandLine.arguments.firstIndex(of: "--only"),
       i + 1 < CommandLine.arguments.count {
        onlyLocale = CommandLine.arguments[i + 1]
    }

    let version = findVersionInPrep(bundleID: bundleID)
    print("Found app=\(version.appID) version=\(version.versionString) (\(version.versionID)) state=PREPARE_FOR_SUBMISSION")
    print(dryRun ? "MODE: DRY RUN (no writes)" : "MODE: LIVE (will create screenshot sets + upload PNGs)")

    let locales = listLocalizations(versionID: version.versionID)
    print("Found \(locales.count) localizations: \(locales.map { $0.locale }.joined(separator: ", "))")

    let filtered = onlyLocale.map { o in locales.filter { $0.locale == o } } ?? locales
    if let o = onlyLocale {
        print("Filtering to locale=\(o) (\(filtered.count) match)")
    }
    for loc in filtered.sorted(by: { $0.locale < $1.locale }) {
        screenshotsForLocale(loc, dryRun: dryRun)
    }

case "upload-listing":
    guard CommandLine.arguments.count >= 3 else { die("Usage: upload-listing <bundleId> [--dry-run] [--only <locale>] [--skip-whats-new]") }
    let bundleID = CommandLine.arguments[2]
    let dryRun = CommandLine.arguments.contains("--dry-run")
    // whatsNew can't be set on initial-release versions (no prior version users would see it).
    // Pass --skip-whats-new for v1.0 first submission.
    let skipWhatsNew = CommandLine.arguments.contains("--skip-whats-new")
    var onlyLocale: String? = nil
    if let i = CommandLine.arguments.firstIndex(of: "--only"),
       i + 1 < CommandLine.arguments.count {
        onlyLocale = CommandLine.arguments[i + 1]
    }

    let version = findVersionInPrep(bundleID: bundleID)
    print("Found app=\(version.appID) version=\(version.versionString) (\(version.versionID))")
    print(dryRun ? "MODE: DRY RUN" : "MODE: LIVE (PATCHes ASC localizations)")

    let appInfoID = findEditableAppInfoID(appID: version.appID)
    print("Editable appInfo: \(appInfoID)")

    let appInfoLocs = listAppInfoLocalizations(appInfoID: appInfoID)
    let versionLocs = listLocalizations(versionID: version.versionID)

    let allLocales = Set(appInfoLocs.map { $0.locale }).union(versionLocs.map { $0.locale }).sorted()
    let target = onlyLocale.map { o in allLocales.filter { $0 == o } } ?? allLocales
    if let o = onlyLocale { print("Filtering to locale=\(o)") }

    // Global URLs (same content across all locales unless per-locale file overrides).
    let globalPrivacyURL = (try? String(contentsOf: URL(fileURLWithPath: "listings/privacy-url.txt"), encoding: .utf8)) ?? ""
    let globalSupportURL = (try? String(contentsOf: URL(fileURLWithPath: "listings/support-url.txt"), encoding: .utf8)) ?? ""

    for locale in target {
        let lang = localeToDir(locale)
        print("---")
        print("[\(locale)] ← listings/\(lang)-*.txt")

        // Page 1: name + subtitle + privacyPolicyUrl → appInfoLocalization
        var infoAttrs: [String: String] = [:]
        if let name = readListingFile(lang: lang, field: "name") { infoAttrs["name"] = name }
        if let subtitle = readListingFile(lang: lang, field: "subtitle") { infoAttrs["subtitle"] = subtitle }
        let perLocalePrivacy = readListingFile(lang: lang, field: "privacy-url") ?? globalPrivacyURL
        if !perLocalePrivacy.isEmpty { infoAttrs["privacyPolicyUrl"] = perLocalePrivacy }
        if !infoAttrs.isEmpty,
           let infoLoc = appInfoLocs.first(where: { $0.locale == locale }) {
            print("  → appInfoLocalization \(infoLoc.id):")
            for (k, v) in infoAttrs { print("    \(k) (\(v.count) chars)") }
            if !dryRun { patchAppInfoLocalization(id: infoLoc.id, attributes: infoAttrs) }
        }

        // Page 2: description + keywords + promotionalText + whatsNew + supportUrl → appStoreVersionLocalization
        var verAttrs: [String: String] = [:]
        if let desc = readListingFile(lang: lang, field: "description") { verAttrs["description"] = desc }
        if let kw = readListingFile(lang: lang, field: "keywords") { verAttrs["keywords"] = kw }
        if let promo = readListingFile(lang: lang, field: "promo") { verAttrs["promotionalText"] = promo }
        if !skipWhatsNew, let wn = readListingFile(lang: lang, field: "whats-new") { verAttrs["whatsNew"] = wn }
        let perLocaleSupport = readListingFile(lang: lang, field: "support-url") ?? globalSupportURL
        if !perLocaleSupport.isEmpty { verAttrs["supportUrl"] = perLocaleSupport }
        if !verAttrs.isEmpty,
           let verLoc = versionLocs.first(where: { $0.locale == locale }) {
            print("  → appStoreVersionLocalization \(verLoc.id):")
            for (k, v) in verAttrs { print("    \(k) (\(v.count) chars)") }
            if !dryRun { patchVersionLocalization(id: verLoc.id, attributes: verAttrs) }
        }
    }

case "create-locales":
    guard CommandLine.arguments.count >= 3 else { die("Usage: create-locales <bundleId> [--dry-run]") }
    let bundleID = CommandLine.arguments[2]
    let dryRun = CommandLine.arguments.contains("--dry-run")

    let version = findVersionInPrep(bundleID: bundleID)
    print("Found app=\(version.appID) version=\(version.versionString) (\(version.versionID))")
    print(dryRun ? "MODE: DRY RUN" : "MODE: LIVE (will POST missing localizations)")

    let appInfoID = findEditableAppInfoID(appID: version.appID)
    let existingInfoLocs = Set(listAppInfoLocalizations(appInfoID: appInfoID).map { $0.locale })
    let existingVerLocs = Set(listLocalizations(versionID: version.versionID).map { $0.locale })

    let langDirs = listingLangDirs()
    print("Local listings/ dirs: \(langDirs.joined(separator: ", "))")

    for dir in langDirs {
        let locale = dirToLocale(dir)
        var created: [String] = []
        if !existingInfoLocs.contains(locale) {
            if dryRun {
                created.append("appInfoLocalization")
            } else {
                // Apple now requires `name` at creation time (formerly optional). Subtitle is
                // optional but cheap to pass since we have it.
                let perLocaleName = readListingFile(lang: dir, field: "name")
                let perLocaleSubtitle = readListingFile(lang: dir, field: "subtitle")
                if let id = createAppInfoLocalization(appInfoID: appInfoID, locale: locale, name: perLocaleName, subtitle: perLocaleSubtitle) {
                    created.append("appInfoLocalization=\(id)")
                } else {
                    created.append("appInfoLocalization=(409 already-exists)")
                }
            }
        }
        if !existingVerLocs.contains(locale) {
            if dryRun {
                created.append("appStoreVersionLocalization")
            } else {
                if let id = createVersionLocalization(versionID: version.versionID, locale: locale) {
                    created.append("appStoreVersionLocalization=\(id)")
                } else {
                    created.append("appStoreVersionLocalization=(409 already-exists)")
                }
            }
        }
        if created.isEmpty {
            print("[\(dir) → \(locale)] already present")
        } else {
            print("[\(dir) → \(locale)] \(dryRun ? "WOULD CREATE" : "created"): \(created.joined(separator: ", "))")
        }
    }

case "set-review-notes":
    guard CommandLine.arguments.count >= 3 else { die("Usage: set-review-notes <bundleId> [--dry-run] [--file <path>]") }
    let bundleID = CommandLine.arguments[2]
    let dryRun = CommandLine.arguments.contains("--dry-run")
    var notesPath = "REVIEW_NOTES.md"
    if let i = CommandLine.arguments.firstIndex(of: "--file"), i + 1 < CommandLine.arguments.count {
        notesPath = CommandLine.arguments[i + 1]
    }

    let version = findVersionInPrep(bundleID: bundleID)
    print("Found app=\(version.appID) version=\(version.versionString) (\(version.versionID))")
    let notes = readReviewNotes(path: notesPath)
    print("Notes from \(notesPath): \(notes.count) chars")
    print(dryRun ? "MODE: DRY RUN" : "MODE: LIVE")
    if dryRun {
        print("---preview---")
        print(notes)
        print("---/preview---")
    } else {
        if let id = findReviewDetailID(versionID: version.versionID) {
            print("PATCH existing appStoreReviewDetail \(id)")
            patchReviewDetail(id: id, notes: notes)
        } else {
            let id = createReviewDetail(versionID: version.versionID, notes: notes)
            print("CREATED appStoreReviewDetail \(id)")
        }
    }

default:
    die("Unknown subcommand: \(subcommand)")
}
