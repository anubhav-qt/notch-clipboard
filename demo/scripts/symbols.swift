import AppKit

// Draws each SF Symbol the panel uses as a white PNG, so the video can tint it like the app.
// Sizes are written to symbols.json, measured at a 100 pt font.
let symbols: [(String, NSFont.Weight)] = [
    ("paintpalette", .regular), ("checkmark.rectangle.stack", .regular), ("trash", .regular),
    ("gearshape", .regular), ("magnifyingglass", .regular), ("bookmark", .regular),
    ("bookmark.fill", .regular), ("chevron.down", .semibold), ("pencil", .regular),
    ("checkmark", .semibold), ("circle.grid.3x3.fill", .regular), ("xmark", .medium),
    ("plus", .medium), ("arrow.counterclockwise", .regular), ("xmark.circle.fill", .regular),
]
let pointSize: CGFloat = 100
let scale: CGFloat = 2
let out = CommandLine.arguments[1]
var sizes: [String: [CGFloat]] = [:]

for (name, weight) in symbols {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
        print("missing \(name)")
        continue
    }
    let size = image.size
    let width = Int((size.width * scale).rounded(.up))
    let height = Int((size.height * scale).rounded(.up))
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                  samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    sizes[name] = [size.width, size.height]
}
let json = try! JSONSerialization.data(withJSONObject: sizes, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: "\(out)/symbols.json"))
