import SwiftUI

// The whole signed-in app:
//   1. Ask Emma — voice-first AI: say what you need, Emma files the work.
//   2. Chat     — team chat with people + @emma.
//   3. Projects — the Commander console (manage.everbot.org), scoped to the
//                 user's granted projects. Only shown to users with console
//                 access (admins, unrestricted, or ≥1 granted project).
//   4. Videos   — reels released to the user from manage.everbot.org.
struct RootTabView: View {
    @EnvironmentObject var authService: AuthService
    // 0 = Ask Emma, 1 = Chat, 3 = Projects, 2 = Videos
    @State private var selection = 0

    private var showConsole: Bool {
        Access.hasConsoleAccess(authService.currentUser)
    }

    var body: some View {
        TabView(selection: $selection) {
            AskEmmaView(isTab: true)
                .tabItem { Label("Ask Emma", systemImage: "sparkles") }
                .tag(0)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            // Console for the projects this user is granted (e.g. the "dan"
            // sandbox). A video-only recipient (empty projects) never sees it.
            if showConsole {
                ConsoleView()
                    .tabItem { Label("Projects", systemImage: "square.grid.2x2") }
                    .tag(3)
            }

            VideosView()
                .tabItem { Label("Videos", systemImage: "play.rectangle.on.rectangle") }
                .tag(2)
        }
        .tint(DS.Colors.accent)
    }
}
