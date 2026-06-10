#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appDirectory = rootURL.appendingPathComponent("App")
let masterURL = appDirectory.appendingPathComponent("HotblockIcon.png")
let iconsetURL = appDirectory.appendingPathComponent("Hotblock.iconset")
let icnsURL = appDirectory.appendingPathComponent("Hotblock.icns")
let canvasSize = 1024

func makeIcon(size: Int) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create icon bitmap")
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(size) / CGFloat(canvasSize)

    let tileRect = NSRect(
        x: 48 * scale,
        y: 48 * scale,
        width: 928 * scale,
        height: 928 * scale
    )
    let tile = NSBezierPath(
        roundedRect: tileRect,
        xRadius: 218 * scale,
        yRadius: 218 * scale
    )
    NSColor(calibratedRed: 217 / 255, green: 1, blue: 67 / 255, alpha: 1).setFill()
    tile.fill()
    NSColor(calibratedWhite: 17 / 255, alpha: 1).setStroke()
    tile.lineWidth = 20 * scale
    tile.stroke()

    guard let font = NSFont(name: "IowanOldStyle-Bold", size: 650 * scale) else {
        fatalError("Iowan Old Style Bold is not available")
    }

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedWhite: 17 / 255, alpha: 1),
    ]
    let letter = NSAttributedString(string: "H", attributes: attributes)
    let letterSize = letter.size()
    let letterOrigin = NSPoint(
        x: (CGFloat(size) - letterSize.width) / 2,
        y: (CGFloat(size) - letterSize.height) / 2 - 14 * scale
    )
    letter.draw(at: letterOrigin)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode icon PNG")
    }
    try png.write(to: url)
}

try? FileManager.default.removeItem(at: iconsetURL)
try? FileManager.default.removeItem(at: icnsURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try writePNG(makeIcon(size: canvasSize), to: masterURL)
for iconFile in iconFiles {
    let outputURL = iconsetURL.appendingPathComponent(iconFile.name)
    try writePNG(makeIcon(size: Int(iconFile.size)), to: outputURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

try FileManager.default.removeItem(at: iconsetURL)
print("Created \(masterURL.path)")
print("Created \(icnsURL.path)")
