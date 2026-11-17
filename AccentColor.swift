import AppKit
import SwiftUI

/// The user's accent colour, stored as "#RRGGBB" so it survives relaunches.
struct AccentColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    static let purple = AccentColor(red: 191.0 / 255, green: 165.0 / 255, blue: 1)

    /// Ready-made choices. Purple, the default, comes first.
    static let presets: [AccentPreset] = [
        AccentPreset(name: "Purple", color: purple),
        AccentPreset(name: "Coral", color: AccentColor(red: 1, green: 122.0 / 255, blue: 107.0 / 255)),
        AccentPreset(name: "Amber", color: AccentColor(red: 242.0 / 255, green: 166.0 / 255, blue: 90.0 / 255)),
        AccentPreset(name: "Lime", color: AccentColor(red: 183.0 / 255, green: 227.0 / 255, blue: 107.0 / 255)),
        AccentPreset(name: "Mint", color: AccentColor(red: 79.0 / 255, green: 209.0 / 255, blue: 197.0 / 255)),
        AccentPreset(name: "Sky", color: AccentColor(red: 110.0 / 255, green: 170.0 / 255, blue: 1)),
        AccentPreset(name: "Pink", color: AccentColor(red: 1, green: 140.0 / 255, blue: 190.0 / 255)),
        AccentPreset(name: "White", color: AccentColor(red: 1, green: 1, blue: 1))
    ]

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    /// Reads "#RRGGBB", "RRGGBB" or the short "#RGB". Anything else gives nil.
    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.allSatisfy(\.isHexDigit) else { return nil }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6 else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    /// What someone typed or pasted, cut down to at most six upper-case hex digits.
    static func hexDigits(from typed: String) -> String {
        let digits = typed.filter(\.isHexDigit).uppercased()
        return String(digits.prefix(6))
    }

    var hex: String {
        let red = Int((red * 255).rounded())
        let green = Int((green * 255).rounded())
        let blue = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// Two colours count as the same when they print the same hex.
    static func == (left: AccentColor, right: AccentColor) -> Bool {
        left.hex == right.hex
    }

    static func clamp(_ value: Double) -> Double {
        if value.isNaN {
            return 0
        }
        return min(1, max(0, value))
    }
}

/// A colour as hue, strength and brightness, each from 0 to 1. The picker keeps one,
/// so the hue is not lost while the colour is white, grey or black.
struct AccentShade: Equatable {
    /// The strength a grey jumps to when a hue is picked for it: the soft look of the default purple.
    static let softSaturation = 0.45

    let hue: Double
    let saturation: Double
    let brightness: Double

    init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = AccentColor.clamp(hue)
        self.saturation = AccentColor.clamp(saturation)
        self.brightness = AccentColor.clamp(brightness)
    }

    init(_ accent: AccentColor) {
        let color = NSColor(srgbRed: accent.red, green: accent.green, blue: accent.blue, alpha: 1)
        self.init(hue: Double(color.hueComponent),
                  saturation: Double(color.saturationComponent),
                  brightness: Double(color.brightnessComponent))
    }

    var accent: AccentColor {
        let color = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        let srgb = color.usingColorSpace(.sRGB) ?? color
        return AccentColor(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
    }

    /// The same hue at its strongest, for painting the shade square.
    var pureHue: AccentColor {
        AccentShade(hue: hue, saturation: 1, brightness: 1).accent
    }

    /// A new hue. A grey or black has no hue to show, so it comes back at the soft strength.
    func with(hue newHue: Double) -> AccentShade {
        if saturation < 0.05 || brightness < 0.05 {
            return AccentShade(hue: newHue, saturation: Self.softSaturation, brightness: 1)
        }
        return AccentShade(hue: newHue, saturation: saturation, brightness: brightness)
    }

    /// A new strength and brightness, keeping the hue.
    func with(saturation newSaturation: Double, brightness newBrightness: Double) -> AccentShade {
        AccentShade(hue: hue, saturation: newSaturation, brightness: newBrightness)
    }

    /// Follows a colour picked some other way. Greys and black have no hue of their own,
    /// so they keep this one, and black keeps this strength too.
    func following(_ accent: AccentColor) -> AccentShade {
        let next = AccentShade(accent)
        if next.brightness == 0 {
            return AccentShade(hue: hue, saturation: saturation, brightness: 0)
        }
        if next.saturation == 0 {
            return AccentShade(hue: hue, saturation: 0, brightness: next.brightness)
        }
        return next
    }
}

struct AccentPreset {
    let name: String
    let color: AccentColor
}
