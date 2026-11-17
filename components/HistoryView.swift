import AppKit
import SwiftUI

/// The whole panel: title row, search with category tabs, the list of clips,
/// and in Select mode the bar at the foot.
struct HistoryView: View {
    @ObservedObject var model: ClipboardModel
    var onQuit: () -> Void = { NSApp.terminate(nil) }
    @State private var confirmingClear = false

    /// A sheet over the panel blocks everything under it.
    private var isBlocked: Bool {
        model.isConfirmingSavedRemoval || model.categoryDraft != nil
    }

    var body: some View {
        VStack(spacing: 10) {
            titleRow
            if model.isPickingAccent {
                AccentPicker(accent: $model.accent, onReset: model.resetAccent)
            }
            searchRow
            if let notice = model.notice {
                Text(notice)
                    .font(panelFont(11))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.entries.isEmpty {
                EmptyHistory(filter: model.filter, categoryName: chosenCategoryName, isSearching: !model.query.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.entries) { clip in
                            ClipRow(clip: clip, model: model)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if model.isSelecting {
                SelectBar(model: model)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .padding(.top, max(17, model.notchHeight + 10))
        .overlayPreferenceValue(MenuAnchorKey.self) { anchors in
            GeometryReader { proxy in
                openMenu(anchors: anchors, in: proxy)
            }
        }
        .disabled(isBlocked)
        .allowsHitTesting(!isBlocked)
        .accessibilityHidden(isBlocked)
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.panel)
        .overlay {
            if model.isConfirmingSavedRemoval {
                SavedRemovalConfirmation(model: model)
            } else if model.categoryDraft != nil {
                CategoryEditor(model: model)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 24, bottomTrailingRadius: 24, topTrailingRadius: 15))
        .environment(\.accent, model.accent.color)
        .preferredColorScheme(.dark)
        .alert("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) { model.clear() }
        } message: {
            Text("Saved items and the current system clipboard are kept.")
        }
    }

    private var chosenCategoryName: String? {
        model.categoryList.category(id: model.categoryID)?.name
    }

    private var titleRow: some View {
        HStack(spacing: 4) {
            SquircleToggle(filter: $model.filter)
            Spacer()
            IconButton(symbol: "paintpalette", label: "Accent colour", isActive: model.isPickingAccent) {
                model.isPickingAccent.toggle()
            }
            IconButton(symbol: "checkmark.rectangle.stack", label: "Select items", isActive: model.isSelecting) {
                model.toggleSelectMode()
            }
            IconButton(symbol: "trash", label: "Clear History") { confirmingClear = true }
            IconButton(symbol: "gearshape", label: "Settings", isActive: model.openMenu == .settings) {
                model.toggleMenu(.settings)
            }
            .menuAnchor(.settings)
        }
    }

    /// Search takes whatever width the tabs leave.
    private var searchRow: some View {
        HStack(spacing: 8) {
            SearchField(text: $model.query, onSubmit: chooseFirstResult)
            if model.categoriesAvailable {
                CategoryTabs(model: model)
                    .layoutPriority(1)
            }
        }
    }

    /// The open dropdown, under its button with right edges lined up. A click anywhere else closes it.
    @ViewBuilder private func openMenu(anchors: [PanelMenu: Anchor<CGRect>], in proxy: GeometryProxy) -> some View {
        if let menu = model.openMenu, let anchor = anchors[menu] {
            let button = proxy[anchor]
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.openMenu = nil }
                menuContent(menu)
                    .offset(x: button.maxX - Dropdown<EmptyView>.width, y: button.maxY + 4)
            }
        }
    }

    @ViewBuilder private func menuContent(_ menu: PanelMenu) -> some View {
        switch menu {
        case .more:
            MoreMenu(model: model)
        case .settings:
            SettingsMenu(model: model, onQuit: onQuit)
        }
    }

    private func chooseFirstResult() {
        if model.isSelecting {
            return
        }
        if let first = model.entries.first {
            model.choose(first)
        }
    }
}

/// One line of text when the list is empty. No icon.
private struct EmptyHistory: View {
    let filter: ClipboardFilter
    let categoryName: String?
    let isSearching: Bool

    private var message: String {
        if isSearching {
            return "No matching items"
        }
        if let categoryName {
            return "No \(categoryName) items"
        }
        if filter == .saved {
            return "No saved items"
        }
        return "No items yet"
    }

    var body: some View {
        Text(message)
            .font(panelFont(14, weight: .medium))
            .foregroundStyle(Theme.dimText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lets the first click on an inactive panel act on the control under it.
final class HostingView: NSHostingView<HistoryView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
