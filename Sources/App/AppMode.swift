import Foundation

enum AppMode: String, CaseIterable {
    case developer = "developer"
    case owner = "owner"

    var displayName: String {
        switch self {
        case .developer: return "Developer"
        case .owner: return "Owner"
        }
    }

    var description: String {
        switch self {
        case .developer: return "Full control over tasks, workers, and system"
        case .owner: return "Simple task creation and status monitoring"
        }
    }

    var icon: String {
        switch self {
        case .developer: return "terminal"
        case .owner: return "storefront"
        }
    }
}
