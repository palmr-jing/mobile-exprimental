import SwiftUI

// The "Projects" tab: the Commander console (project dashboard, tasks, workers,
// progress) surfaced inside the Emma app. It is the read view of
// manage.everbot.org/<project> — a user granted the "dan" project sees the dan
// sandbox here; an admin sees everything. Scoping to the signed-in user's
// allowlist grant happens inside DashboardView / TaskListView (via Access).
//
// Owns its own FirestoreService so the live commander_tasks / commander_workers
// listeners are tied to this tab's lifetime, mirroring DeveloperTabView. The
// signed-in account is read from the app-root environment (authService), so no
// extra injection is needed here.
struct ConsoleView: View {
    @StateObject private var firestoreService = FirestoreService()

    var body: some View {
        DashboardView()
            .environmentObject(firestoreService)
    }
}
