#!/usr/bin/env swift
import AppKit

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

func renderIcon(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
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
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let pixelSize = CGFloat(size)
    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let cornerRadius = pixelSize * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.98, alpha: 1.0),
        NSColor(calibratedRed: 0.05, green: 0.35, blue: 0.85, alpha: 1.0)
    ])!
    gradient.draw(in: rect, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: pixelSize * 0.58, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "icloud.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let tintedSymbol = NSImage(size: symbol.size, flipped: false) { rect in
            NSColor.white.set()
            rect.fill(using: .sourceOver)
            symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
            return true
        }
        let symbolSize = tintedSymbol.size
        let symbolRect = NSRect(
            x: (pixelSize - symbolSize.width) / 2,
            y: (pixelSize - symbolSize.height) / 2 - pixelSize * 0.02,
            width: symbolSize.width,
            height: symbolSize.height
        )
        tintedSymbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, to path: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed: \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for size in sizes {
    let rep = renderIcon(size: size)
    save(rep, to: "\(outputDir)/icon_\(size).png")
}
