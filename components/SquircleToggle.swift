import SwiftUI

/// One choice in a squircle toggle.
struct ToggleOption<Value: Hashable>: Hashable {
    let title: String
    let value: Value
}

/// Segments in one squircle outline. The chosen one gets accent text and an accent outline, no fill.
/// Used for All/Text/Images/Saved and for the All tab's First/Last.
struct SquircleToggle<Value: Hashable>: View {
    let options: [ToggleOption<Value>]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                ToggleSegment(title: option.title, isSelected: selection == option.value) {
                    selection = option.value
                }
            }
        }
        .padding(2)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

extension SquircleToggle where Value == ClipboardFilter {
    /// All, Text, Images and Saved at the left of the title row.
    init(filter: Binding<ClipboardFilter>) {
        options = ClipboardFilter.allCases.map { ToggleOption(title: $0.rawValue, value: $0) }
        _selection = filter
    }
}

private struct ToggleSegment: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accent) private var accent
    @State private var hovered = false

    private var textColor: Color {
        if isSelected {
            return accent
        }
        if hovered {
            return Theme.text
        }
        return Theme.dimText
    }

    private var border: Color {
        if isSelected {
            return accent.opacity(0.7)
        }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(panelFont(12, weight: .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(border, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(HoverRegion(cornerRadius: 8) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
