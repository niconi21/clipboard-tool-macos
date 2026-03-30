import SwiftUI

struct EntryRowView: View {
    let entry: ClipboardEntry

    @State private var collections: [Collection] = []
    private let collectionRepo = CollectionRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                // Content type icon
                Image(systemName: iconName(for: entry.contentType))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                // Text preview — truncated to 1 line
                Text(entry.content)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // #22 — Relative timestamp
                Text(relativeDate(entry.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Favorite indicator
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }
            }

            // #23 — Alias row, shown only when set
            if let alias = entry.alias {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "tag")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(alias)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 28)
            }

            // #24 — Collection chips, loaded lazily
            if !collections.isEmpty {
                collectionChips
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .frame(minHeight: 44)
        .task(id: entry.id) {
            guard let id = entry.id else { return }
            collections = (try? await collectionRepo.fetchCollections(forEntryId: id)) ?? []
        }
    }

    // MARK: - Collection chips

    private var collectionChips: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(collections, id: \.id) { collection in
                Text(collection.name)
                    .font(.caption2)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(hex: collection.color).opacity(0.20))
                    )
                    .foregroundStyle(Color(hex: collection.color))
            }
        }
    }

    // MARK: - Relative date helper (#22)

    /// Returns a short human-readable relative time string.
    func relativeDate(_ date: Date) -> String {
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 {
            return String(localized: "Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: now)
    }

    // MARK: - Icon mapping

    private func iconName(for type: ContentType) -> String {
        switch type {
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
