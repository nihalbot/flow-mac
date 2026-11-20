import AppKit

func generateIcon() {
    let baseSize = 1024
    let masterRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: baseSize,
        pixelsHigh: baseSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: masterRep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    
    // Background squircle (macOS Big Sur+ style app icon shape)
    let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: rect, cornerWidth: 190, cornerHeight: 190, transform: nil)
    
    // Gradient: Flow warm coral gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    
    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    cg.restoreGState()
    
    // Outer subtle border
    cg.addPath(path)
    cg.setStrokeColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    cg.setLineWidth(4)
    cg.strokePath()
    
    // Draw Timer Progress Ring (Flow's iconic concentric arc)
    let center = CGPoint(x: 512, y: 512)
    let radius: CGFloat = 260
    
    // Track ring
    cg.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    cg.setStrokeColor(NSColor(red: 0.95, green: 0.36, blue: 0.30, alpha: 0.25).cgColor)
    cg.setLineWidth(42)
    cg.strokePath()
    
    // Active progress arc
    cg.saveGState()
    cg.setLineCap(.round)
    cg.addArc(center: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi * 0.85, clockwise: false)
    cg.setStrokeColor(NSColor(red: 0.95, green: 0.36, blue: 0.30, alpha: 1.0).cgColor)
    cg.setLineWidth(42)
    cg.strokePath()
    cg.restoreGState()
    
    // Central Flow Icon: Stopwatch glyph
    let font = NSFont.systemFont(ofSize: 180, weight: .bold)
    let str = "⏱" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let strSize = str.size(withAttributes: attrs)
    let strRect = CGRect(
        x: center.x - strSize.width / 2,
        y: center.y - strSize.height / 2 - 10,
        width: strSize.width,
        height: strSize.height
    )
    str.draw(in: strRect, withAttributes: attrs)
    
    NSGraphicsContext.restoreGraphicsState()
    
    let fm = FileManager.default
    let iconsetPath = "/tmp/Flow.iconset"
    try? fm.removeItem(atPath: iconsetPath)
    try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
    
    let iconDefs: [(pixels: Int, name: String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]
    
    for def in iconDefs {
        let p = def.pixels
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: p,
            pixelsHigh: p,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        masterRep.draw(in: NSRect(x: 0, y: 0, width: p, height: p))
        NSGraphicsContext.restoreGraphicsState()
        
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(def.name)"))
        }
    }
    
    print("Exact iconset created at \(iconsetPath)")
}

generateIcon()
