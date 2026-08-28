import Foundation

/// UI state for one showing of the panel: search query and keyboard selection.
final class PanelViewModel: ObservableObject {
    @Published var query = "" {
        didSet { selection = 0 }
    }
    @Published var selection = 0

    let store: HistoryStore
    var onPaste: ((ClipboardItem) -> Void)?
    var onClose: (() -> Void)?

    init(store: HistoryStore) {
        self.store = store
    }

    /// Pinned items first, then newest first, filtered by the query.
    var filtered: [ClipboardItem] {
        let sorted = store.items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.createdAt > b.createdAt
        }
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return sorted }
        return sorted.filter { item in
            if let text = item.text, text.localizedCaseInsensitiveContains(trimmedQuery) { return true }
            if let app = item.appName, app.localizedCaseInsensitiveContains(trimmedQuery) { return true }
            if item.kind == .image, "image".localizedCaseInsensitiveContains(trimmedQuery) { return true }
            return false
        }
    }

    var selectedItem: ClipboardItem? {
        let list = filtered
        guard list.indices.contains(selection) else { return nil }
        return list[selection]
    }

    func moveSelection(by delta: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    func clampSelection() {
        let count = filtered.count
        if count == 0 {
            selection = 0
        } else if selection >= count {
            selection = count - 1
        }
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        onPaste?(item)
    }

    func paste(at index: Int) {
        let list = filtered
        guard list.indices.contains(index) else { return }
        onPaste?(list[index])
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        store.delete(item)
        clampSelection()
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        store.togglePin(item)
    }
}
