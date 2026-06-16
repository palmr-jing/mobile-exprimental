import SwiftUI

struct OwnerTabView: View {
    @StateObject private var firestoreService = FirestoreService()
    @State private var showModeSwitcher = false

    var body: some View {
        TabView {
            AskEmmaView()
                .tabItem {
                    Label("Ask Emma", systemImage: "mic.fill")
                }

            OwnerHomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
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
