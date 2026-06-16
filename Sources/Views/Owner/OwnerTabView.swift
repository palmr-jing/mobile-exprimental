import SwiftUI

enum OwnerTab: String, CaseIterable, Identifiable, Hashable {
    case home, request, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .request: return "Request"
        case .status: return "Status"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .request: return "plus.bubble"
        case .status: return "chart.bar"
        }
    }
}

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
            NavigationStack {
                OwnerHomeView()
            }
            .tabItem { Label(OwnerTab.home.title, systemImage: OwnerTab.home.icon) }
            .tag(OwnerTab.home)

            NavigationStack {
                OwnerRequestView()
            }
            .tabItem { Label(OwnerTab.request.title, systemImage: OwnerTab.request.icon) }
            .tag(OwnerTab.request)

            NavigationStack {
                OwnerStatusView()
            }
            .tabItem { Label(OwnerTab.status.title, systemImage: OwnerTab.status.icon) }
            .tag(OwnerTab.status)
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List(selection: sidebarBinding) {
                ForEach(OwnerTab.allCases) { tab in
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

    private var sidebarBinding: Binding<OwnerTab?> {
        Binding(
            get: { selectedTab },
            set: { if let newValue = $0 { selectedTab = newValue } }
        )
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .home:
            OwnerHomeView()
        case .request:
            OwnerRequestView()
        case .status:
            OwnerStatusView()
        }
    }
}
