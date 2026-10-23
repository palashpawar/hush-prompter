// Renders the Hush app icon (1024x1024 PNG). Usage: swift scripts/make_icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// Work in top-left coordinates.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func gradient(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
}
func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// macOS icon grid: 824pt body inside the 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rounded(body, 186)

// Drop shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: rgb(0x000000, 0.45))
ctx.addPath(bodyPath)
ctx.setFillColor(rgb(0x0B0C1A))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()

// Background: deep indigo to near-black.
ctx.drawLinearGradient(gradient([rgb(0x34307A), rgb(0x16153A), rgb(0x08080F)], [0, 0.55, 1]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
// Warm glow spilling out from under the notch.
ctx.drawRadialGradient(gradient([rgb(0xFF8A5B, 0.55), rgb(0xFF4F8B, 0.18), rgb(0xFF4F8B, 0)], [0, 0.45, 1]),
                       startCenter: CGPoint(x: 512, y: 230), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 230), endRadius: 520, options: [])

// Soft glass sheen across the top half.
ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.10), rgb(0xFFFFFF, 0)], [0, 1]),
                       start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 520), options: [])

// Notch, flush with the top edge.
let notch = CGRect(x: 512 - 175, y: 60, width: 350, height: 160)
ctx.addPath(rounded(notch, 56))
ctx.setFillColor(rgb(0x000000))
ctx.fillPath()

// Camera lens.
let cam = CGPoint(x: 512, y: 168)
ctx.setFillColor(rgb(0x1A1C2E))
ctx.fillEllipse(in: CGRect(x: cam.x - 24, y: cam.y - 24, width: 48, height: 48))
ctx.setFillColor(rgb(0x05060C))
ctx.fillEllipse(in: CGRect(x: cam.x - 14, y: cam.y - 14, width: 28, height: 28))
ctx.setFillColor(rgb(0x7FD8FF, 0.9))
ctx.fillEllipse(in: CGRect(x: cam.x - 9, y: cam.y - 10, width: 8, height: 8))
// Tiny green "on" light.
ctx.setFillColor(rgb(0x5CFF9A))
ctx.fillEllipse(in: CGRect(x: cam.x + 46, y: cam.y - 6, width: 12, height: 12))

// Script lines: the current line glows warm, the rest fade away below.
let lines: [(CGFloat, CGFloat)] = [(560, 1.0), (470, 0.8), (520, 0.5), (380, 0.28), (450, 0.14)]
var y: CGFloat = 330
for (i, (w, alpha)) in lines.enumerated() {
    let h: CGFloat = i == 0 ? 64 : 54
    let r = CGRect(x: 512 - 280, y: y, width: w, height: h)
    let path = rounded(r, h / 2)
    if i == 0 {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 36, color: rgb(0xFF7A6B, 0.8))
        ctx.addPath(path)
        ctx.setFillColor(rgb(0xFF8A5B))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient([rgb(0xFFC56B), rgb(0xFF7A6B), rgb(0xFF4F9A)], [0, 0.5, 1]),
                               start: CGPoint(x: r.minX, y: 0), end: CGPoint(x: r.maxX, y: 0), options: [])
        ctx.restoreGState()
    } else {
        ctx.addPath(path)
        ctx.setFillColor(rgb(0xFFFFFF, alpha))
        ctx.fillPath()
    }
    y += h + 40
}

ctx.restoreGState()

// Hairline edge.
ctx.addPath(rounded(body.insetBy(dx: 1.5, dy: 1.5), 185))
ctx.setStrokeColor(rgb(0xFFFFFF, 0.12))
ctx.setLineWidth(3)
ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
