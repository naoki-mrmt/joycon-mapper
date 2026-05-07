import AppKit
import CoreText

struct IconSlot {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: "JoyconMapper/Assets.xcassets/AppIcon.appiconset")
let customFontURL = URL(fileURLWithPath: ".context/kateru_font_ver1.0-Regular.otf")
let slots: [IconSlot] = [
    .init(filename: "AppIcon-16.png", pixels: 16),
    .init(filename: "AppIcon-16@2x.png", pixels: 32),
    .init(filename: "AppIcon-32.png", pixels: 32),
    .init(filename: "AppIcon-32@2x.png", pixels: 64),
    .init(filename: "AppIcon-128.png", pixels: 128),
    .init(filename: "AppIcon-128@2x.png", pixels: 256),
    .init(filename: "AppIcon-256.png", pixels: 256),
    .init(filename: "AppIcon-256@2x.png", pixels: 512),
    .init(filename: "AppIcon-512.png", pixels: 512),
    .init(filename: "AppIcon-512@2x.png", pixels: 1024),
]

func iconFont(size: CGFloat) -> NSFont {
    guard FileManager.default.fileExists(atPath: customFontURL.path) else {
        return NSFont.systemFont(ofSize: size, weight: .black)
    }

    CTFontManagerRegisterFontsForURL(customFontURL as CFURL, .process, nil)
    guard
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(customFontURL as CFURL) as? [CTFontDescriptor],
        let descriptor = descriptors.first,
        let fontName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
        let font = NSFont(name: fontName, size: size)
    else {
        return NSFont.systemFont(ofSize: size, weight: .black)
    }

    return font
}

func drawIcon(size: Int) throws -> NSBitmapImageRep {
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
        throw NSError(domain: "RenderAppIcon", code: 1)
    }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    NSGraphicsContext.current?.imageInterpolation = .high

    let radius = CGFloat(size) * 0.22
    let iconPath = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.035, dy: CGFloat(size) * 0.035), xRadius: radius, yRadius: radius)

    NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.08, alpha: 1).setFill()
    iconPath.fill()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.54, blue: 0.43, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.72, alpha: 1)
    ])
    gradient?.draw(in: iconPath, angle: 38)

    let innerInset = CGFloat(size) * 0.095
    let innerPath = NSBezierPath(roundedRect: rect.insetBy(dx: innerInset, dy: innerInset), xRadius: radius * 0.68, yRadius: radius * 0.68)
    NSColor(calibratedWhite: 0.02, alpha: 0.18).setFill()
    innerPath.fill()

    let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.12, dy: CGFloat(size) * 0.12), xRadius: radius * 0.6, yRadius: radius * 0.6)
    NSColor(calibratedWhite: 1, alpha: 0.13).setStroke()
    highlight.lineWidth = max(1, CGFloat(size) * 0.012)
    highlight.stroke()

    let fontSize = CGFloat(size) * 0.47
    let font = iconFont(size: fontSize)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
        .kern: -fontSize * 0.035
    ]

    let text = "JM" as NSString
    let textSize = text.size(withAttributes: attributes)
    let textRect = NSRect(
        x: 0,
        y: (CGFloat(size) - textSize.height) * 0.5 - CGFloat(size) * 0.015,
        width: CGFloat(size),
        height: textSize.height
    )

    NSShadow().apply {
        $0.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.016)
        $0.shadowBlurRadius = CGFloat(size) * 0.035
        $0.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
    }
    text.draw(in: textRect, withAttributes: attributes)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RenderAppIcon", code: 1)
    }
    try data.write(to: url)
}

for slot in slots {
    let bitmap = try drawIcon(size: slot.pixels)
    try writePNG(bitmap, to: outputDirectory.appendingPathComponent(slot.filename))
}
