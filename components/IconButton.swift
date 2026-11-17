import SwiftUI

/// A small grey symbol button for the title row. Active ones turn the accent colour.
struct IconButton: View {
    let symbol: String
    let label: String
    var isActive = false
    let action: () -> Void
    @Environment(\.accent) private var accent
    @State private var hovered = false

    private var color: Color {
        if isActive {
            return accent
        }
        if hovered {
            return Theme.text
        }
        return Theme.dimText
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                // Some symbols, like the palette, default to several colours; keep every icon one colour.
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
