import Foundation

/// Bounded event timings only. No copied text, images, entry IDs or mouse paths.
final class TimingLog: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.notchclipboard.timings", qos: .utility)
    private let file: URL
    init(directory: URL) { file = directory.appendingPathComponent("timing.jsonl") }
    func record(_ event: String, fields: [String: Any] = [:]) {
        var record = fields
        record["event"] = event
        record["time"] = Date().timeIntervalSince1970
        record["uptime"] = ProcessInfo.processInfo.systemUptime
        guard var data = try? JSONSerialization.data(withJSONObject: record, options: .sortedKeys) else { return }
        data.append(0x0a)
        let snapshot = data
        queue.async { [file] in
            do {
                let manager = FileManager.default
                try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let size = (try? manager.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
                if size + snapshot.count > 1_048_576 {
                    let previous = file.deletingLastPathComponent().appendingPathComponent("timing-previous.jsonl")
                    if manager.fileExists(atPath: previous.path) { try manager.removeItem(at: previous) }
                    try manager.moveItem(at: file, to: previous)
                }
                if !manager.fileExists(atPath: file.path) {
                    manager.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
                }
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: snapshot)
            } catch { /* Diagnostics must not interrupt clipboard interaction. */ }
        }
    }
    func flush() { queue.sync {} }
}
