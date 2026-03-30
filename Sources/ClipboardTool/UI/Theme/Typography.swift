import SwiftUI

// Design system typography tokens.
// All views must use these — no magic numbers.
enum Typography {
    static let caption  = Font.system(size: 11, weight: .regular)
    static let body     = Font.system(size: 13, weight: .regular)
    static let label    = Font.system(size: 13, weight: .medium)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let title    = Font.system(size: 15, weight: .semibold)
}
