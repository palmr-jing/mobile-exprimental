import Foundation

// The signed-in user, decoupled from FirebaseAuth.User so the same shape works
// for both a real Google sign-in and the deterministic UITest fake.
struct UserAccount: Equatable {
    let uid: String
    let email: String
    let displayName: String
    let photoURL: String?
    var isAdmin: Bool
    var projects: [String]?   // nil = unrestricted (mirrors commander_allowed_users)
}
