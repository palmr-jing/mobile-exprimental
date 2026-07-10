import SwiftUI

@main
struct MobileCommanderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var chatService = ChatService()
    @StateObject private var presenceService = PresenceService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var videoFeed = VideoFeedPresenter()
    @StateObject private var issueReporter = ReportIssuePresenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if TestConfig.isMockVideos {
                    // Root the Videos tab inside a TabView exactly as production
                    // does (RootTabView) — fullScreenCover re-presentation behaves
                    // differently inside a TabView tab, so the bare view would hide
                    // the very bug we test for.
                    MockVideosRoot()
                } else if authService.isSignedIn {
                    RootTabView()
                } else {
                    LoginView()
                }
            }
            // The full-screen video feed lives here, ABOVE the TabView, so it
            // covers the whole screen while being a plain state overlay (no modal
            // fullScreenCover to get stuck on iPad after an open+close).
            .overlay {
                if let service = videoFeed.service, !videoFeed.videos.isEmpty {
                    VideoFeedView(videos: videoFeed.videos, service: service,
                                  onClose: { videoFeed.dismiss() })
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
            .environmentObject(videoFeed)
            .environmentObject(issueReporter)
            // Report-issue sheet, shared by every tab (the button lives in each
            // tab's toolbar and sets the draft, which is captured pre-sheet).
            .sheet(item: $issueReporter.draft) { draft in
                ReportIssueView(draft: draft)
                    .environmentObject(issueReporter)
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
                if TestConfig.isMockVideos { return }
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

// Mock harness that mirrors RootTabView's TabView so UITests exercise the Videos
// tab in the same presentation context as production (Videos is tab 2).
private struct MockVideosRoot: View {
    @State private var selection = 2
    var body: some View {
        TabView(selection: $selection) {
            Color.black.tabItem { Label("Ask Emma", systemImage: "sparkles") }.tag(0)
            Color.black.tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }.tag(1)
            VideosView().tabItem { Label("Videos", systemImage: "play.rectangle.on.rectangle") }.tag(2)
        }
        .tint(DS.Colors.accent)
    }
}
