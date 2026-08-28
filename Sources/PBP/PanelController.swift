import AppKit
import SwiftUI

/// Borderless panel that can become key without activating the app,
/// so the app you're pasting into keeps focus (Alfred/Spotlight-style).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    private let store: HistoryStore
    private var panel: KeyablePanel?
    private var viewModel: PanelViewModel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var accessibilityPromptShown = false

    init(store: HistoryStore) {
        self.store = store
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        hide()

        let model = PanelViewModel(store: store)
        model.onPaste = { [weak self] item in self?.paste(item) }
        model.onClose = { [weak self] in self?.hide() }
        viewModel = model

        let hosting = NSHostingView(rootView: PanelView(store: store, model: model))

        let screen = screenWithMouse()
        let visible = screen.visibleFrame
        let width = min(visible.width - 40, 1280)
        let height: CGFloat = 340
        let rect = NSRect(
            x: visible.midX - width / 2,
            y: visible.minY + 16,
            width: width,
            height: height
        )

        let panel = KeyablePanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.delegate = self

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
        viewModel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Pasting

    private func paste(_ item: ClipboardItem) {
        hide()

        if !PasteService.hasAccessibilityAccess && !accessibilityPromptShown {
            accessibilityPromptShown = true
            PasteService.requestAccessibilityAccess()
        }

        PasteService.copyToPasteboard(item, store: store)
        // Give the panel a beat to close so key focus is back
        // in the target app before we synthesize ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.sendPasteKeystroke()
        }
    }

    // MARK: - Event monitors

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
        // Clicks in other apps close the panel (global monitor never sees our own clicks).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let model = viewModel else { return false }

        switch event.keyCode {
        case 53: // escape
            hide()
            return true
        case 36, 76: // return, keypad enter
            model.pasteSelected()
            return true
        case 123, 126: // left, up
            model.moveSelection(by: -1)
            return true
        case 124, 125: // right, down
            model.moveSelection(by: 1)
            return true
        default:
            break
        }

        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                if let digit = Int(chars), (1...9).contains(digit) {
                    model.paste(at: digit - 1)
                    return true
                }
                if chars == "p" {
                    model.togglePinSelected()
                    return true
                }
            }
            if event.keyCode == 51 { // cmd+delete
                model.deleteSelected()
                return true
            }
        }
        return false
    }

    private func screenWithMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
