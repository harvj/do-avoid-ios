import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3, let screen = NSImage(contentsOfFile: arguments[1]) else {
    fatalError("Usage: swift render-mockup.swift FIELD_SCREENSHOT OUTPUT_DIRECTORY")
}
let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)

func color(_ value: UInt32, opacity: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(value >> 16) / 255, green: CGFloat(value >> 8 & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: opacity)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ hex: UInt32, _ rect: CGRect, _ radius: CGFloat) {
    color(hex).setFill()
    rounded(rect, radius).fill()
}

func phone(x: CGFloat, y: CGFloat, width: CGFloat, shadow: Bool) {
    let height = width * screen.size.height / screen.size.width
    let display = CGRect(x: x, y: y, width: width, height: height)
    let body = display.insetBy(dx: -12, dy: -12)
    let radius = width * 0.127
    if shadow {
        NSGraphicsContext.saveGraphicsState()
        let cast = NSShadow()
        cast.shadowBlurRadius = 70
        cast.shadowOffset = CGSize(width: 12, height: -26)
        cast.shadowColor = color(0x252E23, opacity: 0.27)
        cast.set()
        fill(0x343A37, body, radius + 12)
        NSGraphicsContext.restoreGraphicsState()
    }

    fill(0x454D49, CGRect(x: body.minX - 3, y: body.maxY - 182, width: 5, height: 25), 2)
    fill(0x454D49, CGRect(x: body.minX - 3, y: body.maxY - 232, width: 5, height: 39), 2)
    fill(0x454D49, CGRect(x: body.minX - 3, y: body.maxY - 284, width: 5, height: 39), 2)
    fill(0x454D49, CGRect(x: body.maxX - 2, y: body.maxY - 269, width: 5, height: 61), 2)
    let shell = rounded(body, radius + 12)
    NSGradient(colors: [color(0x858C86), color(0x303733), color(0x565D58)])!
        .draw(in: shell, angle: -30)
    fill(0x101412, body.insetBy(dx: 2, dy: 2), radius + 10)
    NSGraphicsContext.saveGraphicsState()
    rounded(display, radius).addClip()
    screen.draw(in: display, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ name: String, width: Int, height: Int, drawing: () -> Void) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    let output = CGImageDestinationCreateWithURL(destination.appendingPathComponent(name) as CFURL,
                                                  UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(output))
}

func text(_ string: String, at point: CGPoint, font: NSFont, ink: UInt32, tracking: CGFloat = 0) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color(ink), .kern: tracking,
    ]
    (string as NSString).draw(at: point, withAttributes: attributes)
}

render("iphone-transparent.png", width: 600, height: 1240) {
    phone(x: 41, y: 57, width: 518, shadow: false)
}

render("landing-mockup.png", width: 1600, height: 1200) {
    let canvas = CGRect(x: 0, y: 0, width: 1600, height: 1200)
    NSGradient(starting: color(0xF8F6EF), ending: color(0xE8EFE4))!.draw(in: canvas, angle: -24)
    color(0xDCE8D9, opacity: 0.67).setFill()
    NSBezierPath(ovalIn: CGRect(x: 779, y: 215, width: 750, height: 750)).fill()
    color(0xFFFFFF, opacity: 0.58).setStroke()
    let outline = NSBezierPath(ovalIn: CGRect(x: 808, y: 244, width: 692, height: 692))
    outline.lineWidth = 1.5
    outline.stroke()

    let serif = NSFont(name: "Georgia", size: 78) ?? .systemFont(ofSize: 78)
    let body = NSFont(name: "AvenirNext-Medium", size: 28) ?? .systemFont(ofSize: 28)
    let mark = NSFont(name: "AvenirNext-DemiBold", size: 24) ?? .boldSystemFont(ofSize: 24)
    text("Do/Avoid", at: CGPoint(x: 130, y: 817), font: mark, ink: 0x276047, tracking: 1.0)
    text("A quieter way to", at: CGPoint(x: 124, y: 673), font: serif, ink: 0x192D24, tracking: -2.8)
    text("notice patterns.", at: CGPoint(x: 124, y: 580), font: serif, ink: 0x192D24, tracking: -2.8)
    text("Make space for what you want to do", at: CGPoint(x: 131, y: 484), font: body, ink: 0x40574B)
    text("and what you want to do less.", at: CGPoint(x: 131, y: 445), font: body, ink: 0x40574B)
    phone(x: 916, y: 101, width: 452, shadow: true)
}
