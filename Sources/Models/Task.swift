import Foundation
import FirebaseFirestore

enum TaskStatus: String, CaseIterable {
    case pending
    case claimed
    case running
    case done
    case failed
    case blocked
    case needsReview = "needs_review"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .claimed: return "Claimed"
        case .running: return "Running"
        case .done: return "Done"
        case .failed: return "Failed"
        case .blocked: return "Blocked"
        case .needsReview: return "Review"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .pending: return DS.Colors.secondary
        case .claimed: return DS.Colors.blue
        case .running: return DS.Colors.amber
        case .done: return DS.Colors.green
        case .failed: return DS.Colors.red
        case .blocked: return DS.Colors.red.opacity(0.7)
        case .needsReview: return DS.Colors.amber
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .claimed: return "hand.raised"
        case .running: return "play.circle.fill"
        case .done: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .needsReview: return "eye.circle.fill"
        }
    }
}

import SwiftUI

struct CommanderTask: Identifiable {
    let id: String
    var numId: Int
    var project: String
    var path: String
    var task: String
    var description: String
    var status: TaskStatus
    var priority: Int
    var dependsOn: [Int]
    var allowParallel: Bool
    var assignedWorker: String?
    var claimedBy: String?
    var createdBy: TaskCreator?
    var costUsd: Double?
    var durationMs: Int?
    var exitCode: Int?
    var error: String?
    var reviewStatus: String?
    var resultText: String?
    var followUp: String?
    var createdAt: Date?
    var completedAt: Date?

    var effectiveStatus: TaskStatus {
        if status == .done && reviewStatus == "needs_review" {
            return .needsReview
        }
        return status
    }
}

struct TaskCreator {
    let uid: String
    let email: String
    let name: String
    let photo: String?
}

struct ChatMessage: Identifiable {
    let id: String
    let role: String
    let content: String
    let status: String?
    let createdAt: Date?
}

struct OutputChunk: Identifiable {
    let id: String
    let seq: Int
    let text: String
    let createdAt: Date?
}
