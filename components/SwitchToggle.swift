import SwiftUI

/// A small on/off switch. On: accent track, knob on the right.
struct SwitchToggle: View {
    @Binding var isOn: Bool
    @Environment(\.accent) private var accent

    private var track: Color {
        if isOn {
            return accent
        }
        return Color.white.opacity(0.18)
    }

    private var knobAlignment: Alignment {
        if isOn {
            return .trailing
        }
        return .leading
    }

    var body: some View {
        Capsule()
            .fill(track)
            .frame(width: 28, height: 16)
            .overlay(alignment: knobAlignment) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.12), value: isOn)
    }
}
