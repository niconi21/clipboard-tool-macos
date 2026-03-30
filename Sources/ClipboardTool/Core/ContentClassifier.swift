import Foundation

// Detects content type from a string (URL, email, phone, color, code, text).
// Implementation tracked in issue #4.
enum ContentType: String, Codable {
    case url
    case email
    case phone
    case color
    case code
    case text
}

struct ContentClassifier {
    // TODO: implement — issue #4
    func classify(_ string: String) -> ContentType { .text }
}
