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

        assert(AccentColor(hex: "#FFF") == AccentColor(hex: "#FFFFFF"))
        assert(AccentColor(hex: "a1c")?.hex == "#AA11CC")
        assert(AccentColor.hexDigits(from: "#ff00aa") == "FF00AA")
        assert(AccentColor.hexDigits(from: " 12 34 56 78 ") == "123456")
        assert(AccentColor.hexDigits(from: "zz💥#q") == "")
        assert(AccentColor.hexDigits(from: "") == "")
        print("PASS: short hex works and typed text is cut down to six hex digits")

        let wild = AccentColor(red: .nan, green: 2, blue: -1)
        assert(wild.red == 0 && wild.green == 1 && wild.blue == 0)
        let wildShade = AccentShade(hue: .nan, saturation: 9, brightness: -3)
        assert(wildShade.hue == 0 && wildShade.saturation == 1 && wildShade.brightness == 0)
        print("PASS: colour parts are clamped")

        var missed: [String] = []
        for red in stride(from: 0, through: 255, by: 15) {
            for green in stride(from: 0, through: 255, by: 15) {
                for blue in stride(from: 0, through: 255, by: 15) {
                    let color = AccentColor(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
                    if AccentShade(color).accent != color {
                        missed.append(color.hex)
                    }
                }
            }
        }
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<5000 {
            let value = UInt32.random(in: 0...0xFFFFFF, using: &generator)
            let color = AccentColor(hex: String(format: "%06X", value))!
            if AccentShade(color).accent != color {
                missed.append(color.hex)
            }
        }
        assert(missed.isEmpty, "Shade square cannot reach \(missed.prefix(5))")
        print("PASS: every colour, white, black and greys included, can be reached by hue, strength and brightness")

        let white = AccentColor(hex: "#FFFFFF")!
        let black = AccentColor(hex: "#000000")!
        let grey = AccentColor(hex: "#808080")!
        assert(AccentShade(hue: 0.3, saturation: 0, brightness: 1).accent == white)
        assert(AccentShade(hue: 0.7, saturation: 1, brightness: 0).accent == black)
        assert(AccentShade(hue: 0, saturation: 1, brightness: 1).accent.hex == "#FF0000")
        let green = AccentShade(hue: 1.0 / 3, saturation: 0.8, brightness: 0.6)
        let toWhite = green.following(white)
        assert(toWhite.hue == green.hue && toWhite.saturation == 0 && toWhite.brightness == 1, "White keeps the hue")
        let toGrey = green.following(grey)
        assert(toGrey.hue == green.hue && toGrey.saturation == 0, "Grey keeps the hue")
        let toBlack = green.following(black)
        assert(toBlack.hue == green.hue && toBlack.saturation == green.saturation && toBlack.brightness == 0, "Black keeps hue and strength")
        let toPurple = green.following(.purple)
        assert(toPurple.accent == .purple, "A real colour moves the square to it")
        let fromWhite = toWhite.with(hue: 0.5)
        assert(fromWhite.saturation == AccentShade.softSaturation && fromWhite.brightness == 1, "A hue picked on white shows up soft")
        let fromBlack = toBlack.with(hue: 0.5)
        assert(fromBlack.brightness == 1, "A hue picked on black shows up")
        let purpleShade = AccentShade(.purple)
        let cyan = purpleShade.with(hue: 0.5)
        assert(cyan.saturation == purpleShade.saturation && cyan.brightness == purpleShade.brightness, "A hue keeps a real colour's strength")
        assert(AccentShade(hue: 0, saturation: 1, brightness: 1).accent == AccentShade(hue: 1, saturation: 1, brightness: 1).accent)
        print("PASS: the picker keeps its hue through white, grey and black, and a new hue on grey shows up")

        let size = CGSize(width: 200, height: 64)
        assert(ShadeSquare.spot(at: .zero, in: size)! == (0, 1), "Top left is white")
        assert(ShadeSquare.spot(at: CGPoint(x: 200, y: 0), in: size)! == (1, 1), "Top right is the full hue")
        assert(ShadeSquare.spot(at: CGPoint(x: 100, y: 64), in: size)!.brightness == 0, "The bottom is black")
        assert(ShadeSquare.spot(at: CGPoint(x: -50, y: -50), in: size)! == (0, 1), "Past the top left stops at white")
        assert(ShadeSquare.spot(at: CGPoint(x: 999, y: 999), in: size)! == (1, 0), "Past the bottom right stops at black")
        assert(ShadeSquare.spot(at: .zero, in: .zero) == nil, "A square with no size picks nothing")
        assert(ShadeSquare.spot(at: CGPoint(x: CGFloat.nan, y: 10), in: size)!.saturation == 0)
        print("PASS: the shade square maps corners right and stays in range")

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
