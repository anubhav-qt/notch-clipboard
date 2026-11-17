import AppKit
import SwiftUI

/// A text tab beside search, as wide as its text. The chosen one turns the accent colour
/// and gets a short underline. Long names are cut with an ellipsis.
struct TabButton: View {
    let title: String
    let isSelected: Bool
    var showsChevron = false
    let action: () -> Void
    @Environment(\.accent) private var accent
    @State private var hovered = false

    static let maxTextWidth: CGFloat = 92

    private var color: Color {
        if isSelected {
            return accent
        }
        if hovered {
            return Theme.text
        }
        return Theme.dimText
    }

    private var underline: Color {
        if isSelected {
            return accent
        }
        return .clear
    }

    /// The width the title needs, but never more than the cap.
    static func textWidth(for title: String) -> CGFloat {
        let base = NSFont.systemFont(ofSize: 12, weight: .medium)
        var font = base
        if let rounded = base.fontDescriptor.withDesign(.rounded), let roundedFont = NSFont(descriptor: rounded, size: 12) {
            font = roundedFont
        }
        let natural = (title as NSString).size(withAttributes: [.font: font]).width
        return min(maxTextWidth, natural.rounded(.up) + 1)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Text(title)
                        .font(panelFont(12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: Self.textWidth(for: title))
                    if showsChevron {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                }
                Rectangle().fill(underline).frame(height: 1.5)
            }
            .foregroundStyle(color)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.top, 5)
            .frame(height: 34)
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 0) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
