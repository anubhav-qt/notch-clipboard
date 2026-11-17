import SwiftUI

/// The foot of the panel in Select mode: how many are picked, a quiet note, Cancel and Done.
struct SelectBar: View {
    @ObservedObject var model: ClipboardModel

    private var count: Int {
        model.selection?.ids.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) selected")
                        .font(panelFont(12, weight: .medium))
                        .foregroundStyle(Theme.text)
                    if let note = model.selectionNote {
                        Text(note)
                            .font(panelFont(10.5))
                            .foregroundStyle(Theme.dimText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                PanelButton(title: "Cancel", height: 26) { model.cancelSelection() }
                    .frame(width: 72)
                PanelButton(title: "Done", primary: true, height: 26) { model.finishSelection() }
                    .frame(width: 72)
                    .disabled(count == 0)
            }
            .frame(height: 38)
            .padding(.top, 4)
        }
    }
}
