// Renders the Copiest logo: a clipboard holding a stack of copied lines.
// Usage: swift scripts/make-icon.swift
// Writes Resources/AppIcon.icns and docs/logo.png.
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// Draws the logo into a 1024 x 1024 canvas with a top-left origin.
func drawLogo() {
    // Background: macOS icon grid content area (824 pt) with a blue gradient.
    let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(starting: color(0x5AA9FF), ending: color(0x1F4FC9))!.draw(in: bg, angle: 90)

    // Clipboard board with the clip on top.
    color(0xF4F8FF).setFill()
    NSBezierPath(roundedRect: NSRect(x: 282, y: 250, width: 460, height: 560), xRadius: 56, yRadius: 56).fill()
    color(0x173C99).setFill()
    NSBezierPath(roundedRect: NSRect(x: 402, y: 204, width: 220, height: 110), xRadius: 32, yRadius: 32).fill()

    // Lines of copied text, each a little shorter.
    let ink = color(0x2F66E0)
    ink.setStroke()
    for (i, width) in [300.0, 260.0, 300.0, 180.0].enumerated() {
        let line = NSBezierPath()
        line.lineWidth = 34
        line.lineCapStyle = .round
        let y = 410.0 + Double(i) * 92
        line.move(to: NSPoint(x: 362, y: y)); line.line(to: NSPoint(x: 362 + width, y: y))
        line.stroke()
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let scale = CGFloat(size) / 1024
    // Flip so the drawing code can use a top-left origin.
    ctx.cgContext.translateBy(x: 0, y: CGFloat(size))
    ctx.cgContext.scaleBy(x: scale, y: -scale)
    drawLogo()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
try! fm.createDirectory(atPath: "docs", withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try! png(size: 512).write(to: URL(fileURLWithPath: "docs/logo.png"))
print("Wrote Resources/AppIcon.icns and docs/logo.png")
