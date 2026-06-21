import SwiftUI

@main
struct MobileCommanderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var chatService = ChatService()
    @StateObject private var presenceService = PresenceService()
    @StateObject private var notificationService = NotificationService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isSignedIn {
                    RootTabView()
                } else {
                    LoginView()
                }
            }
            // The design system is light-only (hard-coded cream/white surfaces and
            // dark text tokens). Lock the app to light appearance so SwiftUI's
            // adaptive default colors don't resolve to white-on-light in dark mode.
            // Paired with UIUserInterfaceStyle=Light in Info.plist for UIKit surfaces.
            .preferredColorScheme(.light)
            .environmentObject(authService)
            .environmentObject(chatService)
            .environmentObject(notificationService)
            // When the signed-in user is known, start the live chat/presence
            // subscriptions and register for push. Tear them down on sign-out.
            .onChange(of: authService.currentUser) { _, account in
                if let account {
                    chatService.start(user: account)
                    notificationService.start(email: account.email)
                    presenceService.start(user: account)
                    PushService.shared.register(uid: account.uid)
                } else {
                    chatService.stop()
                    notificationService.stop()
                    presenceService.stop()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                presenceService.scenePhaseChanged(phase)
            }
        }
    }
}
