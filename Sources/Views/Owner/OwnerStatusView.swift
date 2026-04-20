import SwiftUI

struct OwnerStatusView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    private var groupedByProject: [String: [CommanderTask]] {
        Dictionary(grouping: firestoreService.tasks.prefix(50), by: \.project)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    overallProgress

                    ForEach(Array(groupedByProject.keys.sorted()), id: \.self) { project in
                        projectSection(project: project, tasks: groupedByProject[project] ?? [])
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Status")
        }
    }

    private var overallProgress: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Overall Progress")
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)

                let total = firestoreService.tasks.count
                let done = firestoreService.tasks.filter { $0.status == .done }.count
                let percent = total > 0 ? Double(done) / Double(total) : 0

                ProgressView(value: percent)
                    .tint(DS.Colors.green)

                HStack {
                    Text("\(done) of \(total) tasks complete")
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

    private func projectSection(project: String, tasks: [CommanderTask]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(DS.Colors.accent)
                Text(project)
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                Text("\(tasks.filter { $0.status == .done }.count)/\(tasks.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            ForEach(tasks.prefix(5)) { task in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: task.effectiveStatus.icon)
                        .font(.caption)
                        .foregroundStyle(task.effectiveStatus.color)
                        .frame(width: 20)
                    Text(task.task)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.text)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border, lineWidth: 0.5)
        )
    }
}
