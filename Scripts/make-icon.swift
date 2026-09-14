// Renders DayPeek's app icon (1024×1024 PNG) with CoreGraphics — headless, no
// Xcode, no image assets. A blue squircle with a white card holding three
// checklist rows; the first row is ticked.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let S: CGFloat = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(S), height: Int(S),
    bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }

// Squircle background, vertical blue gradient.
let margin: CGFloat = 92
let bgRect = CGRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 190, cornerHeight: 190, transform: nil)
ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(84, 160, 255), rgb(10, 96, 230)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// White card.
let card = CGRect(x: 232, y: 248, width: 560, height: 528)
let cardPath = CGPath(roundedRect: card, cornerWidth: 64, cornerHeight: 64, transform: nil)
ctx.addPath(cardPath); ctx.setFillColor(rgb(255, 255, 255)); ctx.fillPath()

// Three checklist rows: circle + line. First row ticked in blue, others grey.
let rowYs: [CGFloat] = [card.maxY - 132, card.midY, card.minY + 132]
let circleX = card.minX + 96
let radius: CGFloat = 42
for (i, cy) in rowYs.enumerated() {
    let ticked = (i == 0)
    let color = ticked ? rgb(10, 96, 230) : rgb(196, 198, 205)
    let circle = CGRect(x: circleX - radius, y: cy - radius, width: radius * 2, height: radius * 2)
    if ticked {
        ctx.addPath(CGPath(ellipseIn: circle, transform: nil))
        ctx.setFillColor(color); ctx.fillPath()
        ctx.setStrokeColor(rgb(255, 255, 255)); ctx.setLineWidth(14)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: circleX - 20, y: cy - 2))
        ctx.addLine(to: CGPoint(x: circleX - 5, y: cy - 17))
        ctx.addLine(to: CGPoint(x: circleX + 22, y: cy + 16))
        ctx.strokePath()
    } else {
        ctx.addPath(CGPath(ellipseIn: circle.insetBy(dx: 6, dy: 6), transform: nil))
        ctx.setStrokeColor(color); ctx.setLineWidth(12); ctx.strokePath()
    }
    let lineX = circleX + radius + 48
    let lineW: CGFloat = ticked ? 300 : (i == 1 ? 340 : 240)
    ctx.addPath(CGPath(roundedRect: CGRect(x: lineX, y: cy - 16, width: lineW, height: 32),
                       cornerWidth: 16, cornerHeight: 16, transform: nil))
    ctx.setFillColor(ticked ? rgb(196, 198, 205) : rgb(60, 60, 67)); ctx.fillPath()
}

// Write PNG.
guard let img = ctx.makeImage() else { fatalError("no image") }
let dir = URL(fileURLWithPath: ".build/icon", isDirectory: true)
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let out = dir.appendingPathComponent("DayPeek-1024.png")
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("no destination")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(out.path)")
