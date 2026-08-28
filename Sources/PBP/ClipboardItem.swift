import Foundation

/// Freshly captured pasteboard content, before it becomes a stored item.
enum ClipboardContent {
    case text(String)
    case image(Data) // PNG bytes
    case files([URL])
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
        case files
    }

    let id: UUID
    let kind: Kind
    var text: String?
    var imageFilename: String?
    var filePaths: [String]?
    var createdAt: Date
    var pinned: Bool
    var appName: String?
    var appBundleID: String?
    let contentHash: String

    var previewTitle: String {
        switch kind {
        case .text:
            let firstLine = (text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first ?? ""
            return firstLine.isEmpty ? "Text" : firstLine
        case .image:
            return "Image"
        case .files:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            return names.joined(separator: ", ")
        }
    }
}
