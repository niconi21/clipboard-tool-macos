import AppKit
import Highlightr
import SwiftUI

/// A read-only, scrollable view that renders `code` with syntax highlighting.
///
/// Uses Highlightr (highlight.js) under the hood.  The `contentType` parameter
/// determines which language grammar is applied; `language` lets the caller
/// override the automatic mapping when needed.
///
/// Theme selection is automatic:
/// - Dark appearance  → "atom-one-dark"
/// - Light appearance → "xcode"
@MainActor
struct SyntaxHighlightView: NSViewRepresentable {

    // MARK: - Public properties

    let code: String
    let contentType: ContentType
    /// Override the language inferred from `contentType`.  Pass `nil` to use
    /// the automatic mapping.
    var language: String? = nil

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = makeTextView()
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        applyHighlighting(to: textView, colorScheme: context.environment.colorScheme)
    }

    // MARK: - Helpers

    private func makeTextView() -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        // Allow horizontal scrolling.
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        return textView
    }

    private func applyHighlighting(to textView: NSTextView, colorScheme: ColorScheme) {
        guard let highlightr = Highlightr() else {
            // Highlightr unavailable — fall back to plain text.
            textView.string = code
            return
        }

        let themeName = colorScheme == .dark ? "atom-one-dark" : "xcode"
        highlightr.setTheme(to: themeName)
        textView.backgroundColor = highlightr.theme.themeBackgroundColor

        let lang = resolvedLanguage
        if let attributed = highlightr.highlight(code, as: lang, fastRender: true) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            // Language not recognised — render without highlighting.
            textView.string = code
        }
    }

    /// Returns the Highlightr language string to use, preferring the caller's
    /// explicit `language` override over the automatic `contentType` mapping.
    private var resolvedLanguage: String {
        if let explicit = language, !explicit.isEmpty {
            return explicit
        }
        return Self.language(for: contentType)
    }

    // MARK: - ContentType → Highlightr language mapping

    static func language(for contentType: ContentType) -> String {
        switch contentType {
        case .code:     return "swift"
        case .json:     return "json"
        case .sql:      return "sql"
        case .shell:    return "bash"
        case .markdown: return "markdown"
        default:        return "plaintext"
        }
    }
}
