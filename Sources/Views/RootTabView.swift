import SwiftUI

// The whole signed-in app:
//   1. Ask Emma — voice-first AI: say what you need, Emma files the work.
//   2. Chat     — team chat with people + @emma.
//   3. Videos   — reels released to the user from manage.everbot.org.
//   4. Released — class recordings (3 angles) released from manage.everbot.org.
struct RootTabView: View {
    // 0 = Ask Emma, 1 = Chat, 2 = Videos, 3 = Released
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            AskEmmaView(isTab: true)
                .tabItem { Label("Ask Emma", systemImage: "sparkles") }
                .tag(0)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            VideosView()
                .tabItem { Label("Videos", systemImage: "play.rectangle.on.rectangle") }
                .tag(2)

            ReleasedRecordingsView()
                .tabItem { Label("Released", systemImage: "video.badge.checkmark") }
                .tag(3)
        }
        .tint(DS.Colors.accent)
    }
}
