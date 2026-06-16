import SwiftUI

enum DeveloperTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard, tasks, newTask, workers, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .tasks: return "Tasks"
        case .newTask: return "New Task"
        case .workers: return "Workers"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .tasks: return "list.bullet"
        case .newTask: return "plus.circle.fill"
        case .workers: return "server.rack"
        case .settings: return "gear"
        }
    }
}

struct DeveloperTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var firestoreService = FirestoreService()
    @State private var selectedTab: DeveloperTab = .dashboard

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .tint(DS.Colors.accent)
        .environmentObject(firestoreService)
    }

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label(DeveloperTab.dashboard.title, systemImage: DeveloperTab.dashboard.icon) }
            .tag(DeveloperTab.dashboard)

            NavigationStack {
                TaskListView()
            }
            .tabItem { Label(DeveloperTab.tasks.title, systemImage: DeveloperTab.tasks.icon) }
            .tag(DeveloperTab.tasks)

            NavigationStack {
                CreateTaskView()
            }
            .tabItem { Label("New", systemImage: DeveloperTab.newTask.icon) }
            .tag(DeveloperTab.newTask)

            NavigationStack {
                WorkersView()
            }
            .tabItem { Label(DeveloperTab.workers.title, systemImage: DeveloperTab.workers.icon) }
            .tag(DeveloperTab.workers)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label(DeveloperTab.settings.title, systemImage: DeveloperTab.settings.icon) }
            .tag(DeveloperTab.settings)
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarBinding) {
                ForEach(DeveloperTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .navigationTitle("Commander")
        } detail: {
            NavigationStack {
                detailContent
            }
        }
    }

    private var sidebarBinding: Binding<DeveloperTab?> {
        Binding(
            get: { selectedTab },
            set: { if let newValue = $0 { selectedTab = newValue } }
        )
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView()
        case .tasks:
            TaskListView()
        case .newTask:
            CreateTaskView()
        case .workers:
            WorkersView()
        case .settings:
            SettingsView()
        }
    }
}
