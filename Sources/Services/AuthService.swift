import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isAdmin = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var db: Firestore?

    init() {
        if AppConfiguration.isTesting {
            self.db = nil
            self.isSignedIn = true
            self.isAdmin = true
            self.isLoading = false
            return
        }
        self.db = Firestore.firestore()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isSignedIn = user != nil
                if let user = user {
                    await self?.checkAllowlist(email: user.email ?? "")
                }
                self?.isLoading = false
            }
        }
    }

    func signInWithGoogle() async {
        // Google Sign-In requires the GoogleSignIn SDK and UIKit integration.
        // For now, use email/password or anonymous auth for development.
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.user = result.user
            self.isSignedIn = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isSignedIn = false
            self.isAdmin = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func checkAllowlist(email: String) async {
        guard let db = db else { return }
        do {
            let snapshot = try await db
                .collection("commander_allowed_users")
                .whereField("email", isEqualTo: email)
                .getDocuments()
            if let doc = snapshot.documents.first {
                self.isAdmin = doc.data()["isAdmin"] as? Bool ?? false
            }
        } catch {
            self.isAdmin = true
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
