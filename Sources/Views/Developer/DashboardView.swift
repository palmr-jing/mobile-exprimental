import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var showNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    statsGrid
                    if !firestoreService.tasksForStatus(.needsReview).isEmpty {
                        reviewSection
                    }
                    workersSection
                    recentTasksSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Commander")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .foregroundStyle(DS.Colors.text)
                            if firestoreService.unreadCount > 0 {
                                Text("\(firestoreService.unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(DS.Colors.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .environmentObject(firestoreService)
            }
            .refreshable {
                firestoreService.listenToTasks()
                firestoreService.listenToWorkers()
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DS.Spacing.md) {
            StatCard(
                title: "Running",
                value: "\(firestoreService.tasksForStatus(.running).count)",
                color: DS.Colors.amber
            )
            StatCard(
                title: "Pending",
                value: "\(firestoreService.tasksForStatus(.pending).count)",
                color: DS.Colors.blue
            )
            StatCard(
                title: "Review",
                value: "\(firestoreService.tasksForStatus(.needsReview).count)",
                color: DS.Colors.amber
            )
            StatCard(
                title: "Done",
                value: "\(firestoreService.tasksForStatus(.done).count)",
                color: DS.Colors.green
            )
            StatCard(
                title: "Failed",
                value: "\(firestoreService.tasksForStatus(.failed).count)",
                color: DS.Colors.red
            )
            StatCard(
                title: "Cost",
                value: String(format: "$%.2f", firestoreService.totalCost),
                color: DS.Colors.text
            )
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "eye.circle.fill")
                    .foregroundStyle(DS.Colors.amber)
                Text("Needs Review")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
            }

            ForEach(firestoreService.tasksForStatus(.needsReview).prefix(3)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRow(task: task)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var workersSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Workers")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                let onlineCount = firestoreService.workers.filter(\.isOnline).count
                Text("\(onlineCount) online")
                    .font(DS.Typography.caption)
                    .foregroundStyle(onlineCount > 0 ? DS.Colors.green : DS.Colors.secondary)
            }

            if firestoreService.workers.isEmpty {
                CommanderCard {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(DS.Colors.secondary)
                        Text("No workers connected")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(firestoreService.workers) { worker in
                    WorkerRow(worker: worker)
                }
            }
        }
    }

    private var recentTasksSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Recent Tasks")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                NavigationLink("See All") {
                    TaskListView()
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.accent)
            }

            ForEach(firestoreService.tasks.prefix(8)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRow(task: task)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        CommanderCard {
            VStack(spacing: DS.Spacing.xs) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct WorkerRow: View {
    let worker: CommanderWorker

    var body: some View {
        CommanderCard {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(worker.isOnline ? DS.Colors.green : DS.Colors.secondary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worker.hostname)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    Text("\(worker.activeTaskCount) active • \(worker.tasksCompleted) done")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }

                Spacer()

                if worker.totalCost > 0 {
                    Text(String(format: "$%.2f", worker.totalCost))
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
        }
    }
}
