import Foundation

// Swift port of the access-scope logic in commander/worker/emma.js. Kept
// behavior-compatible so the iOS client filters projects/tasks the same way the
// backend does (the backend remains the hard boundary; this is for UI scoping).
enum Access {
    // access.projects == nil → unrestricted (mirrors commander_allowed_users).
    static func canAccessProject(_ project: String?, account: UserAccount?) -> Bool {
        guard let account else { return false }
        if account.isAdmin { return true }
        guard let projects = account.projects else { return true }   // nil = unrestricted
        if projects.contains("*") { return true }
        guard let project, !project.isEmpty else { return false }
        return projects.contains(project)
    }

    static func emailToDocId(_ email: String) -> String {
        email.lowercased().map { ($0 == "." || $0 == "@") ? "_" : $0 }.reduce(into: "") { $0.append($1) }
    }

    // The user's accessible project list: union of projects seen in tasks and the
    // repo registry, filtered by access. Sorted + de-duped. Mirrors
    // emma.js accessibleProjects.
    static func accessibleProjects(taskProjects: [String], registryNames: [String], account: UserAccount?) -> [String] {
        var names = Set<String>()
        for p in taskProjects where !p.isEmpty { names.insert(p) }
        for n in registryNames where !n.isEmpty { names.insert(n) }
        return names.filter { canAccessProject($0, account: account) }.sorted()
    }
}
