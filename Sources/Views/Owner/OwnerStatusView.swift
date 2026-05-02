import SwiftUI

struct OwnerStatusView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    private var groupedByProject: [String: [CommanderTask]] {
        Dictionary(grouping: firestoreService.tasks, by: \.project)
    }

    private var totalDone: Int {
        firestoreService.tasks.filter { $0.status == .done }.count
    }

    private var totalCount: Int {
        firestoreService.tasks.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    overallProgress
                    workersStatus
                    projectSections
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Status")
            .refreshable {
                firestoreService.listenToTasks()
                firestoreService.listenToWorkers()
            }
        }
    }

    private var overallProgress: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Overall Progress")
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)

                let percent = totalCount > 0 ? Double(totalDone) / Double(totalCount) : 0

                ProgressView(value: percent)
                    .tint(DS.Colors.green)

                HStack {
                    Text("\(totalDone) of \(totalCount) tasks complete")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.green)
                }
            }
        }
    }

    private var workersStatus: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Workers")
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)

                if firestoreService.workers.isEmpty {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(DS.Colors.amber)
                        Text("No workers online — tasks are queued but not running")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                } else {
                    let online = firestoreService.workers.filter(\.isOnline)
                    HStack(spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(online.isEmpty ? DS.Colors.secondary : DS.Colors.green)
                            .frame(width: 8, height: 8)
                        Text("\(online.count) worker\(online.count == 1 ? "" : "s") online")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.text)
                        Spacer()
                        let active = firestoreService.workers.reduce(0) { $0 + $1.activeTaskCount }
                        if active > 0 {
                            Text("\(active) active")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.amber)
                        }
                    }
                }
            }
        }
    }

    private var projectSections: some View {
        ForEach(Array(groupedByProject.keys.sorted()), id: \.self) { project in
            projectCard(project: project, tasks: groupedByProject[project] ?? [])
        }
    }

    private func projectCard(project: String, tasks: [CommanderTask]) -> some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text(project)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    Spacer()

                    let done = tasks.filter { $0.status == .done }.count
                    Text("\(done)/\(tasks.count)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }

                let done = tasks.filter { $0.status == .done }.count
                let percent = tasks.count > 0 ? Double(done) / Double(tasks.count) : 0
                ProgressView(value: percent)
                    .tint(DS.Colors.accent)

                VStack(spacing: DS.Spacing.xs) {
                    ForEach(tasks.prefix(8)) { task in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: task.effectiveStatus.icon)
                                .font(.caption)
                                .foregroundStyle(task.effectiveStatus.color)
                                .frame(width: 16)
                            Text(task.task)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.text)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }

                    if tasks.count > 8 {
                        Text("+ \(tasks.count - 8) more")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
