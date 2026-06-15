import SwiftUI

struct OwnerTabView: View {
    @StateObject private var firestoreService = FirestoreService()
    @State private var showModeSwitcher = false

    var body: some View {
        TabView {
            OwnerHomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            OwnerRequestView()
                .tabItem {
                    Label("Request", systemImage: "plus.bubble")
                }

            OwnerStatusView()
                .tabItem {
                    Label("Status", systemImage: "chart.bar")
                }
        }
        .tint(DS.Colors.accent)
        .environmentObject(firestoreService)
    }
}
