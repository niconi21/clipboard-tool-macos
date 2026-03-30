import SwiftUI

/// Full-detail panel shown in the trailing column when an entry is selected.
struct EntryDetailView: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void

    @State private var collections: [Collection] = []
    private let collectionRepo = CollectionRepository()

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                headerRow
                Divider()
                contentSection
                metadataSection
            }
            .padding(Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if let id = entry.id {
                collections = (try? await collectionRepo.fetchCollections(forEntryId: id)) ?? []
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            contentTypeBadge
            Spacer()
            Button {
                onCopy()
            } label: {
                Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    private var contentTypeBadge: some View {
        Label(entry.contentType.displayName, systemImage: entry.contentType.iconName)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    // MARK: - Content section

    @ViewBuilder
    private var contentSection: some View {
        let codeLike: Set<ContentType> = [.code, .json, .sql, .shell, .markdown]
        if entry.contentType == .markdown {
            MarkdownPreviewView(content: entry.content)
                .frame(minHeight: 120)
        } else if codeLike.contains(entry.contentType) {
            SyntaxHighlightView(code: entry.content, contentType: entry.contentType)
                .frame(minHeight: 120)
        } else {
            Text(entry.content)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metadata section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider()

            metadataRow(
                icon: "calendar",
                label: String(localized: "Created"),
                value: entry.createdAt.formatted(date: .abbreviated, time: .shortened)
            )

            if let alias = entry.alias {
                metadataRow(icon: "tag", label: String(localized: "Alias"), value: alias)
            }

            if let sourceApp = entry.sourceApp {
                metadataRow(
                    icon: "app.badge",
                    label: String(localized: "Source"),
                    value: sourceApp
                )
            }

            if let windowTitle = entry.windowTitle {
                metadataRow(
                    icon: "macwindow",
                    label: String(localized: "Window"),
                    value: windowTitle
                )
            }

            if !collections.isEmpty {
                collectionsRow
            }
        }
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var collectionsRow: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(String(localized: "Collections"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)
            FlowLayout(spacing: Spacing.xs) {
                ForEach(collections, id: \.id) { collection in
                    collectionChip(collection)
                }
            }
        }
    }

    private func collectionChip(_ collection: Collection) -> some View {
        Text(collection.name)
            .font(.caption2)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(hex: collection.color).opacity(0.25))
            )
            .foregroundStyle(Color(hex: collection.color))
    }
}

// MARK: - FlowLayout helper (simple wrapping HStack)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        y += rowHeight
        return CGSize(width: maxWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - ContentType display helpers

private extension ContentType {
    var displayName: String {
        switch self {
        case .url:      return String(localized: "URL")
        case .email:    return String(localized: "Email")
        case .phone:    return String(localized: "Phone")
        case .color:    return String(localized: "Color")
        case .code:     return String(localized: "Code")
        case .text:     return String(localized: "Text")
        case .json:     return String(localized: "JSON")
        case .sql:      return String(localized: "SQL")
        case .shell:    return String(localized: "Shell")
        case .markdown: return String(localized: "Markdown")
        case .image:    return String(localized: "Image")
        }
    }

    var iconName: String {
        switch self {
        case .url:      return "link"
        case .email:    return "envelope"
        case .phone:    return "phone"
        case .color:    return "paintpalette"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .text:     return "doc.on.doc"
        case .json:     return "curlybraces"
        case .sql:      return "tablecells"
        case .shell:    return "terminal"
        case .markdown: return "text.alignleft"
        case .image:    return "photo"
        }
    }
}

// MARK: - Color from hex string

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
