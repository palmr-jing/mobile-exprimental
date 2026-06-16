import SwiftUI

enum DeveloperTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard, tasks, newTask, chat, reports, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .tasks: return "Tasks"
        case .newTask: return "New"
        case .chat: return "Chat"
        case .reports: return "Reports"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .tasks: return "list.bullet"
        case .newTask: return "plus.circle.fill"
        case .chat: return "bubble.left.and.bubble.right"
        case .reports: return "chart.bar"
        case .settings: return "gear"
        }
    }
}

// Adaptive layout: bottom TabView on iPhone (compact), sidebar NavigationSplitView
// on iPad (regular) so the app uses the full screen instead of a phone-width
// column. Child views keep their own navigation.
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
            ForEach(DeveloperTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarBinding) {
                ForEach(DeveloperTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .navigationTitle("Commander")
        } detail: {
            content(for: selectedTab)
                .id(selectedTab)
        }
    }

    private var sidebarBinding: Binding<DeveloperTab?> {
        Binding(get: { selectedTab }, set: { if let v = $0 { selectedTab = v } })
    }

    @ViewBuilder
    private func content(for tab: DeveloperTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .tasks: TaskListView()
        case .newTask: CreateTaskView()
        case .chat: ChatView()
        case .reports: ReportsView()
        case .settings: SettingsView()
        }
    }
}
