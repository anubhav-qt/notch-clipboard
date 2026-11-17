import SwiftUI

/// The Add/Edit categories sheet. It edits a copy; Done saves it, Escape throws it away.
struct CategoryEditor: View {
    @ObservedObject var model: ClipboardModel
    @Environment(\.accent) private var accent
    @FocusState private var focusedRow: String?
    @State private var dragging: String?
    @State private var dragStart = 0
    @State private var addHovered = false
    /// When the last row was removed, so a double click on × removes only one.
    @State private var lastRemoval = Date.distantPast

    static let rowHeight: CGFloat = 26
    static let rowSpacing: CGFloat = 6
    /// More rows than this scroll, so the sheet always fits under the notch.
    static let visibleRows = 6
    private static let rowsSpace = "categoryRows"

    private var draft: CategoryDraft {
        model.categoryDraft ?? CategoryDraft(model.categoryList)
    }

    private var allPosition: Binding<Bool> {
        Binding {
            draft.allIsLast
        } set: { isLast in
            model.categoryDraft?.allIsLast = isLast
        }
    }

    /// The rows show in full up to six. Past that they scroll, and half a row peeks out to say so.
    private var rowsHeight: CGFloat {
        let shown = min(draft.rows.count, Self.visibleRows)
        var height = CGFloat(shown) * Self.rowHeight + CGFloat(max(shown - 1, 0)) * Self.rowSpacing
        if draft.rows.count > Self.visibleRows {
            height += Self.rowSpacing + Self.rowHeight / 2
        }
        return height
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .contentShape(Rectangle())
                .onTapGesture {}
            ScrollViewReader { scroller in
                VStack(alignment: .leading, spacing: 10) {
                    allRow
                    Rectangle().fill(Theme.line).frame(height: 1)
                    ScrollView {
                        rows
                    }
                    .frame(height: rowsHeight)
                    .onChange(of: draft.rows.count) { before, after in
                        // A new row is added at the end; bring it into view once it exists.
                        if after > before, let last = draft.rows.last {
                            scroller.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    if draft.canAdd {
                        addRow
                    }
                    footer
                }
            }
            .padding(16)
            .frame(width: 380)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.3), lineWidth: 0.7).allowsHitTesting(false))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {}
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Add or edit categories")
            .padding(.top, model.notchHeight)
        }
    }

    /// All can't be renamed, only placed first or last among the tabs.
    private var allRow: some View {
        HStack {
            Text("All")
                .font(panelFont(12.5))
                .foregroundStyle(Theme.dimText)
                .padding(.horizontal, 9)
                .frame(width: 150, height: Self.rowHeight, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.03)))
            Spacer()
            SquircleToggle(options: [ToggleOption(title: "First", value: false), ToggleOption(title: "Last", value: true)],
                           selection: allPosition)
        }
    }

    private var rows: some View {
        VStack(spacing: Self.rowSpacing) {
            ForEach(Array(draft.rows.enumerated()), id: \.element.id) { index, row in
                CategoryRow(
                    name: nameBinding(for: row.id),
                    isDragging: dragging == row.id,
                    canRemove: draft.canRemove,
                    focus: $focusedRow,
                    id: row.id,
                    onRemove: { remove(row.id) },
                    drag: dragGesture(for: row.id, at: index))
                .id(row.id)
                .overlay(alignment: .bottom) {
                    if index == CategoryList.tabCount - 1 && draft.rows.count > CategoryList.tabCount {
                        // Where More starts. It sits in the gap, so every row keeps the same pitch.
                        DashedLine().offset(y: Self.rowSpacing / 2 + 0.5)
                    }
                }
            }
        }
        .coordinateSpace(name: Self.rowsSpace)
    }

    private var addRow: some View {
        Button {
            if let id = model.categoryDraft?.add() {
                focusedRow = id
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                Text("Add category").font(panelFont(12.5))
            }
            .foregroundStyle(accent)
            .opacity(addHovered ? 1 : 0.85)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
            .background(HoverRegion(cornerRadius: 0) { addHovered = $0 })
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add category")
    }

    /// The hint, or in its place the reason Done is waiting.
    private var footer: some View {
        HStack {
            if let problem = draft.problem {
                Text(problem)
                    .font(panelFont(11))
                    .foregroundStyle(Theme.problem)
            } else {
                Text("Hold and drag \(Image(systemName: "circle.grid.3x3.fill")) to reorder")
                    .font(panelFont(11))
                    .foregroundStyle(Theme.faintText)
            }
            Spacer()
            PanelButton(title: "Done", primary: true, height: 28) { model.saveCategoryDraft() }
                .frame(width: 76)
                .disabled(draft.problem != nil)
        }
    }

    /// Removing reshapes the sheet, so a quick second click could land on the next row's ×. Ignore it.
    private func remove(_ id: String) {
        let now = Date()
        if now.timeIntervalSince(lastRemoval) < 0.4 {
            return
        }
        lastRemoval = now
        model.categoryDraft?.remove(id: id)
    }

    private func nameBinding(for id: String) -> Binding<String> {
        Binding {
            draft.name(id: id)
        } set: { name in
            model.categoryDraft?.rename(id: id, to: name)
        }
    }

    /// Dragging the dots by one row pitch moves the row by one place.
    private func dragGesture(for id: String, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.rowsSpace))
            .onChanged { drag in
                if dragging != id {
                    dragging = id
                    dragStart = index
                }
                let pitch = Self.rowHeight + Self.rowSpacing
                let steps = Int((drag.translation.height / pitch).rounded())
                model.categoryDraft?.move(id: id, to: dragStart + steps)
            }
            .onEnded { _ in
                dragging = nil
            }
    }
}

