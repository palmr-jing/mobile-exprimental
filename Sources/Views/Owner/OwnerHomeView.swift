import SwiftUI

struct OwnerHomeView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .owner
    @State private var showModeSwitcher = false

    private var activeTasks: [CommanderTask] {
        firestoreService.tasks.filter { $0.status == .running || $0.status == .claimed }
    }

    private var completedToday: [CommanderTask] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return firestoreService.tasks.filter {
            $0.status == .done && ($0.completedAt ?? .distantPast) >= startOfDay
        }
    }

    private var needsAttention: [CommanderTask] {
        firestoreService.tasks.filter {
            $0.status == .failed || $0.effectiveStatus == .needsReview
        }
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        statusCards(proxy: proxy)
                        if !needsAttention.isEmpty { attentionSection }
                        if !activeTasks.isEmpty { activeSection }
                        summarySection
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModeSwitcher = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
            }
            .sheet(isPresented: $showModeSwitcher) {
                ModeSwitcher()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Status Cards

    private func statusCards(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Your App Status")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                StatusMetricCard(
                    icon: "hammer.fill",
                    count: activeTasks.count,
                    label: "In Progress",
                    subtitle: activeTasks.isEmpty
                        ? "Nothing running right now"
                        : "\(activeTasks.count) task\(activeTasks.count == 1 ? "" : "s") being worked on",
                    color: DS.Colors.amber
                ) {
                    withAnimation { proxy.scrollTo("active", anchor: .top) }
                }

                StatusMetricCard(
                    icon: "checkmark.circle.fill",
                    count: completedToday.count,
                    label: "Done Today",
                    subtitle: completedToday.isEmpty
                        ? "No tasks finished yet today"
                        : "\(completedToday.count) finished since midnight",
                    color: DS.Colors.green
                ) {
                    withAnimation { proxy.scrollTo("completed", anchor: .top) }
                }

                StatusMetricCard(
                    icon: "exclamationmark.triangle.fill",
                    count: needsAttention.count,
                    label: "Needs Attention",
                    subtitle: needsAttention.isEmpty
                        ? "Everything looks good"
                        : "\(needsAttention.count) need\(needsAttention.count == 1 ? "s" : "") your review",
                    color: needsAttention.isEmpty ? DS.Colors.secondary : DS.Colors.red
                ) {
                    withAnimation { proxy.scrollTo("attention", anchor: .top) }
                }

                StatusMetricCard(
                    icon: "tray.full.fill",
                    count: firestoreService.tasks.count,
                    label: "Total Tasks",
                    subtitle: "All time across projects",
                    color: DS.Colors.blue
                ) {
                    // No-op — informational card
                }
            }
        }
    }

    // MARK: - Sections

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.red)

            ForEach(needsAttention.prefix(3)) { task in
                OwnerTaskCard(task: task)
            }
        }
        .id("attention")
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Working On")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            ForEach(activeTasks) { task in
                OwnerTaskCard(task: task)
            }
        }
        .id("active")
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Recently Completed")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            if completedToday.isEmpty {
                CommanderCard {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DS.Colors.secondary)
                        Text("No tasks completed today")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(completedToday.prefix(5)) { task in
                    OwnerTaskCard(task: task)
                }
            }
        }
        .id("completed")
    }
}

// MARK: - Status Metric Card

struct StatusMetricCard: View {
    let icon: String
    let count: Int
    let label: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }

                Text(label)
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)

                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Owner Task Card

struct OwnerTaskCard: View {
    let task: CommanderTask

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    StatusBadge(status: task.effectiveStatus)
                    Spacer()
                    if !task.project.isEmpty {
                        Text(TaskTextHelper.friendlyProjectName(task.project))
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }

                Text(TaskTextHelper.humanize(task.task))
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(2)

                HStack {
                    Text(TaskTextHelper.ownerDisplayName(for: task.effectiveStatus))
                        .font(DS.Typography.caption)
                        .foregroundStyle(task.effectiveStatus.color)

                    Spacer()

                    if let date = task.completedAt ?? task.createdAt {
                        Text(date, style: .relative)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }

                if task.status == .running {
                    ProgressView()
                        .tint(DS.Colors.amber)
                        .scaleEffect(0.8, anchor: .leading)
                }
            }
        }
    }
}
