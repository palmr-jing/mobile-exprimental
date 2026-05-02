import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    private var recentlyCompleted: [CommanderTask] {
        firestoreService.tasks
            .filter { $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var recentlyFailed: [CommanderTask] {
        firestoreService.tasks
            .filter { $0.status == .failed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var todayTasks: [CommanderTask] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return firestoreService.tasks.filter {
            guard let created = $0.createdAt else { return false }
            return created >= startOfDay
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    todaySummary

                    if !recentlyFailed.isEmpty {
                        failedSection
                    }

                    completedSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Activity")
            .refreshable {
                firestoreService.listenToTasks()
            }
        }
    }

    private var todaySummary: some View {
        CommanderDarkCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Today")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)

                HStack(spacing: DS.Spacing.xl) {
                    VStack {
                        Text("\(todayTasks.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Created")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        Text("\(todayTasks.filter { $0.status == .done }.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.green)
                        Text("Completed")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        Text("\(todayTasks.filter { $0.status == .failed }.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.red)
                        Text("Failed")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        let cost = todayTasks.compactMap(\.costUsd).reduce(0, +)
                        Text(String(format: "$%.2f", cost))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.amber)
                        Text("Spent")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var failedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(DS.Colors.red)
                Text("Recent Failures")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
            }

            ForEach(recentlyFailed.prefix(5)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    CommanderCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Text("#\(task.numId)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                                Spacer()
                                if let date = task.completedAt {
                                    Text(date, style: .relative)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.secondary)
                                }
                            }
                            Text(task.task)
                                .font(DS.Typography.subheading)
                                .foregroundStyle(DS.Colors.text)
                                .lineLimit(1)
                            if let error = task.error {
                                Text(error)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.red)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Colors.green)
                Text("Recently Completed")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
            }

            ForEach(recentlyCompleted.prefix(15)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    HStack(spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("#\(task.numId)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                                Text(task.project)
                                    .font(DS.Typography.small)
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Text(task.task)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.text)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let cost = task.costUsd {
                                Text(String(format: "$%.3f", cost))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                            if let date = task.completedAt {
                                Text(date, style: .relative)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
