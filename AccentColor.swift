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
        AccentPreset(name: "Pink", color: AccentColor(red: 1, green: 140.0 / 255, blue: 190.0 / 255))
    ]

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    /// Any hue at the same soft strength as the default purple. Hue runs from 0 to 1.
    init(hue: Double) {
        let wrapped = hue - hue.rounded(.down)
        let color = NSColor(hue: wrapped, saturation: 0.45, brightness: 1, alpha: 1)
        self.init(red: Double(color.redComponent), green: Double(color.greenComponent), blue: Double(color.blueComponent))
    }

    /// Reads "#RRGGBB" or "RRGGBB". Anything else gives nil.
    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
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

    private static func clamp(_ value: Double) -> Double {
        if value.isNaN {
            return 0
        }
        return min(1, max(0, value))
    }
}

struct AccentPreset {
    let name: String
    let color: AccentColor
}
