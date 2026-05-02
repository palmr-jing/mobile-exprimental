import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var filterStatus: TaskStatus?
    @State private var filterProject: String?
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newest
    @State private var selectedTasks: Set<String> = []
    @State private var isSelecting = false
    @State private var showBulkActions = false

    enum SortOrder: String, CaseIterable {
        case newest = "Newest"
        case oldest = "Oldest"
        case priority = "Priority"
        case project = "Project"
    }

    var filteredTasks: [CommanderTask] {
        var result = firestoreService.tasks
        if let filter = filterStatus {
            result = result.filter { $0.effectiveStatus == filter }
        }
        if let project = filterProject {
            result = result.filter { $0.project == project }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.task.localizedCaseInsensitiveContains(searchText) ||
                $0.project.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                "\($0.numId)".contains(searchText)
            }
        }
        switch sortOrder {
        case .newest:
            result.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            result.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .priority:
            result.sort { $0.priority < $1.priority }
        case .project:
            result.sort { $0.project < $1.project }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterSection
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)

                if isSelecting {
                    bulkBar
                }

                if firestoreService.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(DS.Colors.secondary)
                        Text("No tasks")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(filteredTasks) { task in
                                if isSelecting {
                                    selectableTaskRow(task)
                                } else {
                                    NavigationLink(destination: TaskDetailView(task: task)) {
                                        TaskRow(task: task)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(DS.Spacing.lg)
                    }
                }
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Tasks (\(filteredTasks.count))")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(isSelecting ? "Cancel Selection" : "Select Multiple") {
                            isSelecting.toggle()
                            if !isSelecting { selectedTasks.removeAll() }
                        }
                        Divider()
                        Menu("Sort By") {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(DS.Colors.text)
                    }
                }
            }
            .refreshable {
                firestoreService.listenToTasks()
            }
        }
    }

    private var filterSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    FilterChip(title: "All", isSelected: filterStatus == nil) {
                        filterStatus = nil
                    }
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        let count = firestoreService.tasksForStatus(status).count
                        FilterChip(title: "\(status.displayName) (\(count))", isSelected: filterStatus == status) {
                            filterStatus = status
                        }
                    }
                }
            }

            if firestoreService.projects.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        FilterChip(title: "All Projects", isSelected: filterProject == nil) {
                            filterProject = nil
                        }
                        ForEach(firestoreService.projects, id: \.self) { project in
                            FilterChip(title: project, isSelected: filterProject == project) {
                                filterProject = project
                            }
                        }
                    }
                }
            }
        }
    }

    private var bulkBar: some View {
        HStack(spacing: DS.Spacing.md) {
            Text("\(selectedTasks.count) selected")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.text)

            Spacer()

            if !selectedTasks.isEmpty {
                Menu("Actions") {
                    Button("Retry All") {
                        Task { try? await firestoreService.bulkRetry(taskIds: Array(selectedTasks)) }
                        selectedTasks.removeAll()
                        isSelecting = false
                    }
                    Button("Mark Done") {
                        Task { try? await firestoreService.bulkUpdateStatus(taskIds: Array(selectedTasks), status: .done) }
                        selectedTasks.removeAll()
                        isSelecting = false
                    }
                    Button("Cancel", role: .destructive) {
                        Task { try? await firestoreService.bulkUpdateStatus(taskIds: Array(selectedTasks), status: .failed) }
                        selectedTasks.removeAll()
                        isSelecting = false
                    }
                }
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.accent)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
    }

    private func selectableTaskRow(_ task: CommanderTask) -> some View {
        Button {
            if selectedTasks.contains(task.id) {
                selectedTasks.remove(task.id)
            } else {
                selectedTasks.insert(task.id)
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTasks.contains(task.id) ? DS.Colors.accent : DS.Colors.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("#\(task.numId)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        StatusBadge(status: task.effectiveStatus)
                    }
                    Text(task.task)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(selectedTasks.contains(task.id) ? DS.Colors.accent.opacity(0.05) : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(selectedTasks.contains(task.id) ? DS.Colors.accent : DS.Colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.small)
                .foregroundStyle(isSelected ? .white : DS.Colors.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                        Text(String(format: "$%.3f", cost))
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
                    if task.priority <= 3 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(DS.Colors.red)
                    }
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