/// One category: drag dots, its name, and a remove button.
private struct CategoryRow<Drag: Gesture>: View {
    @Binding var name: String
    let isDragging: Bool
    let canRemove: Bool
    var focus: FocusState<String?>.Binding
    let id: String
    let onRemove: () -> Void
    let drag: Drag
    @Environment(\.accent) private var accent
    @State private var removeHovered = false
    @State private var handleHovered = false
    /// The field's own text. Kept separate so a cut to 20 characters shows in the field too.
    @State private var text = ""

    private var outline: Color {
        if isDragging {
            return accent.opacity(0.7)
        }
        return .clear
    }

    private var removeColor: Color {
        if removeHovered && canRemove {
            return Theme.text
        }
        return Theme.faintText
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.grid.3x3.fill")
                .font(.system(size: 9))
                .foregroundStyle(handleHovered || isDragging ? Theme.text : Theme.faintText)
                .frame(width: 22, height: CategoryEditor.rowHeight)
                .contentShape(Rectangle())
                .background(HoverRegion(cornerRadius: 4) { handleHovered = $0 })
                .gesture(drag)
                .help("Drag to reorder")
                .accessibilityLabel("Reorder \(name)")
            TextField("Name", text: $text)
                .onAppear { text = name }
                .onChange(of: text) { _, typed in
                    let capped = String(typed.prefix(ClipCategory.maxNameLength))
                    if capped != typed {
                        text = capped
                        return
                    }
                    name = capped
                }
                .onChange(of: name) { _, stored in
                    if stored != text {
                        text = stored
                    }
                }
                .textFieldStyle(.plain)
                .font(panelFont(12.5))
                .focused(focus, equals: id)
                .padding(.horizontal, 9)
                .frame(height: CategoryEditor.rowHeight)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(outline, lineWidth: 1))
                .accessibilityLabel("Category name")
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(removeColor)
                    .frame(width: 24, height: CategoryEditor.rowHeight)
                    .contentShape(Rectangle())
                    .background(HoverRegion(cornerRadius: 4) { removeHovered = $0 })
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .help("Remove \(name)")
            .accessibilityLabel("Remove \(name)")
        }
    }
}

/// A plain dashed rule with no text.
private struct DashedLine: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            .stroke(Theme.faintText, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(height: 1)
    }
}
