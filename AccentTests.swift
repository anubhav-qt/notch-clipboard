import AppKit

@main struct AccentTests {
    @MainActor static func main() {
        assert(AccentColor.purple.hex == "#BFA5FF")
        assert(AccentColor(hex: "#BFA5FF") == .purple)
        assert(AccentColor(hex: "bfa5ff") == .purple)
        assert(AccentColor(hex: "  #BFA5FF ") == .purple)
        for bad in ["", "#", "#BFA5F", "#BFA5FFF", "#GGGGGG", "+BFA5F", "-00000", "BF A5F", "#BFA5FF\n", "🎨🎨🎨"] {
            assert(AccentColor(hex: bad) == nil, "Accepted \(bad)")
        }
        print("PASS: hex colours read both spellings and reject anything else")

        let wild = AccentColor(red: .nan, green: 2, blue: -1)
        assert(wild.red == 0 && wild.green == 1 && wild.blue == 0)
        assert(AccentColor(hue: 0) == AccentColor(hue: 1))
        assert(AccentColor(hue: -0.25) == AccentColor(hue: 0.75))
        assert(AccentColor(hue: 3.5) == AccentColor(hue: 0.5))
        print("PASS: colour parts are clamped and hues wrap around")

        assert(HueBar.hue(at: -20, width: 200) == 0)
        assert(HueBar.hue(at: 100, width: 200) == 0.5)
        assert(HueBar.hue(at: 900, width: 200) == 0.999)
        assert(HueBar.hue(at: 50, width: 0) == 0)
        print("PASS: dragging past either end of the hue bar stays in range")

        assert(AccentColor.presets.first?.color == .purple)
        assert(Set(AccentColor.presets.map(\.name)).count == AccentColor.presets.count)
        assert(Set(AccentColor.presets.map(\.color.hex)).count == AccentColor.presets.count)
        print("PASS: presets start with purple and have no duplicates")

        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        func makeModel() -> ClipboardModel {
            ClipboardModel(store: ClipboardStore(board: board, file: file), categorizer: nil, defaults: defaults)
        }
        let first = makeModel()
        assert(first.accent == .purple)
        let coral = AccentColor.presets[1].color
        first.accent = coral
        assert(defaults.string(forKey: ClipboardModel.accentKey) == coral.hex)
        assert(makeModel().accent == coral)
        first.resetAccent()
        assert(first.accent == .purple)
        assert(makeModel().accent == .purple)
        defaults.set("not a colour", forKey: ClipboardModel.accentKey)
        assert(makeModel().accent == .purple)
        defaults.set(42, forKey: ClipboardModel.accentKey)
        assert(makeModel().accent == .purple)
        print("PASS: the chosen accent survives a relaunch, resets to purple and ignores bad stored values")
    }
}
