// Renders the TrayOps app icon (a "switch.2"-style toggle motif on a gradient
// tile) into a macOS `.iconset` directory. Run via `scripts/generate-icon.sh`,
// which then assembles the `.icns` with `iconutil`. No Xcode required.
//
// Usage: swift scripts/generate-icon.swift <output-iconset-dir>

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func makeIcon(size: CGFloat) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Rounded-rect tile (macOS squircle-ish corner) clipped for the gradient.
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.2237
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()

    let colors = [
        CGColor(srgbRed: 0.37, green: 0.36, blue: 0.90, alpha: 1.0), // indigo
        CGColor(srgbRed: 0.19, green: 0.69, blue: 0.78, alpha: 1.0), // teal
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

    // Two toggle "pills": top is on (knob right), bottom is off (knob left).
    func toggle(centerY: CGFloat, knobRight: Bool) {
        let width = size * 0.50
        let height = size * 0.155
        let r = height / 2
        let track = CGRect(x: size * 0.5 - width / 2, y: centerY - height / 2, width: width, height: height)
        context.addPath(CGPath(roundedRect: track, cornerWidth: r, cornerHeight: r, transform: nil))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.30))
        context.fillPath()

        let knobDiameter = height * 0.72
        let knobX = knobRight ? (track.maxX - r) : (track.minX + r)
        context.addEllipse(in: CGRect(
            x: knobX - knobDiameter / 2,
            y: centerY - knobDiameter / 2,
            width: knobDiameter,
            height: knobDiameter
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
        context.fillPath()
    }

    toggle(centerY: size * 0.5 + size * 0.135, knobRight: true)
    toggle(centerY: size * 0.5 - size * 0.135, knobRight: false)

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <output-iconset-dir>\n".utf8))
    exit(2)
}
let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// (filename, pixel size) entries required by an .iconset.
let entries: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in entries {
    writePNG(makeIcon(size: pixels), to: outputDir.appendingPathComponent(name))
}
print("Wrote \(entries.count) PNGs to \(outputDir.path)")
