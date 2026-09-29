import Foundation

/// A lightweight on-device recipe parser that mirrors the server's heuristic
/// (see grayrecipes lib/extract.ts `parseRecipeText`). Used for the instant
/// preview before the server extraction returns.
enum LocalRecipeParser {
    static func parse(lines rawLines: [String]) -> RecipeDraft {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var draft = RecipeDraft()
        guard !lines.isEmpty else { return draft }

        enum Section { case unknown, ingredients, instructions }
        var section: Section = .unknown

        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()

            if i == 0 && !lower.contains("ingredient") && !lower.contains("instruction") {
                draft.title = line
                continue
            }
            if lower.contains("serves") || lower.contains("servings") || lower.contains("yield") {
                if let match = firstMatch(in: line, pattern: "(\\d+[\\s\\-]*\\d*)") { draft.servings = match }
                continue
            }
            if lower.contains("prep time") || lower.contains("prep:") {
                if let match = firstMatch(in: line, pattern: "(\\d+\\s*(?:min|minutes|hrs?|hours?))") { draft.prepTime = match }
                continue
            }
            if lower.contains("cook time") || lower.contains("cook:") || lower.contains("bake time") {
                if let match = firstMatch(in: line, pattern: "(\\d+\\s*(?:min|minutes|hrs?|hours?))") { draft.cookTime = match }
                continue
            }
            if lower.contains("ingredient") { section = .ingredients; continue }
            if lower.contains("instruction") || lower.contains("direction")
                || lower.contains("method") || lower.contains("steps") {
                section = .instructions; continue
            }

            switch section {
            case .ingredients:
                let cleaned = stripLeadingMarkers(line)
                if !cleaned.isEmpty { draft.ingredients.append(cleaned) }
            case .instructions:
                let cleaned = stripLeadingNumbers(line)
                if !cleaned.isEmpty { draft.instructions.append(cleaned) }
            case .unknown:
                if looksLikeIngredient(line) {
                    draft.ingredients.append(stripLeadingMarkers(line))
                }
            }
        }

        if draft.title.isEmpty { draft.title = "Untitled Recipe" }
        return draft
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        if firstMatch(in: line, pattern: "^\\d+/\\d+") != nil { return true }
        if firstMatch(in: line, pattern: "^[\\d.]+\\s*(cup|tsp|tbsp|oz|lb|g|kg|ml|l)") != nil { return true }
        return line.hasPrefix("-") || line.hasPrefix("•")
    }

    private static func stripLeadingMarkers(_ line: String) -> String {
        replacing(line, pattern: "^[\\-\\u{2022}\\*\\d\\.]+\\s*", with: "")
    }

    private static func stripLeadingNumbers(_ line: String) -> String {
        replacing(line, pattern: "^[\\d\\.]+\\s*", with: "")
    }

    // MARK: Regex helpers
    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: match.numberOfRanges > 1 ? 1 : 0), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespaces)
    }

    private static func replacing(_ text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
            .trimmingCharacters(in: .whitespaces)
    }
}
