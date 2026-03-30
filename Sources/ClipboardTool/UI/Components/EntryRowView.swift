import SwiftUI

struct EntryRowView: View {
    let entry: ClipboardEntry

    var body: some View {
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

            // Favorite indicator
            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .frame(minHeight: 44)
    }

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
        }
    }
}
