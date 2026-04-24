import SwiftUI
import FirebaseCore

@main
struct MobileCommanderApp: App {
    @StateObject private var authService = AuthService()
    @AppStorage("appMode") private var appMode: AppMode = .developer

    init() {
        if AppConfiguration.isTesting {
            if ProcessInfo.processInfo.arguments.contains("--developer-mode") {
                UserDefaults.standard.set("developer", forKey: "appMode")
            } else if ProcessInfo.processInfo.arguments.contains("--owner-mode") {
                UserDefaults.standard.set("owner", forKey: "appMode")
            }
        } else {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            if authService.isSignedIn {
                switch appMode {
                case .developer:
                    DeveloperTabView()
                        .environmentObject(authService)
                case .owner:
                    OwnerTabView()
                        .environmentObject(authService)
                }
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}
