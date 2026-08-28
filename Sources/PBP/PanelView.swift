import AppKit
import SwiftUI

// MARK: - Panel

struct PanelView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var model: PanelViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard…", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .frame(maxWidth: 300)

            Text("\(model.filtered.count) item\(model.filtered.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("↩ paste   ⌘1–9 quick paste   ⌘P pin   ⌘⌫ delete   esc close")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if model.filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text(model.query.isEmpty ? "Clipboard history is empty — copy something!" : "No matches for “\(model.query)”")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(model.filtered.enumerated()), id: \.element.id) { index, item in
                            CardView(
                                item: item,
                                index: index,
                                isSelected: index == model.selection,
                                store: store
                            )
                            .id(item.id)
                            .onTapGesture {
                                model.selection = index
                                model.onPaste?(item)
                            }
                            .contextMenu {
                                Button(item.pinned ? "Unpin" : "Pin") { store.togglePin(item) }
                                Button("Copy Without Pasting") {
                                    PasteService.copyToPasteboard(item, store: store)
                                    model.onClose?()
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    store.delete(item)
                                    model.clampSelection()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: model.selection) { newValue in
                    let list = model.filtered
                    guard list.indices.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(list[newValue].id)
                    }
                }
            }
        }
    }
}

// MARK: - Card

struct CardView: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let store: HistoryStore

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            cardBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cardFooter
        }
        .frame(width: 210, height: 250)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
    }

    private var cardHeader: some View {
        HStack(spacing: 6) {
            if let icon = AppIconCache.icon(forBundleID: item.appBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(item.appName ?? "Clipboard")
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer()
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }
            Text(Self.relativeFormatter.localizedString(for: item.createdAt, relativeTo: Date()))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }

    @ViewBuilder
    private var cardBody: some View {
        switch item.kind {
        case .text:
            Text((item.text ?? "").prefix(600))
                .font(.system(size: 11.5))
                .lineLimit(11)
                .multilineTextAlignment(.leading)
                .padding(10)
        case .image:
            if let url = store.imageURL(for: item),
               let image = ThumbnailCache.image(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 210, height: 178)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .files:
            VStack(alignment: .leading, spacing: 6) {
                ForEach((item.filePaths ?? []).prefix(6), id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text((path as NSString).lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
                if (item.filePaths?.count ?? 0) > 6 {
                    Text("+ \((item.filePaths?.count ?? 0) - 6) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
    }

    private var cardFooter: some View {
        HStack {
            Text(footerLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    private var footerLabel: String {
        switch item.kind {
        case .text:
            let count = item.text?.count ?? 0
            return "\(count) character\(count == 1 ? "" : "s")"
        case .image:
            return "Image"
        case .files:
            let count = item.filePaths?.count ?? 0
            return "\(count) file\(count == 1 ? "" : "s")"
        }
    }
}

// MARK: - Caches

enum ThumbnailCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = icon
        return icon
    }
}

// MARK: - Visual effect background

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
