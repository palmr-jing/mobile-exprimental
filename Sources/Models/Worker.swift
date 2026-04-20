import Foundation

struct CommanderWorker: Identifiable {
    let id: String
    var hostname: String
    var status: WorkerStatus
    var tasksCompleted: Int
    var totalCost: Double
    var lastHeartbeat: Date?
    var activeTaskCount: Int

    var isOnline: Bool {
        guard let heartbeat = lastHeartbeat else { return false }
        return Date().timeIntervalSince(heartbeat) < 60
    }
}

enum WorkerStatus: String {
    case online
    case offline

    var color: SwiftUI.Color {
        switch self {
        case .online: return DS.Colors.green
        case .offline: return DS.Colors.secondary
        }
    }
}

import SwiftUI
