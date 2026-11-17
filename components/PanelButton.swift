import SwiftUI

/// A text button for sheets and bars. The primary one is tinted with the accent.
/// A disabled one is dimmed and does nothing.
struct PanelButton: View {
    let title: String
    var primary = false
    var height: CGFloat = 34
    let action: () -> Void
    @Environment(\.accent) private var accent
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    private var textColor: Color {
        if primary {
            return accent
        }
        return Color.white.opacity(0.75)
    }

    private var fillColor: Color {
        if primary {
            return accent.opacity(hovered ? 0.22 : 0.12)
        }
        return Color.white.opacity(hovered ? 0.09 : 0.035)
    }

    private var borderColor: Color {
        if primary {
            return accent.opacity(0.4)
        }
        return Color.white.opacity(0.15)
    }

    var body: some View {
        Button(action: action) {
            Text(title).font(panelFont(12.5, weight: .medium))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .background(RoundedRectangle(cornerRadius: 6).fill(fillColor))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(borderColor, lineWidth: 0.7).allowsHitTesting(false))
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(title)
    }
}
