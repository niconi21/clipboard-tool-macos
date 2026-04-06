import SwiftUI

extension ContentType {
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
