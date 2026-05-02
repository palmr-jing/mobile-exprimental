import SwiftUI

struct OwnerHomeView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .owner
    @State private var showSettings = false

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

    private var pendingTasks: [CommanderTask] {
        firestoreService.tasks.filter { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    statusHeroCard
                    if !needsAttention.isEmpty { attentionSection }
                    if !activeTasks.isEmpty { activeSection }
                    queueSection
                    if !completedToday.isEmpty { completedSection }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) {
                ownerTopBar
            }
            .sheet(isPresented: $showSettings) {
                OwnerSettingsView()
                    .environmentObject(authService)
            }
            .refreshable {
                firestoreService.listenToTasks()
            }
        }
    }

    private var ownerTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Commander")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Text(greeting)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var statusHeroCard: some View {
        CommanderDarkCard {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(activeTasks.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.amber)
                        Text("Working")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(pendingTasks.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.blue)
                        Text("Queued")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(completedToday.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.green)
                        Text("Done Today")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }

                if needsAttention.count > 0 {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Colors.red)
                        Text("\(needsAttention.count) item\(needsAttention.count == 1 ? "" : "s") need\(needsAttention.count == 1 ? "s" : "") attention")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.red)
                    }
                }
            }
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.red)

            ForEach(needsAttention.prefix(5)) { task in
                OwnerTaskCard(task: task, showError: true)
            }
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Working On")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                Text("\(activeTasks.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(DS.Colors.amber.opacity(0.1))
                    .clipShape(Capsule())
            }

            ForEach(activeTasks) { task in
                OwnerTaskCard(task: task, showProgress: true)
            }
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("In Queue")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                Text("\(pendingTasks.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            if pendingTasks.isEmpty {
                CommanderCard {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(DS.Colors.secondary)
                        Text("Queue is empty")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(pendingTasks.prefix(5)) { task in
                    OwnerTaskCard(task: task)
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Done Today")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Colors.green)
            }

            ForEach(completedToday.prefix(5)) { task in
                OwnerTaskCard(task: task, showCompletion: true)
            }
        }
    }
}

struct OwnerTaskCard: View {
    let task: CommanderTask
    var showProgress: Bool = false
    var showError: Bool = false
    var showCompletion: Bool = false

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    StatusBadge(status: task.effectiveStatus)
                    Spacer()
                    if let date = task.completedAt ?? task.createdAt {
                        Text(date, style: .relative)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }

                Text(task.task)
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(2)

                if showProgress && task.status == .running {
                    HStack(spacing: DS.Spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("In progress...")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.amber)
                    }
                }

                if showError, let error = task.error {
                    Text(error)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.red)
                        .lineLimit(2)
                }

                if showCompletion, task.status == .done {
                    if let result = task.resultText {
                        Text(result)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.green)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Label(task.project, systemImage: "folder")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                    Spacer()
                }
            }
        }
    }
}
