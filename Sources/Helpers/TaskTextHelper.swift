import Foundation

enum TaskTextHelper {
    private static let knownProjects: [String: String] = [
        "palmr-ios": "Palmr",
        "palmr-ios-2": "Palmr",
        "palmr-web": "Palmr Web",
        "palmr-api": "Palmr API",
        "mobile-commander": "Mobile Commander",
        "mobile-exprimental": "Mobile Commander",
    ]

    static func friendlyProjectName(_ slug: String) -> String {
        if let known = knownProjects[slug] { return known }
        if slug.isEmpty { return "Project" }
        return slug
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func humanize(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty { return result }

        result = stripBracketedPrefixes(result)
        result = stripTemplatePrefixes(result)
        result = stripIPAddresses(result)
        result = stripFilePaths(result)
        result = stripStackTraces(result)
        result = collapseWhitespace(result)

        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }

        return result
    }

    private static func stripBracketedPrefixes(_ text: String) -> String {
        var s = text
        while let range = s.range(of: #"^\s*\[[^\]]{1,20}\]\s*"#, options: .regularExpression) {
            s.removeSubrange(range)
        }
        return s
    }

    private static func stripTemplatePrefixes(_ text: String) -> String {
        let prefixes = [
            "Fix a Bug: ", "Fix a Bug:",
            "New Feature: ", "New Feature:",
            "UI Change: ", "UI Change:",
            "Update Content: ", "Update Content:",
        ]
        var s = text
        for prefix in prefixes {
            if s.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
                break
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func stripIPAddresses(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?\b"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func stripFilePaths(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(/[a-zA-Z0-9._-]+){3,}"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func stripStackTraces(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let cleaned = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("at ") && trimmed.contains(":") { return false }
            if trimmed.range(of: #"^\s*(File|Line|Error|Traceback)\b"#, options: .regularExpression) != nil
                && trimmed.contains(":") { return false }
            return true
        }
        return cleaned.first ?? text
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ownerDisplayName(for status: TaskStatus) -> String {
        switch status {
        case .pending: return "Queued"
        case .claimed: return "Starting"
        case .running: return "Working on it"
        case .done: return "Done"
        case .failed: return "Something went wrong"
        case .blocked: return "Stuck"
        case .needsReview: return "Ready for review"
        }
    }
}
