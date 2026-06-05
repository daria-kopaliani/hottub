#!/usr/bin/env swift

import AppKit
import Foundation

// Usage: render-caption.swift <input.png> <output.png> <caption>
// Overlays a dark caption strip + white bold SF Pro Display text in the
// top portion of the image. Strip height adapts to caption length so a
// short caption gets a tighter strip.

guard CommandLine.arguments.count >= 4 else {
    FileHandle.standardError.write("Usage: render-caption.swift <input.png> <output.png> <caption>\n".data(using: .utf8)!)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let caption = CommandLine.arguments[3]

guard let inputImage = NSImage(contentsOfFile: inputPath),
      let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Failed to load \(inputPath)\n".data(using: .utf8)!)
    exit(2)
}

let width = CGFloat(cgImage.width)
let height = CGFloat(cgImage.height)

let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmapRep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

// Background: draw original screen
let imgRect = NSRect(x: 0, y: 0, width: width, height: height)
NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    .draw(in: imgRect)

// Caption strip in the top portion. Solid dark fill so the caption clearly
// separates from the dark-theme app content below it.
let stripHeight = height * 0.13
let stripRect = NSRect(x: 0, y: height - stripHeight, width: width, height: stripHeight)
NSColor.black.setFill()
stripRect.fill()

// Caption text
// Start with a font size that scales with image width, then shrink if the
// text overflows the available width — keeps single-line layout consistent.
let baseFontSize = width * 0.045
let horizontalPadding: CGFloat = width * 0.06
let maxTextWidth = width - 2 * horizontalPadding

func makeAttr(fontSize: CGFloat) -> NSAttributedString {
    let f = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    p.lineBreakMode = .byClipping
    return NSAttributedString(string: caption, attributes: [
        .font: f,
        .foregroundColor: NSColor.white,
        .paragraphStyle: p
    ])
}

var fontSize = baseFontSize
var attr = makeAttr(fontSize: fontSize)
var textSize = attr.size()
while textSize.width > maxTextWidth && fontSize > 20 {
    fontSize -= 1
    attr = makeAttr(fontSize: fontSize)
    textSize = attr.size()
}
let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

let textPointX = (width - textSize.width) / 2
let stripMidY = stripRect.origin.y + stripRect.height / 2

// Use Core Text with explicit baseline positioning. In a non-flipped CGContext,
// CTLineDraw with textPosition.y = baselineY places the baseline at baselineY
// and ascenders rise above (higher y = visually higher).
// For vertical centering of cap-height in the strip:
//   baseline = stripMidY - capHeight/2
let line = CTLineCreateWithAttributedString(attr)
let cgCtx = NSGraphicsContext.current!.cgContext
let baselineY = stripMidY - font.capHeight / 2
cgCtx.textPosition = CGPoint(x: textPointX, y: baselineY)
CTLineDraw(line, cgCtx)

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(3)
}

do {
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    FileHandle.standardError.write("Failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(4)
}
