import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Writes an item back to the pasteboard and (when Accessibility access is
/// granted) synthesizes ⌘V into the frontmost app so it pastes in place.
enum PasteService {
    static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func copyToPasteboard(_ item: ClipboardItem, store: HistoryStore) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image:
            guard let url = store.imageURL(for: item),
                  let png = try? Data(contentsOf: url) else { return }
            pasteboard.setData(png, forType: .png)
            if let rep = NSBitmapImageRep(data: png),
               let tiff = rep.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .files:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }
    }

    /// Sends ⌘V to the frontmost application. No-op without Accessibility access
    /// (the item is already on the pasteboard, so a manual ⌘V still works).
    static func sendPasteKeystroke() {
        guard hasAccessibilityAccess else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
