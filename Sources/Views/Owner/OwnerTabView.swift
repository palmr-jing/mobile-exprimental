import SwiftUI

enum OwnerTab: String, CaseIterable, Identifiable, Hashable {
    case home, chat, request, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .chat: return "Chat"
        case .request: return "Request"
        case .status: return "Status"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .chat: return "bubble.left.and.bubble.right"
        case .request: return "plus.bubble"
        case .status: return "chart.bar"
        }
    }
}

// Adaptive layout: bottom TabView on iPhone (compact), sidebar NavigationSplitView
// on iPad (regular). Child views keep their own navigation.
struct OwnerTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var firestoreService = FirestoreService()
    @State private var selectedTab: OwnerTab = .home

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
            ForEach(OwnerTab.allCases) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarBinding) {
                ForEach(OwnerTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .navigationTitle("Commander")
        } detail: {
            content(for: selectedTab)
                .id(selectedTab)
        }
    }

    private var sidebarBinding: Binding<OwnerTab?> {
        Binding(get: { selectedTab }, set: { if let v = $0 { selectedTab = v } })
    }

    @ViewBuilder
    private func content(for tab: OwnerTab) -> some View {
        switch tab {
        case .home: OwnerHomeView()
        case .chat: ChatView()
        case .request: OwnerRequestView()
        case .status: OwnerStatusView()
        }
    }
}
