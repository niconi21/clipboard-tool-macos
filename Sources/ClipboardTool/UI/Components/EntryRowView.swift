import SwiftUI

struct EntryRowView: View {
    let entry: ClipboardEntry

    @State private var collections: [Collection] = []
    private let collectionRepo = CollectionRepository()

    // MARK: - Cached formatters

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                // Content type icon
                Image(systemName: entry.contentType.iconName)
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
                        .foregroundStyle(Color(nsColor: .systemYellow))
                        .accessibilityLabel(String(localized: "Favorite"))
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
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: now)
    }

}


