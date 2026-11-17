import SwiftUI

/// A small outlined squircle label, with no fill.
struct Chip: View {
    let text: String
    let help: String
    var color: Color = Theme.dimText

    var body: some View {
        Text(text)
            .font(panelFont(10.5, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(color.opacity(0.45), lineWidth: 1))
            .help(help)
            .accessibilityLabel(help)
    }
}
