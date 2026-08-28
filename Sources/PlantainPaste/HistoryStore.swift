import AppKit
import CryptoKit
import Foundation

/// Owns the clipboard history: in-memory list, JSON persistence, and image blobs on disk.
/// Everything runs on the main thread (timers, UI, hotkey callbacks all land there).
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    let maxItems = 500

    private let baseDir: URL
    private let imagesDir: URL
    private let historyFile: URL
    private var saveWorkItem: DispatchWorkItem?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDir = appSupport.appendingPathComponent("Plantain Paste", isDirectory: true)
        imagesDir = baseDir.appendingPathComponent("images", isDirectory: true)
        historyFile = baseDir.appendingPathComponent("history.json")
        // One-time migration from the app's earlier names.
        for legacyName in ["PBP", "ClipStack"] {
            let legacyDir = appSupport.appendingPathComponent(legacyName, isDirectory: true)
            if !FileManager.default.fileExists(atPath: baseDir.path),
               FileManager.default.fileExists(atPath: legacyDir.path) {
                try? FileManager.default.moveItem(at: legacyDir, to: baseDir)
            }
        }
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Mutations

    func add(_ content: ClipboardContent, from app: NSRunningApplication?) {
        let hash = Self.hash(of: content)

        // Re-copying something already in history moves it to the top instead of duplicating.
        if let existing = items.firstIndex(where: { $0.contentHash == hash }) {
            var item = items.remove(at: existing)
            item.createdAt = Date()
            items.insert(item, at: 0)
            scheduleSave()
            return
        }

        let id = UUID()
        var item = ClipboardItem(
            id: id,
            kind: .text,
            text: nil,
            imageFilename: nil,
            filePaths: nil,
            createdAt: Date(),
            pinned: false,
            appName: app?.localizedName,
            appBundleID: app?.bundleIdentifier,
            contentHash: hash
        )

        switch content {
        case .text(let string):
            item = ClipboardItem(
                id: id, kind: .text, text: string, imageFilename: nil, filePaths: nil,
                createdAt: item.createdAt, pinned: false,
                appName: item.appName, appBundleID: item.appBundleID, contentHash: hash
            )
        case .image(let pngData):
            let filename = "\(id.uuidString).png"
            do {
                try pngData.write(to: imagesDir.appendingPathComponent(filename))
            } catch {
                return
            }
            item = ClipboardItem(
                id: id, kind: .image, text: nil, imageFilename: filename, filePaths: nil,
                createdAt: item.createdAt, pinned: false,
                appName: item.appName, appBundleID: item.appBundleID, contentHash: hash
            )
        case .files(let urls):
            item = ClipboardItem(
                id: id, kind: .files, text: urls.map(\.lastPathComponent).joined(separator: " "),
                imageFilename: nil, filePaths: urls.map(\.path),
                createdAt: item.createdAt, pinned: false,
                appName: item.appName, appBundleID: item.appBundleID, contentHash: hash
            )
        }

        items.insert(item, at: 0)
        trim()
        scheduleSave()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].pinned.toggle()
        scheduleSave()
    }

    func delete(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        removeImageFile(for: items[idx])
        items.remove(at: idx)
        scheduleSave()
    }

    func clearUnpinned() {
        for item in items where !item.pinned {
            removeImageFile(for: item)
        }
        items.removeAll { !$0.pinned }
        scheduleSave()
    }

    func clearAll() {
        for item in items {
            removeImageFile(for: item)
        }
        items.removeAll()
        scheduleSave()
    }

    // MARK: - Files

    func imageURL(for item: ClipboardItem) -> URL? {
        guard let filename = item.imageFilename else { return nil }
        return imagesDir.appendingPathComponent(filename)
    }

    private func removeImageFile(for item: ClipboardItem) {
        guard let url = imageURL(for: item) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func trim() {
        while items.count > maxItems {
            guard let idx = items.lastIndex(where: { !$0.pinned }) else { break }
            removeImageFile(for: items[idx])
            items.remove(at: idx)
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: historyFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([ClipboardItem].self, from: data) {
            items = decoded
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }

    // MARK: - Hashing

    static func hash(of content: ClipboardContent) -> String {
        let data: Data
        switch content {
        case .text(let string):
            data = Data(string.utf8)
        case .image(let png):
            data = png
        case .files(let urls):
            data = Data(urls.map(\.path).joined(separator: "\n").utf8)
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
