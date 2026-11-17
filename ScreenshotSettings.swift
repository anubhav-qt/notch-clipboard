import Foundation

enum ScreenshotSettings {
    private static let domain = "com.apple.symbolichotkeys"
    private static let ids = ["28", "29", "30", "31"]
    static func configure(restore: Bool) throws {
        let directory = clipboardDataDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let backup = directory.appendingPathComponent("screenshot-shortcuts-before.plist")
        let output = try run("/usr/bin/defaults", ["export", domain, "-"])
        guard var preferences = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any] else { throw CocoaError(.propertyListReadCorrupt) }
        var hotkeys = preferences["AppleSymbolicHotKeys"] as? [String: Any] ?? [:]
        if restore {
            let data = try Data(contentsOf: backup)
            guard let original = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw CocoaError(.propertyListReadCorrupt) }
            for id in ids {
                // The backup stores the string "absent" for a shortcut that did not exist.
                if let value = original[id], !(value is String) {
                    hotkeys[id] = value
                } else {
                    hotkeys.removeValue(forKey: id)
                }
            }
        } else {
            if !FileManager.default.fileExists(atPath: backup.path) {
                var original: [String: Any] = [:]
                for id in ids { original[id] = hotkeys[id] ?? "absent" }
                try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0).write(to: backup, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
            }
            for (id, character, key, modifiers) in [("28", 51, 20, 1441792), ("29", 51, 20, 1179648), ("30", 52, 21, 1441792), ("31", 52, 21, 1179648)] {
                hotkeys[id] = ["enabled": true, "value": ["type": "standard", "parameters": [character, key, modifiers]]]
            }
        }
        preferences["AppleSymbolicHotKeys"] = hotkeys
        let temporary = directory.appendingPathComponent("shortcut-update.plist")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0).write(to: temporary, options: .atomic)
        _ = try run("/usr/bin/defaults", ["import", domain, temporary.path])
        _ = try run("/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", ["-u"])
        print(restore ? "Original screenshot shortcuts restored." : "Command-Shift-3/4 now copy screenshots to the clipboard.")
    }
    private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "ScreenshotSettings", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Could not run \(executable)"]) }
        return data
    }
}
