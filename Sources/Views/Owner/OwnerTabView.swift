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
                .accessibilityIdentifier("tab-home")

            OwnerRequestView()
                .tabItem {
                    Label("Request", systemImage: "plus.bubble")
                }
                .accessibilityIdentifier("tab-request")

            OwnerStatusView()
                .tabItem {
                    Label("Status", systemImage: "chart.bar")
                }
                .accessibilityIdentifier("tab-status")
        }
        .tint(DS.Colors.accent)
        .environmentObject(firestoreService)
    }
}
