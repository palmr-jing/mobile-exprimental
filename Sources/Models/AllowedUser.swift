import Foundation

// An entry in commander_allowed_users (doc id = email with @ and . replaced by
// _). `projects == nil` means unrestricted access.
struct AllowedUser: Identifiable, Equatable {
    let id: String        // doc id
    var email: String
    var name: String
    var isAdmin: Bool
    var projects: [String]?
}
