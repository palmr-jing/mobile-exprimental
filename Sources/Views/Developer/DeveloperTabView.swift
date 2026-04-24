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
                .accessibilityIdentifier("tab-dashboard")

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }
                .accessibilityIdentifier("tab-tasks")

            CreateTaskView()
                .tabItem {
                    Label("New", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("tab-new")

            WorkersView()
                .tabItem {
                    Label("Workers", systemImage: "server.rack")
                }
                .accessibilityIdentifier("tab-workers")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .accessibilityIdentifier("tab-settings")
        }
        .tint(DS.Colors.accent)
        .environmentObject(firestoreService)
        .sheet(isPresented: $showModeSwitcher) {
            ModeSwitcher()
                .presentationDetents([.medium])
        }
    }
}
