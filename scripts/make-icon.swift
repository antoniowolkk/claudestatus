// Renders the app icon to Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
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

    // Rounded light tile
    let inset = s * 0.09
    let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: tile, cornerWidth: s * 0.2, cornerHeight: s * 0.2, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor(red: 0.05, green: 0.3, blue: 0.8, alpha: 0.25).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(red: 0.985, green: 0.99, blue: 1, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Blueprint grid
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.setStrokeColor(NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 0.07).cgColor)
    ctx.setLineWidth(max(1, s / 512))
    var g = tile.minX
    while g < tile.maxX { ctx.move(to: CGPoint(x: g, y: tile.minY)); ctx.addLine(to: CGPoint(x: g, y: tile.maxY)); g += s / 16 }
    g = tile.minY
    while g < tile.maxY { ctx.move(to: CGPoint(x: tile.minX, y: g)); ctx.addLine(to: CGPoint(x: tile.maxX, y: g)); g += s / 16 }
    ctx.strokePath()
    ctx.restoreGState()

    // Gauge ring
    let c = CGPoint(x: s / 2, y: s / 2)
    let r = s * 0.27
    let lw = s * 0.055
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.08).cgColor)
    ctx.addArc(center: c, radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    let cyan = NSColor(red: 0, green: 0.76, blue: 0.86, alpha: 1)
    let blue = NSColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 1)
    let violet = NSColor(red: 0.45, green: 0.36, blue: 0.95, alpha: 1)
    let steps = 120
    let start = CGFloat.pi / 2
    let sweep = CGFloat.pi * 2 * 0.72
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps)
        let col = t < 0.5 ? cyan.blended(withFraction: t * 2, of: blue)! : blue.blended(withFraction: (t - 0.5) * 2, of: violet)!
        ctx.setStrokeColor(col.cgColor)
        ctx.addArc(center: c, radius: r, startAngle: start - sweep * t, endAngle: start - sweep * (t + 1.0 / CGFloat(steps)) - 0.002, clockwise: true)
        ctx.strokePath()
    }

    // Four-point spark in the middle
    let k = s * 0.12
    let spark = CGMutablePath()
    spark.move(to: CGPoint(x: c.x, y: c.y + k))
    spark.addQuadCurve(to: CGPoint(x: c.x + k, y: c.y), control: CGPoint(x: c.x + k * 0.15, y: c.y + k * 0.15))
    spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y - k), control: CGPoint(x: c.x + k * 0.15, y: c.y - k * 0.15))
    spark.addQuadCurve(to: CGPoint(x: c.x - k, y: c.y), control: CGPoint(x: c.x - k * 0.15, y: c.y - k * 0.15))
    spark.addQuadCurve(to: CGPoint(x: c.x, y: c.y + k), control: CGPoint(x: c.x - k * 0.15, y: c.y + k * 0.15))
    ctx.addPath(spark)
    ctx.setFillColor(blue.cgColor)
    ctx.fillPath()

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
