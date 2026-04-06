import SwiftUI

/// Renders markdown content with a toggle between raw source and rendered preview.
struct MarkdownPreviewView: View {
    let content: String

    @State private var showPreview: Bool = true
    @State private var cachedAttributed: AttributedString?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mode toggle toolbar
            HStack {
                Spacer()
                Button {
                    withAnimation(Animations.list) {
                        showPreview.toggle()
                    }
                } label: {
                    Label(
                        showPreview
                            ? String(localized: "Raw")
                            : String(localized: "Preview"),
                        systemImage: showPreview ? "doc.plaintext" : "eye"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .padding(.trailing, Spacing.sm)
                .padding(.top, Spacing.xs)
            }

            Divider()

            if showPreview {
                renderedView
            } else {
                rawView
            }
        }
    }

    // MARK: - Subviews

    private var renderedView: some View {
        ScrollView(.vertical) {
            Text(cachedAttributed ?? AttributedString(content))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
        }
        .task(id: content) {
            cachedAttributed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
        }
    }

    private var rawView: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
        }
    }

}
