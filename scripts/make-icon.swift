import AppKit

// Disegna l'icona 1024×1024: cielo scuro, stelle sfumate, lente arancione.
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 190, yRadius: 190)
NSGradient(starting: NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.30, alpha: 1),
           ending: NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.09, alpha: 1))!.draw(in: tile, angle: -90)

let stars: [(CGFloat, CGFloat, CGFloat)] = [(360, 640, 110), (620, 700, 50), (280, 360, 45), (720, 520, 35), (470, 470, 28)]
for (x, y, r) in stars {
    NSGradient(starting: .white, ending: NSColor.white.withAlphaComponent(0))!
        .draw(fromCenter: NSPoint(x: x, y: y), radius: 0, toCenter: NSPoint(x: x, y: y), radius: r, options: [])
}

NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.20, alpha: 1).setStroke()
let lens = NSBezierPath(ovalIn: NSRect(x: 520, y: 200, width: 270, height: 270))
lens.lineWidth = 40
lens.stroke()
let handle = NSBezierPath()
handle.move(to: NSPoint(x: 560, y: 240))
handle.line(to: NSPoint(x: 420, y: 100))
handle.lineWidth = 56
handle.lineCapStyle = .round
handle.stroke()

NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try rep.representation(using: .png, properties: [:])!.write(to: output)
