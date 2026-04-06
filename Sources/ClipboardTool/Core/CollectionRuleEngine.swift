import Foundation
import GRDB
import os.log

struct CollectionRuleEngine {

    /// Returns unique collection IDs whose rules match `entry`.
    /// Rules are evaluated in descending priority order.
    /// - A rule with only `contentType` set matches when the entry's content type raw value equals the rule's content type.
    /// - A rule with only `contentPattern` set matches when the entry's content matches the regex.
    /// - A rule with both fields set requires both conditions to be true.
    func matchingCollections(for entry: ClipboardEntry, db: any DatabaseReader) async throws -> [Int64] {
        let rules = try await db.read { database in
            try CollectionRule
                .filter(CollectionRule.Columns.enabled == true)
                .order(CollectionRule.Columns.priority.desc)
                .fetchAll(database)
        }

        var seen = Set<Int64>()
        var result: [Int64] = []
        var engine = self

        for rule in rules {
            guard engine.matches(rule: rule, entry: entry) else { continue }
            let collectionId = rule.collectionId
            if seen.insert(collectionId).inserted {
                result.append(collectionId)
            }
        }

        return result
    }

    // MARK: - Private

    private var regexCache: [String: NSRegularExpression] = [:]

    private mutating func compiledRegex(for pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            os_log(.error, "CollectionRuleEngine: invalid regex pattern '%{public}@'", pattern)
            return nil
        }
        regexCache[pattern] = regex
        return regex
    }

    private mutating func matches(rule: CollectionRule, entry: ClipboardEntry) -> Bool {
        let typeMatches: Bool
        let patternMatches: Bool

        if let ruleContentType = rule.contentType {
            typeMatches = entry.contentType.rawValue == ruleContentType
        } else {
            typeMatches = true // not constrained
        }

        if let pattern = rule.contentPattern {
            patternMatches = regexMatches(pattern: pattern, in: entry.content)
        } else {
            patternMatches = true // not constrained
        }

        // If neither field is set, the rule is not applicable — skip it.
        if rule.contentType == nil && rule.contentPattern == nil {
            return false
        }

        return typeMatches && patternMatches
    }

    private mutating func regexMatches(pattern: String, in string: String) -> Bool {
        guard let regex = compiledRegex(for: pattern) else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}
