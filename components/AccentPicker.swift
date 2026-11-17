import SwiftUI

/// Ready-made swatches, a hue bar for any other colour, and a reset to purple.
struct AccentPicker: View {
    @Binding var accent: AccentColor
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentColor.presets, id: \.name) { preset in
                Swatch(preset: preset, isSelected: preset.color == accent) { accent = preset.color }
            }
            HueBar { hue in accent = AccentColor(hue: hue) }
            IconButton(symbol: "arrow.counterclockwise", label: "Reset to purple", action: onReset)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
    }
}

private struct Swatch: View {
    let preset: AccentPreset
    let isSelected: Bool
    let action: () -> Void
    @State private var hovered = false

    private var ring: Color {
        if isSelected {
            return .white
        }
        if hovered {
            return Theme.dimText
        }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(preset.color.color)
                .frame(width: 16, height: 16)
                .padding(2)
                .overlay(Circle().strokeBorder(ring, lineWidth: 1.2))
                .contentShape(Circle())
                .background(HoverRegion(cornerRadius: 10) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .help(preset.name)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Click or drag along the bar to pick any hue.
struct HueBar: View {
    static let hues: [Color] = [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1].map { AccentColor(hue: $0).color }
    let onPick: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(LinearGradient(colors: Self.hues, startPoint: .leading, endPoint: .trailing))
                .frame(height: 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    onPick(Self.hue(at: drag.location.x, width: geometry.size.width))
                })
        }
        .frame(height: 24)
        .accessibilityLabel("Hue")
    }

    /// Position along the bar as a hue from 0 to just under 1.
    static func hue(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let fraction = Double(x / width)
        return min(0.999, max(0, fraction))
    }
}
