#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"
let variant = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "light"

let topColor: NSColor
let bottomColor: NSColor
let symbolColor: NSColor

switch variant {
case "dark":
    topColor = NSColor(srgbRed: 0.08, green: 0.22, blue: 0.35, alpha: 1.0)
    bottomColor = NSColor(srgbRed: 0.02, green: 0.10, blue: 0.20, alpha: 1.0)
    symbolColor = .white
case "tinted":
    topColor = NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
    bottomColor = NSColor(srgbRed: 0.04, green: 0.04, blue: 0.04, alpha: 1.0)
    symbolColor = .white
default:
    topColor = NSColor(srgbRed: 0.42, green: 0.80, blue: 0.95, alpha: 1.0)
    bottomColor = NSColor(srgbRed: 0.01, green: 0.45, blue: 0.72, alpha: 1.0)
    symbolColor = .white
}

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Cannot create CGContext")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

let gradient = NSGradient(colors: [topColor, bottomColor])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// "♨︎" with text variation selector forces monochrome text rendering instead of color emoji.
let symbol = "♨\u{FE0E}"
let fontSize: CGFloat = 720
let font = NSFont(name: "Apple Symbols", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize, weight: .medium)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: symbolColor
]
let attrString = NSAttributedString(string: symbol, attributes: attributes)

let textSize = attrString.size()
let drawRect = NSRect(
    x: (size - textSize.width) / 2,
    y: (size - textSize.height) / 2 - fontSize * 0.10,
    width: textSize.width,
    height: textSize.height
)
attrString.draw(in: drawRect)

NSGraphicsContext.restoreGraphicsState()

guard let cgImage = context.makeImage() else {
    fatalError("Cannot make CGImage")
}
let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode PNG")
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(pngData.count) bytes to \(outputPath)")
