import AppKit
import SwiftUI

@main struct SavedRemovalTests {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let file = directory.appendingPathComponent("saved.plist")
        let store = ClipboardStore(board: board, file: file)
        for text in ["alpha", "beta"] {
            board.clearContents(); board.setString(text, forType: .string); assert(store.poll())
        }
        for entry in store.entries { assert(store.toggleSaved(id: entry.id)) }
        let model = ClipboardModel(store: store, categorizer: nil, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let alpha = model.entries.first { $0.title == "alpha" }!
        let beta = model.entries.first { $0.title == "beta" }!
        var version = board.changeCount
        model.toggleSaved(alpha)
        assert(model.pendingSavedRemovalID == alpha.id && store.isSaved(id: alpha.id))
        model.choose(beta)
        model.toggleSaved(beta)
        assert(board.changeCount == version && model.pendingSavedRemovalID == alpha.id && store.isSaved(id: beta.id))
        model.finishSavedRemoval(remove: false)
        assert(!model.isConfirmingSavedRemoval && store.isSaved(id: alpha.id))
        model.toggleSaved(alpha)
        model.finishSavedRemoval(remove: true)
        assert(!store.isSaved(id: alpha.id))
        model.toggleSaved(alpha)
        assert(!model.isConfirmingSavedRemoval && store.isSaved(id: alpha.id))
        print("PASS: No keeps, Yes removes, adding never prompts, and confirmation blocks underlying row actions")

        model.toggleSaved(alpha)
        model.skipPendingRemovalConfirmation = true
        model.cancelSavedRemoval()
        assert(store.isSaved(id: alpha.id) && !model.skipsSavedRemovalConfirmation)
        assert(!model.isConfirmingSavedRemoval && !model.skipPendingRemovalConfirmation)
        print("PASS: dismissing cancels removal and discards an unconfirmed checkbox change")

        model.toggleSaved(alpha)
        model.skipPendingRemovalConfirmation = true
        model.finishSavedRemoval(remove: true)
        model.filter = .saved
        model.query = "beta"
        model.reload()
        model.toggleSaved(beta)
        assert(!store.isSaved(id: beta.id) && !model.isConfirmingSavedRemoval && model.skipsSavedRemovalConfirmation)
        model.toggleSaved(alpha)
        model.clear()
        assert(model.skipsSavedRemovalConfirmation && store.isSaved(id: alpha.id) && board.changeCount == version)
        model.shutdown()
        print("PASS: session preference survives filters, reloads and history clearing without touching the clipboard")

        let reloaded = ClipboardStore(board: board, file: file)
        let restarted = ClipboardModel(store: reloaded, categorizer: nil, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        restarted.filter = .saved
        assert(!restarted.skipsSavedRemovalConfirmation && restarted.entries.count == 1)
        let saved = restarted.entries[0]
        restarted.toggleSaved(saved)
        assert(restarted.isConfirmingSavedRemoval)
        restarted.cancelSavedRemoval()
        print("PASS: a new app session asks again")
        // Keep a session copy so this fixture can be saved again after removal.
        assert(reloaded.choose(id: alpha.id))
        version = board.changeCount

        let panel = NotchPanel(contentRect: NSRect(x: 300, y: 300, width: 560, height: 440), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        let host = HostingView(rootView: HistoryView(model: restarted))
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        let originalMouse = NSEvent.mouseLocation
        defer {
            panel.orderOut(nil)
            CGWarpMouseCursorPosition(CGPoint(x: originalMouse.x, y: NSScreen.screens.first!.frame.maxY - originalMouse.y))
        }
        func pump() {
            let deadline = Date(timeIntervalSinceNow: 0.12)
            while Date() < deadline {
                if let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) { app.sendEvent(event) }
                app.updateWindows()
            }
            host.layoutSubtreeIfNeeded()
        }
        func click(_ x: CGFloat, _ y: CGFloat) {
            let point = CGPoint(x: panel.frame.minX + x, y: NSScreen.screens.first!.frame.maxY - panel.frame.minY - y)
            CGWarpMouseCursorPosition(point)
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            pump()
        }
        restarted.toggleSaved(saved)
        pump()
        assert(restarted.isConfirmingSavedRemoval && NSApp.modalWindow == nil)
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: directory.deletingLastPathComponent().appendingPathComponent("removal-dialog.png"))
        click(110, 220)
        assert(restarted.isConfirmingSavedRemoval, "Blank card padding must not dismiss")
        click(30, 220)
        assert(!restarted.isConfirmingSavedRemoval && reloaded.isSaved(id: alpha.id) && board.changeCount == version)
        print("PASS: confirmation is visible in the same panel; clicking the backdrop dismisses without removing or copying")

        restarted.toggleSaved(saved)
        pump()
        let outside = NSWindow(contentRect: NSRect(x: 20, y: 40, width: 120, height: 80), styleMask: [.borderless], backing: .buffered, defer: false)
        outside.isReleasedWhenClosed = false
        outside.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary]
        outside.level = panel.level
        outside.orderFrontRegardless()
        let outsidePoint = CGPoint(x: 50, y: NSScreen.screens.first!.frame.maxY - 70)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: outsidePoint, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        pump()
        assert(!restarted.isConfirmingSavedRemoval && reloaded.isSaved(id: alpha.id))
        outside.orderOut(nil)
        print("PASS: a native click in another window dismisses the confirmation")
        restarted.toggleSaved(saved)
        pump()
        click(203, 176)
        assert(!restarted.isConfirmingSavedRemoval && reloaded.isSaved(id: alpha.id))
        restarted.toggleSaved(saved)
        pump()
        click(358, 176)
        assert(!restarted.isConfirmingSavedRemoval && !reloaded.isSaved(id: alpha.id))
        print("PASS: native mouse clicks on No and Yes perform the correct actions")
        restarted.toggleSaved(saved)
        restarted.toggleSaved(saved)
        pump()
        assert(restarted.isConfirmingSavedRemoval)
        click(138, 226)
        assert(restarted.skipPendingRemovalConfirmation)
        click(203, 176)
        assert(restarted.skipsSavedRemovalConfirmation && reloaded.isSaved(id: alpha.id))
        restarted.toggleSaved(saved)
        assert(!restarted.isConfirmingSavedRemoval && !reloaded.isSaved(id: alpha.id))
        restarted.shutdown()
        print("PASS: native checkbox click suppresses later removal confirmations for the session")
    }
}
