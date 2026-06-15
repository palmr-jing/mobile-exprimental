import Foundation

// A notification doc, commander_notifications. Today these are @mention
// notifications written by the sender; the fleet also writes failed/blocked/
// completed types which we render the same way.
struct AppNotification: Identifiable, Equatable {
    let id: String
    var type: String
    var recipientEmail: String?
    var fromName: String
    var channelId: String?
    var channelName: String?
    var text: String
    var message: String
    var read: Bool
    var createdAt: Date?
}
