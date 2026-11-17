import SwiftUI

/// All, the first three categories and More, on the right of the search field.
struct CategoryTabs: View {
    @ObservedObject var model: ClipboardModel

    /// More looks chosen while one of its categories is the filter.
    private var moreIsChosen: Bool {
        guard let id = model.categoryID else { return false }
        return model.categoryList.more.contains { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(model.categoryList.tabs.enumerated()), id: \.offset) { _, tab in
                tabButton(tab)
            }
        }
    }

    @ViewBuilder private func tabButton(_ tab: CategoryTab) -> some View {
        switch tab {
        case .all:
            TabButton(title: "All", isSelected: model.categoryID == nil) {
                model.selectCategory(nil)
            }
        case .category(let category):
            TabButton(title: category.name, isSelected: model.categoryID == category.id) {
                model.selectCategory(category.id)
            }
        case .more:
            TabButton(title: "More", isSelected: moreIsChosen, showsChevron: true) {
                model.toggleMenu(.more)
            }
            .menuAnchor(.more)
        }
    }
}

/// Every category after the first three, then Add/Edit categories.
struct MoreMenu: View {
    @ObservedObject var model: ClipboardModel
    @Environment(\.accent) private var accent

    var body: some View {
        Dropdown {
            ForEach(model.categoryList.more, id: \.id) { category in
                DropdownRow(title: category.name, isChecked: model.categoryID == category.id) {
                    model.selectCategory(category.id)
                }
            }
            if !model.categoryList.more.isEmpty {
                DropdownDivider()
            }
            DropdownRow(title: "Add/Edit categories", symbol: "pencil", tint: accent) {
                model.editCategories()
            }
        }
    }
}

/// Behind the gear: the Reorder history and Save images as files switches, and Quit.
struct SettingsMenu: View {
    @ObservedObject var model: ClipboardModel
    let onQuit: () -> Void

    var body: some View {
        Dropdown {
            SettingsSwitchRow(title: "Reorder history",
                              help: "Move a clip to the top each time it is copied again",
                              isOn: $model.reordersHistory)
            SettingsSwitchRow(title: "Save images as files",
                              help: "Keep copied images as PNG files in Pictures › Notch Clipboard, and paste them as files",
                              isOn: $model.savesImagesAsFiles)
            DropdownDivider()
            DropdownRow(title: "Quit Clipboard", action: onQuit)
        }
    }
}

/// One settings line: a name and a switch. Clicking anywhere on the line flips it.
private struct SettingsSwitchRow: View {
    let title: String
    let help: String
    @Binding var isOn: Bool
    @State private var hovered = false

    private var fill: Color {
        if hovered {
            return Theme.cardHover
        }
        return .clear
    }

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(panelFont(12.5))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 6)
                SwitchToggle(isOn: $isOn)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 6) { hovered = $0 })
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
