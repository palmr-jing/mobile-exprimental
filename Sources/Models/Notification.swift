import Foundation
import SwiftUI

struct CommanderNotification: Identifiable {
    let id: String
    var message: String
    var type: NotificationType
    var read: Bool
    var taskId: String?
    var workerId: String?
    var createdAt: Date?
}

enum NotificationType: String {
    case info
    case completed
    case failed
    case blocked
    case review = "needs_review"

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .review: return "eye.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return DS.Colors.blue
        case .completed: return DS.Colors.green
        case .failed: return DS.Colors.red
        case .blocked: return DS.Colors.amber
        case .review: return DS.Colors.amber
        }
    }
}
