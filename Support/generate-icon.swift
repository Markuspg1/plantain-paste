// Renders the 1024x1024 master PNG for the app icon.
// Usage: swift Support/generate-icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon_1024.png"
let canvas: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas),
    pixelsHigh: Int(canvas),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS-style squircle tile with a margin, indigo→purple gradient.
let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(
    starting: NSColor(calibratedRed: 0.30, green: 0.44, blue: 0.98, alpha: 1),
    ending: NSColor(calibratedRed: 0.52, green: 0.20, blue: 0.90, alpha: 1)
)!.draw(in: tilePath, angle: -70)

// White clipboard glyph, centered.
let config = NSImage.SymbolConfiguration(pointSize: 400, weight: .medium)
if let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let maxSide: CGFloat = 470
    let scale = maxSide / max(tinted.size.width, tinted.size.height)
    let w = tinted.size.width * scale
    let h = tinted.size.height * scale
    tinted.draw(
        in: NSRect(x: (canvas - w) / 2, y: (canvas - h) / 2, width: w, height: h),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
}

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
