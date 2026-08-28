import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = HistoryStore()
    private lazy var panelController = PanelController(store: store)
    private let monitor = ClipboardMonitor()
    private let hotkey = HotkeyManager()

    private var launchAtLoginItem: NSMenuItem!
    private var accessibilityItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        monitor.onCapture = { [weak self] content, app in
            self?.store.add(content, from: app)
        }
        monitor.start()

        hotkey.onHotkey = { [weak self] in
            self?.panelController.toggle()
        }
        hotkey.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
        hotkey.unregister()
        monitor.stop()
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "PBP"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        let openItem = NSMenuItem(title: "Open Clipboard History", action: #selector(openPanel), keyEquivalent: "v")
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        accessibilityItem = NSMenuItem(title: "Enable Auto-Paste (Accessibility)…", action: #selector(enableAutoPaste), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear Unpinned History", action: #selector(clearUnpinned), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let clearAllItem = NSMenuItem(title: "Clear Everything…", action: #selector(clearEverything), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit PBP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        if isRunningFromAppBundle {
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchAtLoginItem.isEnabled = false
            launchAtLoginItem.toolTip = "Run the built PBP.app to enable this"
        }
        accessibilityItem.state = PasteService.hasAccessibilityAccess ? .on : .off
    }

    private var isRunningFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // MARK: - Actions

    @objc private func openPanel() {
        panelController.show()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showAlert(
                title: "Couldn’t change Launch at Login",
                message: error.localizedDescription
            )
        }
    }

    @objc private func enableAutoPaste() {
        if PasteService.hasAccessibilityAccess {
            showAlert(
                title: "Auto-Paste is enabled",
                message: "PBP has Accessibility access and will paste selected items directly into the frontmost app."
            )
        } else {
            PasteService.requestAccessibilityAccess()
            PasteService.openAccessibilitySettings()
        }
    }

    @objc private func clearUnpinned() {
        store.clearUnpinned()
    }

    @objc private func clearEverything() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This deletes every item, including pinned ones. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear Everything")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
