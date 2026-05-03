import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    private var allTasks: [CommanderTask] { firestoreService.tasks }

    private var todayTasks: [CommanderTask] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allTasks.filter { ($0.completedAt ?? Date.distantPast) >= startOfDay && $0.status == .done }
    }

    private var thisWeekTasks: [CommanderTask] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return allTasks.filter { ($0.completedAt ?? Date.distantPast) >= startOfWeek && $0.status == .done }
    }

    private var totalCost: Double { allTasks.compactMap(\.costUsd).reduce(0, +) }
    private var todayCost: Double { todayTasks.compactMap(\.costUsd).reduce(0, +) }
    private var weekCost: Double { thisWeekTasks.compactMap(\.costUsd).reduce(0, +) }
    private var completedCount: Int { allTasks.filter { $0.status == .done }.count }
    private var failedCount: Int { allTasks.filter { $0.status == .failed }.count }

    private var projectBreakdown: [(name: String, done: Int, total: Int, cost: Double)] {
        let grouped = Dictionary(grouping: allTasks, by: \.project)
        return grouped.map { (key, tasks) in
            (
                name: key,
                done: tasks.filter { $0.status == .done }.count,
                total: tasks.count,
                cost: tasks.compactMap(\.costUsd).reduce(0, +)
            )
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    metricsGrid
                    costSection
                    projectBreakdownSection
                    statusBreakdownSection
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Reports")
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DS.Spacing.md) {
            MetricCard(title: "Today", value: "\(todayTasks.count)", subtitle: "completed", color: DS.Colors.green)
            MetricCard(title: "This Week", value: "\(thisWeekTasks.count)", subtitle: "completed", color: DS.Colors.blue)
            MetricCard(title: "All Time", value: "\(completedCount)", subtitle: "completed", color: DS.Colors.accent)
        }
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Cost")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            CommanderDarkCard {
                HStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.xs) {
                        Text("$\(todayCost, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.green)
                        Text("Today")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }

                    VStack(spacing: DS.Spacing.xs) {
                        Text("$\(weekCost, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.blue)
                        Text("This Week")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }

                    VStack(spacing: DS.Spacing.xs) {
                        Text("$\(totalCost, specifier: "%.2f")")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("All Time")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var projectBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("By Project")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            if projectBreakdown.isEmpty {
                CommanderCard {
                    Text("No project data yet")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(projectBreakdown, id: \.name) { project in
                    CommanderCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                    .foregroundStyle(DS.Colors.accent)
                                Text(project.name)
                                    .font(DS.Typography.subheading)
                                    .foregroundStyle(DS.Colors.text)
                                Spacer()
                                if project.cost > 0 {
                                    Text("$\(project.cost, specifier: "%.2f")")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.secondary)
                                }
                            }

                            ProgressView(value: project.total > 0 ? Double(project.done) / Double(project.total) : 0)
                                .tint(DS.Colors.green)

                            Text("\(project.done)/\(project.total) tasks complete")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondary)
                        }
                    }
                }
            }
        }
    }

    private var statusBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Status Overview")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            CommanderCard {
                VStack(spacing: DS.Spacing.md) {
                    StatusRow(label: "Completed", count: completedCount, color: DS.Colors.green, total: allTasks.count)
                    StatusRow(label: "Running", count: allTasks.filter { $0.status == .running }.count, color: DS.Colors.amber, total: allTasks.count)
                    StatusRow(label: "Pending", count: allTasks.filter { $0.status == .pending || $0.status == .claimed }.count, color: DS.Colors.blue, total: allTasks.count)
                    StatusRow(label: "Failed", count: failedCount, color: DS.Colors.red, total: allTasks.count)
                    StatusRow(label: "Needs Review", count: allTasks.filter { $0.effectiveStatus == .needsReview }.count, color: DS.Colors.amber, total: allTasks.count)
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        CommanderCard {
            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.small)
                    .foregroundStyle(DS.Colors.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(subtitle)
                    .font(DS.Typography.small)
                    .foregroundStyle(DS.Colors.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct StatusRow: View {
    let label: String
    let count: Int
    let color: Color
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                Text("\(count)")
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.border)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geo.size.width * fraction, height: 4)
                    }
            }
            .frame(height: 4)
        }
    }
}
