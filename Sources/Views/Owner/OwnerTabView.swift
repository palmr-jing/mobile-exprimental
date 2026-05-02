import SwiftUI

struct OwnerTabView: View {
    @StateObject private var firestoreService = FirestoreService()

    var body: some View {
        TabView {
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
