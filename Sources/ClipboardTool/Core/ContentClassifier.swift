import Foundation

// Detects content type from a string (URL, email, phone, color, code, text, etc.).
// All case raw values match the Linux version's content_types table names exactly
// to enable cross-platform JSON export/import.
enum ContentType: String, Codable, CaseIterable {
    case url
    case email
    case phone
    case color
    case code
    case text
    case json
    case sql
    case shell
    case markdown
    case image
}

struct ContentClassifier {

    // MARK: - Public API

    func classify(_ string: String) -> ContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if isEmail(trimmed) { return .email }
        if isURL(trimmed)   { return .url }
        if isPhone(trimmed) { return .phone }
        if isColor(trimmed) { return .color }
        if isCode(string)   { return .code }  // use original to preserve indentation
        return .text
    }

    // MARK: - Private detectors

    private func isURL(_ string: String) -> Bool {
        // 1. Scheme-based URLs — delegate to NSDataDetector for robust handling.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(string.startIndex..., in: string)
            let matches = detector.matches(in: string, options: [], range: range)
            // Accept only when the entire string is covered by a URL match.
            if let match = matches.first,
               match.resultType == .link,
               match.range == range {
                return true
            }
        }

        // 2. Bare-domain patterns not caught by NSDataDetector
        //    e.g. "github.com/foo", "www.example.org"
        let barePattern = #"^(?:www\.)?[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z]{2,})+(?:[/?#]\S*)?$"#
        return matchesEntire(pattern: barePattern, in: string)
    }

    private func isEmail(_ string: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return matchesEntire(pattern: pattern, in: string)
    }

    private func isPhone(_ string: String) -> Bool {
        // Use NSDataDetector for phone number detection.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) {
            let range = NSRange(string.startIndex..., in: string)
            let matches = detector.matches(in: string, options: [], range: range)
            if let match = matches.first,
               match.resultType == .phoneNumber,
               match.range == range {
                return true
            }
        }
        return false
    }

    private func isColor(_ string: String) -> Bool {
        // Matches #RGB, #RRGGBB, #RRGGBBAA (case insensitive).
        let pattern = #"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
        return matchesEntire(pattern: pattern, in: string)
    }

    private func isCode(_ string: String) -> Bool {
        let markers = ["{", "}", "func ", "def ", "class ", "import ", "return ",
                       "var ", "let ", "const ", "=>", "->", "if (", "for ("]
        let matchCount = markers.filter { string.contains($0) }.count
        if matchCount >= 2 { return true }

        // Fallback: 3+ lines with consistent non-zero indentation.
        let lines = string.components(separatedBy: .newlines)
        guard lines.count >= 3 else { return false }
        let indentedLines = lines.filter { line in
            guard let first = line.first else { return false }
            return first == " " || first == "\t"
        }
        return indentedLines.count >= 3
    }

    // MARK: - Helpers

    /// Returns true when the entire string matches the given regex pattern.
    private func matchesEntire(pattern: String, in string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: .anchored, range: range)?.range == range
    }
}
