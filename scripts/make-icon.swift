// Renders the app icon (Wolkky on a light tile) to Resources/AppIcon.icns and docs/icon.png.
// Usage: swift scripts/make-icon.swift   (run scripts/prepare-image.swift first)
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
guard let mascot = NSImage(contentsOf: root.appendingPathComponent("Resources/Wolkky.png")) else {
    print("Missing Resources/Wolkky.png — run scripts/prepare-image.swift first"); exit(1)
}
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Light sky tile
    let inset = s * 0.09
    let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: tile, cornerWidth: s * 0.2, cornerHeight: s * 0.2, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor(red: 0.05, green: 0.3, blue: 0.8, alpha: 0.22).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [NSColor(red: 0.80, green: 0.91, blue: 1.0, alpha: 1).cgColor,
                                  NSColor(red: 0.97, green: 0.99, blue: 1.0, alpha: 1).cgColor] as CFArray,
                         locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: tile.minY), end: CGPoint(x: 0, y: tile.maxY), options: [])
    ctx.restoreGState()

    // Wolkky, centered
    let maxW = tile.width * 0.74
    let ratio = mascot.size.height / mascot.size.width
    let mw = maxW, mh = maxW * ratio
    mascot.draw(in: CGRect(x: (s - mw) / 2, y: (s - mh) / 2 - s * 0.01, width: mw, height: mh))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try p.run()
p.waitUntilExit()
try draw(512).write(to: root.appendingPathComponent("docs/icon.png"))
print("✓ \(out.path)")
