import SwiftUI

struct ProjectDetailView: View {
    let projectName: String
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var filterStatus: TaskStatus?
    @State private var searchText = ""

    private var projectTasks: [CommanderTask] {
        var result = firestoreService.tasks.filter { $0.project == projectName }
        if let filter = filterStatus {
            result = result.filter { $0.effectiveStatus == filter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.task.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var allProjectTasks: [CommanderTask] {
        firestoreService.tasks.filter { $0.project == projectName }
    }

    private var doneCount: Int { allProjectTasks.filter { $0.status == .done }.count }
    private var totalCount: Int { allProjectTasks.count }
    private var totalCost: Double { allProjectTasks.compactMap(\.costUsd).reduce(0, +) }
    private var reviewCount: Int { allProjectTasks.filter { $0.effectiveStatus == .needsReview }.count }

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            filterBar
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

            if projectTasks.isEmpty {
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
                        ForEach(projectTasks) { task in
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
        .navigationTitle(projectName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search tasks...")
    }

    private var headerCard: some View {
        CommanderDarkCard {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("\(doneCount)/\(totalCount) complete")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                    Spacer()
                    if totalCost > 0 {
                        Text("$\(totalCost, specifier: "%.2f")")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                }
                ProgressView(value: totalCount > 0 ? Double(doneCount) / Double(totalCount) : 0)
                    .tint(DS.Colors.green)
                HStack(spacing: DS.Spacing.lg) {
                    if reviewCount > 0 {
                        Label("\(reviewCount) need review", systemImage: "eye.circle")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.amber)
                    }
                    let running = allProjectTasks.filter { $0.status == .running }.count
                    if running > 0 {
                        Label("\(running) running", systemImage: "play.circle")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.green)
                    }
                    Spacer()
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                FilterChip(title: "All (\(totalCount))", isSelected: filterStatus == nil) {
                    filterStatus = nil
                }
                ForEach([TaskStatus.running, .pending, .done, .failed, .needsReview], id: \.self) { status in
                    let count = allProjectTasks.filter { $0.effectiveStatus == status }.count
                    if count > 0 {
                        FilterChip(title: "\(status.displayName) (\(count))", isSelected: filterStatus == status) {
                            filterStatus = status
                        }
                    }
                }
            }
        }
    }
}
