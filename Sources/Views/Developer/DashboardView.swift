import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthService

    // Tasks the signed-in user is allowed to see, filtered by their allowlist
    // project grant. Everything on this dashboard (stats, projects, recent) is
    // derived from this so a scoped user (e.g. Dan → "dan") only sees their
    // projects; admins/unrestricted see all. UI scoping only — the backend
    // rules remain the hard boundary.
    private var scopedTasks: [CommanderTask] {
        firestoreService.tasks.filter {
            Access.canAccessProject($0.project, account: authService.currentUser)
        }
    }

    private var projects: [(name: String, tasks: [CommanderTask])] {
        let grouped = Dictionary(grouping: scopedTasks, by: \.project)
        return grouped
            .map { (name: $0.key, tasks: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    statsGrid
                    overallProgress
                    projectsSection
                    workersSection
                    recentTasksSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Commander")
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DS.Spacing.md) {
            StatCard(
                title: "Running",
                value: "\(scopedTasks.filter { $0.status == .running }.count)",
                color: DS.Colors.amber
            )
            StatCard(
                title: "Pending",
                value: "\(scopedTasks.filter { $0.status == .pending || $0.status == .claimed }.count)",
                color: DS.Colors.blue
            )
            StatCard(
                title: "Review",
                value: "\(scopedTasks.filter { $0.effectiveStatus == .needsReview }.count)",
                color: DS.Colors.amber
            )
            StatCard(
                title: "Done",
                value: "\(scopedTasks.filter { $0.status == .done }.count)",
                color: DS.Colors.green
            )
        }
    }

    private var overallProgress: some View {
        let total = scopedTasks.count
        let done = scopedTasks.filter { $0.status == .done }.count
        let progress = total > 0 ? Double(done) / Double(total) : 0
        let totalCost = scopedTasks.compactMap(\.costUsd).reduce(0, +)

        return CommanderDarkCard {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("\(done)/\(total) tasks complete")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                    Spacer()
                    if totalCost > 0 {
                        Text("$\(totalCost, specifier: "%.2f") spent")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                }
                ProgressView(value: progress)
                    .tint(DS.Colors.green)
            }
        }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Projects")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            if projects.isEmpty {
                CommanderCard {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(DS.Colors.secondary)
                        Text("No projects yet")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Spacer()
                    }
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DS.Spacing.md) {
                    ForEach(projects, id: \.name) { project in
                        NavigationLink(destination: ProjectDetailView(projectName: project.name)) {
                            ProjectCard(name: project.name, tasks: project.tasks)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

            ForEach(scopedTasks.prefix(5)) { task in
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
                Text(title)
                    .font(DS.Typography.small)
                    .foregroundStyle(DS.Colors.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct ProjectCard: View {
    let name: String
    let tasks: [CommanderTask]

    private var done: Int { tasks.filter { $0.status == .done }.count }
    private var running: Int { tasks.filter { $0.status == .running }.count }
    private var failed: Int { tasks.filter { $0.status == .failed }.count }
    private var progress: Double { tasks.isEmpty ? 0 : Double(done) / Double(tasks.count) }

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.accent)
                    Text(name)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(1)
                }

                ProgressView(value: progress)
                    .tint(DS.Colors.green)

                HStack(spacing: DS.Spacing.sm) {
                    Text("\(done)/\(tasks.count)")
                        .font(DS.Typography.small)
                        .foregroundStyle(DS.Colors.secondary)
                    Spacer()
                    if running > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(DS.Colors.amber)
                                .frame(width: 6, height: 6)
                            Text("\(running)")
                                .font(DS.Typography.small)
                                .foregroundStyle(DS.Colors.amber)
                        }
                    }
                    if failed > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(DS.Colors.red)
                                .frame(width: 6, height: 6)
                            Text("\(failed)")
                                .font(DS.Typography.small)
                                .foregroundStyle(DS.Colors.red)
                        }
                    }
                }
            }
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
