import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
let sizes = [(16,"icon_16x16"),(32,"icon_16x16@2x"),(32,"icon_32x32"),(64,"icon_32x32@2x"),(128,"icon_128x128"),(256,"icon_128x128@2x"),(256,"icon_256x256"),(512,"icon_256x256@2x"),(512,"icon_512x512"),(1024,"icon_512x512@2x")]
for (pixels, name) in sizes {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.29, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 212, yRadius: 212).fill()
    NSColor(calibratedRed: 0.92, green: 0.96, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 208, y: 330, width: 608, height: 364), xRadius: 86, yRadius: 86).fill()
    NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.60, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 480, y: 384, width: 250, height: 250)).fill()
    NSColor(calibratedRed: 0.35, green: 0.76, blue: 1, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 525, y: 429, width: 160, height: 160)).fill()
    NSColor(calibratedWhite: 1, alpha: 0.8).setFill()
    NSBezierPath(ovalIn: NSRect(x: 555, y: 515, width: 44, height: 44)).fill()
    NSColor(calibratedRed: 0.23, green: 0.41, blue: 0.65, alpha: 1).setFill()
    for y in [450,486,522,558] { NSBezierPath(roundedRect: NSRect(x: 276, y: y, width: 124, height: 13), xRadius: 6, yRadius: 6).fill() }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name + ".png"))
}
