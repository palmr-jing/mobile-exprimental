import Foundation
import SwiftUI

struct CommanderWorker: Identifiable {
    let id: String
    var hostname: String
    var status: WorkerStatus
    var tasksCompleted: Int
    var totalCost: Double
    var lastHeartbeat: Date?
    var activeTaskCount: Int
    var restartRequested: Bool

    var isOnline: Bool {
        guard let heartbeat = lastHeartbeat else { return false }
        return Date().timeIntervalSince(heartbeat) < 60
    }

    var timeSinceHeartbeat: String? {
        guard let heartbeat = lastHeartbeat else { return nil }
        let interval = Date().timeIntervalSince(heartbeat)
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
}

enum WorkerStatus: String {
    case online
    case offline

    var color: Color {
        switch self {
        case .online: return DS.Colors.green
        case .offline: return DS.Colors.secondary
        }
    }
}
