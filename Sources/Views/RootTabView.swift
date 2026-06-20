import SwiftUI

// The whole signed-in app: two chat surfaces and nothing else.
//   1. Ask Emma — voice-first AI: say what you need, Emma files the work.
//   2. Chat     — team chat with people + @emma.
// Replaces the old Developer/Owner multi-tab modes; the other screens
// (dashboard, tasks, reports, settings, owner home/request/status) are no
// longer routed.
struct RootTabView: View {
    // 0 = Ask Emma, 1 = Chat
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            AskEmmaView(isTab: true, onSent: { selection = 1 })
                .tabItem { Label("Ask Emma", systemImage: "sparkles") }
                .tag(0)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)
        }
        .tint(DS.Colors.accent)
    }
}
