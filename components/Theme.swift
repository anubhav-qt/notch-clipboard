import SwiftUI

/// Fixed panel colours. Only the accent changes, and it comes from the environment.
enum Theme {
    static let panel = Color.black
    static let card = Color(white: 0.078)
    static let cardHover = Color(white: 0.11)
    static let menu = Color(white: 0.095)
    static let line = Color.white.opacity(0.08)
    static let text = Color.white.opacity(0.9)
    static let dimText = Color.white.opacity(0.5)
    static let faintText = Color.white.opacity(0.35)
    static let problem = Color(red: 1, green: 0.45, blue: 0.45)
}

func panelFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
    Font.system(size: size, weight: weight, design: .rounded)
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue = AccentColor.purple.color
}

extension EnvironmentValues {
    /// The user's chosen accent colour.
    var accent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}
