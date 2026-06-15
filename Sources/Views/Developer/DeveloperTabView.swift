import SwiftUI

struct DeveloperTabView: View {
    @StateObject private var firestoreService = FirestoreService()
    @State private var showModeSwitcher = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }

            CreateTaskView()
                .tabItem {
                    Label("New", systemImage: "plus.circle.fill")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(DS.Colors.accent)
        .environmentObject(firestoreService)
        .sheet(isPresented: $showModeSwitcher) {
            ModeSwitcher()
                .presentationDetents([.medium])
        }
    }
}
