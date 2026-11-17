import SwiftUI

/// One clip as a flat card: preview, text, details and a bookmark.
/// In Select mode the bookmark becomes a numbered box and a tap picks the row.
struct ClipRow: View {
    let clip: Clip
    @ObservedObject var model: ClipboardModel
    @Environment(\.accent) private var accent
    @State private var hovered = false

    private var fill: Color {
        if hovered {
            return Theme.cardHover
        }
        return Theme.card
    }

    private var pickNumber: Int? {
        model.selection?.number(of: clip.id)
    }

    private var isDimmed: Bool {
        model.selection?.isDimmed(kind: clip.kind) ?? false
    }

    private var outline: Color {
        if pickNumber != nil {
            return accent.opacity(0.8)
        }
        return .clear
    }

    private var label: String {
        if model.isSelecting {
            return "Select \(clip.kind): \(clip.title)"
        }
        return "Copy \(clip.kind): \(clip.title)"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: tapped) {
                HStack(spacing: 12) {
                    if let thumbnail = model.thumbnail(clip) {
                        ImagePreview(image: thumbnail)
                    }
                    ClipText(clip: clip)
                }
                .padding(.leading, 12)
                .padding(.trailing, 46)
                .padding(.vertical, 9)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            if model.isSelecting {
                PickBox(number: pickNumber)
                    .padding(.trailing, 13)
                    .allowsHitTesting(false)
            } else {
                BookmarkButton(isSaved: clip.isSaved) { model.toggleSaved(clip) }
                    .padding(.trailing, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(outline, lineWidth: 1).allowsHitTesting(false))
        .opacity(isDimmed ? 0.35 : 1)
        .background(HoverRegion(cornerRadius: 9) { hovered = $0 })
    }

    private func tapped() {
        if model.isSelecting {
            model.pick(clip)
        } else {
            model.choose(clip)
        }
    }
}

/// An empty squircle; once picked it shows the paste order.
private struct PickBox: View {
    let number: Int?
    @Environment(\.accent) private var accent

    private var border: Color {
        if number != nil {
            return accent
        }
        return Theme.faintText
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(border, lineWidth: 1.2)
            if let number {
                Text("\(number)")
                    .font(panelFont(10.5, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

/// Copied images show the picture itself. Other clips show no icon.
private struct ImagePreview: View {
    let image: NSImage

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct ClipText: View {
    let clip: Clip
    @Environment(\.accent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(clip.title)
                .font(panelFont(12.5))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                if let category = clip.categoryName {
                    Chip(text: category, help: "Category: \(category)", color: accent)
                }
                Spacer(minLength: 4)
                Text(ClipboardAge.label(created: clip.created))
                    .font(panelFont(10.5))
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
            }
        }
    }
}

/// Unsaved: grey outline. Saved: filled accent. Hovered: dim accent.
private struct BookmarkButton: View {
    let isSaved: Bool
    let action: () -> Void
    @Environment(\.accent) private var accent
    @State private var hovered = false

    private var symbol: String {
        if isSaved {
            return "bookmark.fill"
        }
        return "bookmark"
    }

    private var color: Color {
        if hovered {
            return accent.opacity(0.6)
        }
        if isSaved {
            return accent
        }
        return Theme.faintText
    }

    private var label: String {
        if isSaved {
            return "Remove from Saved"
        }
        return "Save item"
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 28, height: 32)
                .contentShape(Rectangle())
                .background(HoverRegion(cornerRadius: 4) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
