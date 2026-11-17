import SwiftUI

/// Where each menu's button sits, so its dropdown can open right under it.
struct MenuAnchorKey: PreferenceKey {
    static let defaultValue: [PanelMenu: Anchor<CGRect>] = [:]
    static func reduce(value: inout [PanelMenu: Anchor<CGRect>], nextValue: () -> [PanelMenu: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks this view as the button that opens `menu`.
    func menuAnchor(_ menu: PanelMenu) -> some View {
        anchorPreference(key: MenuAnchorKey.self, value: .bounds) { [menu: $0] }
    }
}

/// A small dark card that drops down under its button, right edges lined up.
struct Dropdown<Content: View>: View {
    static var width: CGFloat { 196 }
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 5)
        .frame(width: Self.width)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.menu))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        // Empty space inside the card must not close it.
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {}
    }
}

/// One line in a dropdown: an optional icon, a title and an optional check.
struct DropdownRow: View {
    let title: String
    var symbol: String?
    var isChecked = false
    var tint: Color?
    let action: () -> Void
    @State private var hovered = false

    private var fill: Color {
        if hovered {
            return Theme.cardHover
        }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(panelFont(12.5))
                    .lineLimit(1)
                Spacer(minLength: 6)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundStyle(tint ?? Theme.text)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

struct DropdownDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}
