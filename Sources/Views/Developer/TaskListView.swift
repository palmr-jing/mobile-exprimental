import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthService
    @State private var filterStatus: TaskStatus?
    @State private var searchText = ""

    var filteredTasks: [CommanderTask] {
        // Scope to the user's granted projects first (mirrors DashboardView).
        var result = firestoreService.tasks.filter {
            Access.canAccessProject($0.project, account: authService.currentUser)
        }
        if let filter = filterStatus {
            result = result.filter { $0.effectiveStatus == filter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.task.localizedCaseInsensitiveContains(searchText) ||
                $0.project.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)

                if firestoreService.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredTasks.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: filterStatus != nil ? "line.3.horizontal.decrease.circle" : "tray",
                        title: filterStatus != nil ? "No matching tasks" : "No tasks yet",
                        subtitle: filterStatus != nil
                            ? "Try a different filter or clear the current one."
                            : "Tasks will appear here once created."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(filteredTasks) { task in
                                NavigationLink(destination: TaskDetailView(task: task)) {
                                    TaskRow(task: task)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DS.Spacing.lg)
                    }
                }
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                FilterChip(title: "All", isSelected: filterStatus == nil) {
                    filterStatus = nil
                }
                ForEach([TaskStatus.running, .pending, .done, .failed, .needsReview], id: \.self) { status in
                    FilterChip(title: status.displayName, isSelected: filterStatus == status) {
                        filterStatus = status
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(isSelected ? .white : DS.Colors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? DS.Colors.dark : DS.Colors.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(DS.Colors.border, lineWidth: isSelected ? 0 : 0.5)
                )
        }
    }
}

struct TaskRow: View {
    let task: CommanderTask

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("#\(task.numId)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                    StatusBadge(status: task.effectiveStatus)
                    Spacer()
                    if let cost = task.costUsd {
                        Text("$\(cost, specifier: "%.3f")")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }

                Text(task.task)
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(2)

                HStack {
                    Label(task.project, systemImage: "folder")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                    Spacer()
                    if let date = task.createdAt {
                        Text(date, style: .relative)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
            }
        }
    }
}
