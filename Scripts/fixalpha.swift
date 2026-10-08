import AppKit
import CoreGraphics
import Foundation

// 用 SVG 背景圆角矩形的几何信息，把 qlmanage 渲染出的不透明白底裁成透明角。
// 输入: src, 输出: dst, 参数: x y w h radius scale(与实际像素的比值)

guard CommandLine.arguments.count >= 8 else {
    print("用法: fixalpha <src> <dst> <x> <y> <w> <h> <radius>")
    exit(1)
}
let srcPath = CommandLine.arguments[1]
let dstPath = CommandLine.arguments[2]
let rx = Double(CommandLine.arguments[3])!
let ry = Double(CommandLine.arguments[4])!
let rw = Double(CommandLine.arguments[5])!
let rh = Double(CommandLine.arguments[6])!
let rr = Double(CommandLine.arguments[7])!

guard let image = NSImage(contentsOfFile: srcPath),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("无法读取 \(srcPath)"); exit(1)
}

let w = cgImage.width
let h = cgImage.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

// SVG 是 1024 画布，实际渲染尺寸可能不同，按比例换算。
let scale = Double(w) / 1024.0
let bx = rx * scale, by = ry * scale, bw = rw * scale, bh = rh * scale, br = rr * scale

func inside(_ px: Double, _ py: Double) -> Bool {
    let minX = bx, maxX = bx + bw, minY = by, maxY = by + bh
    if px < minX || px > maxX || py < minY || py > maxY { return false }
    // 四个圆角区域
    let cx: Double, cy: Double
    if px < minX + br && py < minY + br { cx = minX + br; cy = minY + br }
    else if px > maxX - br && py < minY + br { cx = maxX - br; cy = minY + br }
    else if px < minX + br && py > maxY - br { cx = minX + br; cy = maxY - br }
    else if px > maxX - br && py > maxY - br { cx = maxX - br; cy = maxY - br }
    else { return true }
    let dx = px - cx, dy = py - cy
    return dx * dx + dy * dy <= br * br
}

// 4x4 超采样求覆盖率，得到平滑边缘
let subs = 4
let step = 1.0 / Double(subs)
for y in 0..<h {
    for x in 0..<w {
        var hits = 0
        for sy in 0..<subs {
            for sx in 0..<subs {
                let px = Double(x) + (Double(sx) + 0.5) * step
                let py = Double(y) + (Double(sy) + 0.5) * step
                if inside(px, py) { hits += 1 }
            }
        }
        let cov = Double(hits) / Double(subs * subs)
        if cov >= 1.0 { continue }
        let i = (y * w + x) * 4
        pixels[i]     = UInt8(Double(pixels[i]) * cov)
        pixels[i + 1] = UInt8(Double(pixels[i + 1]) * cov)
        pixels[i + 2] = UInt8(Double(pixels[i + 2]) * cov)
        pixels[i + 3] = UInt8(255.0 * cov)
    }
}

guard let out = ctx.makeImage() else { print("生成图像失败"); exit(1) }
let rep = NSBitmapImageRep(cgImage: out)
guard let data = rep.representation(using: .png, properties: [:]) else {
    print("编码失败"); exit(1)
}
try data.write(to: URL(fileURLWithPath: dstPath))
print("已写出 \(dstPath) (\(w)x\(h))")
