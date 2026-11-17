import SwiftUI

/// Presets, a hex box, a shade square and a hue bar. Together they reach any colour.
struct AccentPicker: View {
    @Binding var accent: AccentColor
    let onReset: () -> Void
    @State private var shade: AccentShade

    init(accent: Binding<AccentColor>, onReset: @escaping () -> Void) {
        _accent = accent
        self.onReset = onReset
        _shade = State(initialValue: AccentShade(accent.wrappedValue))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(AccentColor.presets, id: \.name) { preset in
                    Swatch(preset: preset, isSelected: preset.color == accent) { accent = preset.color }
                }
                Spacer(minLength: 4)
                HexField(accent: $accent)
                IconButton(symbol: "arrow.counterclockwise", label: "Reset to purple", action: onReset)
            }
            ShadeSquare(shade: shade, onPick: pick)
            HueBar(hue: shade.hue) { hue in pick(shade.with(hue: hue)) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
        .onChange(of: accent) { _, newAccent in
            // A preset, the hex box or reset picked this, so the square and bar follow it.
            if newAccent != shade.accent {
                shade = shade.following(newAccent)
            }
        }
    }

    private func pick(_ next: AccentShade) {
        shade = next
        accent = next.accent
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

/// Type or paste a colour. Six digits apply while typing; three, like FFF, apply on Return.
struct HexField: View {
    static let width: CGFloat = 84
    @Binding var accent: AccentColor
    @State private var text: String
    @FocusState private var focused: Bool

    init(accent: Binding<AccentColor>) {
        _accent = accent
        _text = State(initialValue: Self.digits(of: accent.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 2) {
            Text("#")
                .foregroundStyle(Theme.faintText)
            TextField("Hex", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .accessibilityLabel("Hex colour")
                .onSubmit(apply)
        }
        .font(panelFont(12, weight: .medium).monospaced())
        .padding(.horizontal, 8)
        .frame(width: Self.width, height: 24)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.cardHover))
        .onChange(of: text) { _, typed in
            let digits = AccentColor.hexDigits(from: typed)
            if digits != typed {
                text = digits
                return
            }
            if digits.count == 6, let color = AccentColor(hex: digits) {
                accent = color
            }
        }
        .onChange(of: accent) { _, newAccent in
            // Keep half-typed text alone; show any colour picked some other way.
            if AccentColor(hex: text) != newAccent {
                text = Self.digits(of: newAccent)
            }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused {
                apply()
            }
        }
    }

    /// Uses the text if it is a colour, then shows the colour in full either way.
    private func apply() {
        if let color = AccentColor(hex: text) {
            accent = color
        }
        text = Self.digits(of: accent)
    }

    private static func digits(of accent: AccentColor) -> String {
        String(accent.hex.dropFirst())
    }
}

/// Strength runs left to right (white to the full hue), brightness top to bottom (to black).
struct ShadeSquare: View {
    static let height: CGFloat = 64
    let shade: AccentShade
    let onPick: (AccentShade) -> Void
    @State private var hovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.white, shade.pureHue.color], startPoint: .leading, endPoint: .trailing))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                Thumb(color: shade.accent.color, isLarge: hovered)
                    .position(x: shade.saturation * geometry.size.width,
                              y: (1 - shade.brightness) * geometry.size.height)
            }
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard let spot = Self.spot(at: drag.location, in: geometry.size) else { return }
                onPick(shade.with(saturation: spot.saturation, brightness: spot.brightness))
            })
        }
        .frame(height: Self.height)
        .accessibilityLabel("Shade")
    }

    /// A point in the square as strength and brightness. Points outside stop at the edge.
    static func spot(at point: CGPoint, in size: CGSize) -> (saturation: Double, brightness: Double)? {
        guard size.width > 0, size.height > 0 else { return nil }
        let saturation = AccentColor.clamp(Double(point.x / size.width))
        let darkness = AccentColor.clamp(Double(point.y / size.height))
        return (saturation, 1 - darkness)
    }
}

/// Click or drag along the bar to pick any hue.
struct HueBar: View {
    static let stops: [Double] = [0, 1.0 / 6, 2.0 / 6, 3.0 / 6, 4.0 / 6, 5.0 / 6, 1]
    static let hues: [Color] = stops.map { stop in
        AccentShade(hue: stop, saturation: 1, brightness: 1).pureHue.color
    }
    let hue: Double
    let onPick: (Double) -> Void
    @State private var hovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: Self.hues, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                Thumb(color: AccentShade(hue: hue, saturation: 1, brightness: 1).pureHue.color, isLarge: hovered)
                    .position(x: hue * geometry.size.width, y: geometry.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                onPick(Self.hue(at: drag.location.x, width: geometry.size.width))
            })
        }
        .frame(height: 20)
        .accessibilityLabel("Hue")
    }

    /// Position along the bar as a hue from 0 to just under 1.
    static func hue(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let fraction = Double(x / width)
        return min(0.999, max(0, fraction))
    }
}

/// The ring that marks the picked spot. A dark edge keeps it visible on white.
private struct Thumb: View {
    let color: Color
    let isLarge: Bool

    private var size: CGFloat {
        if isLarge {
            return 14
        }
        return 12
    }

    var body: some View {
        Circle()
            .fill(color)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 0.5))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.1), value: isLarge)
    }
}
