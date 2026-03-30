import SwiftUI

/// Renders markdown content with a toggle between raw source and rendered preview.
struct MarkdownPreviewView: View {
    let content: String

    @State private var showPreview: Bool = true

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
            Text(attributedContent)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
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

    // MARK: - Helpers

    private var attributedContent: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(content)
    }
}
