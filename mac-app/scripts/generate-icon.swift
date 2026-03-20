#!/usr/bin/swift

import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Touchy.icns"
let fileManager = FileManager.default
let outputURL = URL(fileURLWithPath: outputPath)
let workingURL = outputURL.deletingLastPathComponent().appendingPathComponent("Touchy.iconbuild", isDirectory: true)

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try? fileManager.removeItem(at: workingURL)
try fileManager.createDirectory(at: workingURL, withIntermediateDirectories: true)

let iconSizes = [16, 32, 48, 128, 256, 512, 1024]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

let tealDark = color(13, 92, 93)
let teal = color(54, 181, 177)
let warmSand = color(240, 224, 181)
let orange = color(240, 158, 82)
let ink = color(23, 45, 54)
let whiteGlass = NSColor.white.withAlphaComponent(0.72)
let trackpadFill = color(244, 250, 247, 0.28)
let trackpadStroke = NSColor.white.withAlphaComponent(0.32)
let accent = color(255, 181, 65)

func drawIcon(side: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(side),
        pixelsHigh: Int(side),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    canvas.fill()

    let outer = NSBezierPath(roundedRect: canvas.insetBy(dx: side * 0.03, dy: side * 0.03), xRadius: side * 0.225, yRadius: side * 0.225)
    NSGradient(colors: [tealDark, teal, warmSand, orange])?
        .draw(in: outer, angle: -24)

    NSGraphicsContext.current?.cgContext.setShadow(
        offset: CGSize(width: 0, height: -side * 0.035),
        blur: side * 0.08,
        color: NSColor.black.withAlphaComponent(0.18).cgColor
    )
    outer.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)

    let glowRect = NSRect(x: side * 0.22, y: side * 0.16, width: side * 0.64, height: side * 0.64)
    let glow = NSBezierPath(ovalIn: glowRect)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.3), NSColor.white.withAlphaComponent(0.02)])?
        .draw(in: glow, relativeCenterPosition: NSPoint(x: -0.2, y: 0.4))

    let padRect = NSRect(x: side * 0.19, y: side * 0.22, width: side * 0.62, height: side * 0.58)

    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: side * 0.5, yBy: side * 0.5)
    transform.rotate(byDegrees: -13)
    transform.translateX(by: -side * 0.5, yBy: -side * 0.5)
    transform.concat()

    let padShadowPath = NSBezierPath(roundedRect: padRect.offsetBy(dx: 0, dy: -side * 0.02), xRadius: side * 0.11, yRadius: side * 0.11)
    NSGraphicsContext.current?.cgContext.setShadow(
        offset: CGSize(width: 0, height: -side * 0.02),
        blur: side * 0.05,
        color: ink.withAlphaComponent(0.24).cgColor
    )
    NSColor.black.withAlphaComponent(0.18).setFill()
    padShadowPath.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)

    let pad = NSBezierPath(roundedRect: padRect, xRadius: side * 0.11, yRadius: side * 0.11)
    NSGradient(colors: [trackpadFill, NSColor.white.withAlphaComponent(0.18)])?
        .draw(in: pad, angle: -18)
    trackpadStroke.setStroke()
    pad.lineWidth = max(2, side * 0.012)
    pad.stroke()

    let highlight = NSBezierPath(roundedRect: NSRect(x: padRect.minX + side * 0.03, y: padRect.midY + side * 0.08, width: padRect.width * 0.7, height: padRect.height * 0.14), xRadius: side * 0.05, yRadius: side * 0.05)
    NSColor.white.withAlphaComponent(0.18).setFill()
    highlight.fill()

    let touchRadius = side * 0.055
    let touchCenters = [
        NSPoint(x: padRect.minX + padRect.width * 0.27, y: padRect.minY + padRect.height * 0.64),
        NSPoint(x: padRect.minX + padRect.width * 0.47, y: padRect.minY + padRect.height * 0.55),
        NSPoint(x: padRect.minX + padRect.width * 0.67, y: padRect.minY + padRect.height * 0.44),
    ]

    for (index, center) in touchCenters.enumerated() {
        let alpha = 0.9 - CGFloat(index) * 0.12
        let circle = NSBezierPath(ovalIn: NSRect(x: center.x - touchRadius, y: center.y - touchRadius, width: touchRadius * 2, height: touchRadius * 2))
        NSGradient(colors: [whiteGlass.withAlphaComponent(alpha), NSColor.white.withAlphaComponent(0.35)])?
            .draw(in: circle, relativeCenterPosition: NSPoint(x: -0.2, y: 0.35))
    }

    let targetCenter = NSPoint(x: padRect.minX + padRect.width * 0.68, y: padRect.minY + padRect.height * 0.23)
    let outerRing = NSBezierPath(ovalIn: NSRect(x: targetCenter.x - side * 0.1, y: targetCenter.y - side * 0.1, width: side * 0.2, height: side * 0.2))
    accent.withAlphaComponent(0.8).setStroke()
    outerRing.lineWidth = max(2, side * 0.014)
    outerRing.stroke()

    let innerRing = NSBezierPath(ovalIn: NSRect(x: targetCenter.x - side * 0.055, y: targetCenter.y - side * 0.055, width: side * 0.11, height: side * 0.11))
    NSColor.white.withAlphaComponent(0.92).setFill()
    innerRing.fill()

    let centerDot = NSBezierPath(ovalIn: NSRect(x: targetCenter.x - side * 0.018, y: targetCenter.y - side * 0.018, width: side * 0.036, height: side * 0.036))
    accent.setFill()
    centerDot.fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    return rep
}

let tiffURL = workingURL.appendingPathComponent("Touchy.tiff")
let reps = iconSizes.map { drawIcon(side: CGFloat($0)) }
let image = NSImage(size: NSSize(width: 1024, height: 1024))
for rep in reps {
    image.addRepresentation(rep)
}
guard let tiffData = image.tiffRepresentation else {
    throw NSError(domain: "TouchyIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode TIFF"])
}
try tiffData.write(to: tiffURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/tiff2icns")
process.arguments = [tiffURL.path, outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "TouchyIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "tiff2icns failed"])
}

try? fileManager.removeItem(at: workingURL)
print("Wrote \(outputURL.path)")
