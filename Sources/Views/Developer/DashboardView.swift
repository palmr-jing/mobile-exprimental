import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                statsGrid
                workersSection
                recentTasksSection
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Commander")
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 100), spacing: DS.Spacing.md)
        ], spacing: DS.Spacing.md) {
            StatCard(
                title: "Running",
                value: "\(firestoreService.tasks.filter { $0.status == .running }.count)",
                color: DS.Colors.amber
            )
            StatCard(
                title: "Pending",
                value: "\(firestoreService.tasks.filter { $0.status == .pending }.count)",
                color: DS.Colors.blue
            )
            StatCard(
                title: "Done",
                value: "\(firestoreService.tasks.filter { $0.status == .done }.count)",
                color: DS.Colors.green
            )
        }
    }

    private var workersSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Workers")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                    ForEach(firestoreService.workers) { worker in
                        WorkerRow(worker: worker)
                    }
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                ForEach(firestoreService.tasks.prefix(5)) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
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
                    Text("$\(worker.totalCost, specifier: "%.2f")")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
        }
    }
}
