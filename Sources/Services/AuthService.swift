import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: UserAccount?
    @Published var isSignedIn = false
    @Published var isAdmin = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in await self?.handleAuthChange(user) }
        }
        // In UI tests we bypass Google's interactive flow: sign in anonymously
        // (so presence/chat writes have a real uid the emulator rules accept)
        // and synthesize the account identity from launch arguments.
        if TestConfig.isUITest, TestConfig.fakeUserEmail != nil {
            Task { @MainActor in try? await Auth.auth().signInAnonymously() }
        }
    }

    private func handleAuthChange(_ user: User?) async {
        isLoading = false
        guard let user else {
            currentUser = nil
            isSignedIn = false
            isAdmin = false
            return
        }
        if TestConfig.isUITest, let email = TestConfig.fakeUserEmail {
            let account = UserAccount(
                uid: user.uid, email: email, displayName: email, photoURL: nil,
                isAdmin: TestConfig.fakeUserIsAdmin,
                projects: TestConfig.fakeUserIsAdmin ? nil : []
            )
            apply(account)
            return
        }
        let account = await loadAccount(
            uid: user.uid,
            email: (user.email ?? "").lowercased(),
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString
        )
        apply(account)
    }

    private func apply(_ account: UserAccount) {
        currentUser = account
        isSignedIn = true
        isAdmin = account.isAdmin
    }

    func signInWithGoogle() async {
        errorMessage = nil
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing Firebase client ID."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't present sign-in."
            return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in returned no token."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
            // handleAuthChange picks it up via the state listener.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isSignedIn = false
            isAdmin = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Load the user's allowlist record (access scope + display identity).
    private func loadAccount(uid: String, email: String, displayName: String?, photoURL: String?) async -> UserAccount {
        // An emailless Firebase user (anonymous sign-in, or a provider that
        // returned no email) yields an empty allowlist doc id. Firestore's
        // `documentWithPath:` throws an *uncatchable* ObjC NSException on an
        // empty path, which aborts the whole process (SIGABRT) rather than
        // landing in the catch below — the crash seen under the test host.
        // Fail closed without querying.
        guard !email.isEmpty else {
            return UserAccount(uid: uid, email: email, displayName: displayName ?? "Unknown",
                               photoURL: photoURL, isAdmin: false, projects: [])
        }
        var isAdmin = false
        var projects: [String]? = []
        var name = displayName ?? email
        do {
            let doc = try await db.collection("commander_allowed_users")
                .document(Access.emailToDocId(email)).getDocument()
            if let data = doc.data() {
                isAdmin = data["isAdmin"] as? Bool ?? false
                // Absent `projects` means unrestricted (nil), matching the backend.
                projects = data["projects"] as? [String]
                if let n = data["displayName"] as? String, !n.isEmpty { name = n }
                else if let n = data["name"] as? String, !n.isEmpty { name = n }
            }
        } catch {
            // Leave defaults (no access) — fail closed.
        }
        return UserAccount(uid: uid, email: email, displayName: name, photoURL: photoURL, isAdmin: isAdmin, projects: projects)
    }

    // Top-most presented view controller in the active foreground scene.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
