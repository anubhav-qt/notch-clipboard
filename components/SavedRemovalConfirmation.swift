import SwiftUI

struct SavedRemovalConfirmation: View {
    @ObservedObject var model: ClipboardModel
    @Environment(\.accent) private var accent
    @State private var checkboxHovered = false

    private var checkboxSymbol: String {
        if model.skipPendingRemovalConfirmation {
            return "checkmark.square.fill"
        }
        return "square"
    }

    private var checkboxColor: Color {
        if model.skipPendingRemovalConfirmation || checkboxHovered {
            return accent
        }
        return Color.white.opacity(0.45)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .contentShape(Rectangle())
                .onTapGesture { model.cancelSavedRemoval() }
                .accessibilityLabel("Dismiss confirmation")
            VStack(alignment: .leading, spacing: 22) {
                Text("Remove from Saved?")
                    .font(panelFont(17, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                Button { model.skipPendingRemovalConfirmation.toggle() } label: {
                    HStack(spacing: 9) {
                        Image(systemName: checkboxSymbol)
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(checkboxColor)
                        Text("Don't ask again in this session")
                            .font(panelFont(11.5)).foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .background(HoverRegion(cornerRadius: 0) { checkboxHovered = $0 })
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Don't ask again in this session")
                .accessibilityValue(model.skipPendingRemovalConfirmation ? "Checked" : "Unchecked")
                HStack(spacing: 10) {
                    PanelButton(title: "No") { model.finishSavedRemoval(remove: false) }
                    PanelButton(title: "Yes", primary: true) { model.finishSavedRemoval(remove: true) }
                }
            }
            .padding(24)
            .frame(width: 350)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.3), lineWidth: 0.7).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            // Empty space inside the card must not dismiss it or reach a row.
            .onTapGesture {}
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Remove from Saved?")
        }
        .background(ConfirmationOutsideClicks { model.cancelSavedRemoval() })
    }
}

private struct ConfirmationOutsideClicks: NSViewRepresentable {
    let dismiss: () -> Void
    func makeNSView(context: Context) -> ConfirmationClickView {
        let view = ConfirmationClickView()
        view.dismiss = dismiss
        return view
    }
    func updateNSView(_ view: ConfirmationClickView, context: Context) { view.dismiss = dismiss }
    static func dismantleNSView(_ view: ConfirmationClickView, coordinator: ()) { view.stopMonitoring() }
}

private final class ConfirmationClickView: NSView {
    var dismiss: (() -> Void)?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissIfOutside(event)
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss?()
        }
    }

    private func dismissIfOutside(_ event: NSEvent) {
        guard let window else { return }
        if event.window !== window {
            dismiss?()
        }
    }

    func stopMonitoring() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }
}
