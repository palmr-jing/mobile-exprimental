import SwiftUI

// The whole signed-in app:
//   1. Ask Emma — voice-first AI: say what you need, Emma files the work.
//   2. Chat     — team chat with people + @emma.
//   3. Videos   — reels released to the user from manage.everbot.org.
struct RootTabView: View {
    // 0 = Ask Emma, 1 = Chat, 2 = Videos
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            AskEmmaView(isTab: true)
                .tabItem { Label("Ask Emma", systemImage: "sparkles") }
                .tag(0)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            VideoFeedView()
                .tabItem { Label("Videos", systemImage: "play.rectangle.on.rectangle") }
                .tag(2)
        }
        .tint(DS.Colors.accent)
    }
}
