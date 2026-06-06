import AppKit
import Foundation

let scriptURL = URL(fileURLWithPath: #filePath)
let repositoryRoot = scriptURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let packagingURL = repositoryRoot.appendingPathComponent("packaging")
let iconsetURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("SpacesRenamer-\(UUID().uuidString).iconset")
let icnsURL = packagingURL.appendingPathComponent("SpacesRenamer.icns")

let iconSizes: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let scale = CGFloat(size) / 1024
    let canvas = NSRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    NSColor.clear.setFill()
    canvas.fill()

    let tileRect = NSRect(
        x: 116 * scale,
        y: 96 * scale,
        width: 792 * scale,
        height: 792 * scale
    )
    let tileRadius = 158 * scale
    let tilePath = roundedRect(tileRect, radius: tileRadius)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 36 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.set()

    NSGradient(
        starting: NSColor(calibratedWhite: 1.0, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.92, green: 0.94, blue: 1.0, alpha: 1.0)
    )?.draw(in: tilePath, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.88).setStroke()
    tilePath.lineWidth = 4.5 * scale
    tilePath.stroke()

    let innerStroke = roundedRect(tileRect.insetBy(dx: 7 * scale, dy: 7 * scale), radius: tileRadius - 7 * scale)
    NSColor(calibratedRed: 0.42, green: 0.54, blue: 0.82, alpha: 0.16).setStroke()
    innerStroke.lineWidth = 3 * scale
    innerStroke.stroke()

    let markRect = NSRect(
        x: 272 * scale,
        y: 274 * scale,
        width: 480 * scale,
        height: 514 * scale
    )
    let markPath = NSBezierPath()
    markPath.move(to: NSPoint(x: markRect.minX + 10 * scale, y: markRect.minY + 112 * scale))
    markPath.curve(
        to: NSPoint(x: markRect.midX, y: markRect.minY + 108 * scale),
        controlPoint1: NSPoint(x: markRect.minX + 95 * scale, y: markRect.minY + 156 * scale),
        controlPoint2: NSPoint(x: markRect.midX - 88 * scale, y: markRect.minY + 132 * scale)
    )
    markPath.curve(
        to: NSPoint(x: markRect.maxX - 10 * scale, y: markRect.minY + 112 * scale),
        controlPoint1: NSPoint(x: markRect.midX + 88 * scale, y: markRect.minY + 132 * scale),
        controlPoint2: NSPoint(x: markRect.maxX - 96 * scale, y: markRect.minY + 156 * scale)
    )
    markPath.curve(
        to: NSPoint(x: markRect.midX, y: markRect.maxY),
        controlPoint1: NSPoint(x: markRect.maxX - 3 * scale, y: markRect.minY + 350 * scale),
        controlPoint2: NSPoint(x: markRect.maxX - 126 * scale, y: markRect.maxY)
    )
    markPath.curve(
        to: NSPoint(x: markRect.minX + 10 * scale, y: markRect.minY + 112 * scale),
        controlPoint1: NSPoint(x: markRect.minX + 126 * scale, y: markRect.maxY),
        controlPoint2: NSPoint(x: markRect.minX + 3 * scale, y: markRect.minY + 350 * scale)
    )
    markPath.close()

    NSGraphicsContext.current?.saveGraphicsState()
    let markShadow = NSShadow()
    markShadow.shadowBlurRadius = 12 * scale
    markShadow.shadowOffset = NSSize(width: 0, height: -5 * scale)
    markShadow.shadowColor = NSColor(calibratedRed: 0.1, green: 0.24, blue: 0.42, alpha: 0.22)
    markShadow.set()

    NSGradient(colorsAndLocations:
        (NSColor(calibratedRed: 0.07, green: 0.28, blue: 0.78, alpha: 1.0), 0.0),
        (NSColor(calibratedRed: 0.50, green: 0.74, blue: 0.97, alpha: 1.0), 0.34),
        (NSColor(calibratedRed: 0.99, green: 0.86, blue: 0.37, alpha: 1.0), 0.63),
        (NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.38, alpha: 1.0), 1.0)
    )?.draw(in: markPath, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    let shinePath = markPath.copy() as! NSBezierPath
    NSGraphicsContext.current?.saveGraphicsState()
    shinePath.addClip()
    let shineRect = NSRect(
        x: markRect.minX + 46 * scale,
        y: markRect.minY + 356 * scale,
        width: markRect.width - 92 * scale,
        height: 112 * scale
    )
    NSGradient(
        starting: NSColor.white.withAlphaComponent(0.30),
        ending: NSColor.white.withAlphaComponent(0.0)
    )?.draw(in: shineRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func writePNG(image: NSImage, size: Int, to url: URL) throws {
    guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        throw NSError(domain: "SpacesRenamerIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not create CGImage for \(size)px icon."
        ])
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    bitmap.size = NSSize(width: size, height: size)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "SpacesRenamerIcon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode \(size)px icon as PNG."
        ])
    }

    try data.write(to: url)
}

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer {
    try? FileManager.default.removeItem(at: iconsetURL)
}

for icon in iconSizes {
    let image = drawIcon(size: icon.size)
    try writePNG(
        image: image,
        size: icon.size,
        to: iconsetURL.appendingPathComponent(icon.name)
    )
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconsetURL.path,
    "-o", icnsURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "SpacesRenamerIcon", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "iconutil failed with status \(process.terminationStatus)."
    ])
}

print("Generated \(icnsURL.path)")
