import SwiftUI

struct OwnerHomeView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .owner
    @AppStorage("hasSeenOwnerHint") private var hasSeenOwnerHint = false
    @State private var showModeSwitcher = false
    @State private var showFirstRunHint = false

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
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        greetingCard
                        if !needsAttention.isEmpty { attentionSection }
                        if !activeTasks.isEmpty { activeSection }
                        summarySection
                    }
                    .padding(DS.Spacing.lg)
                }
                .background(DS.Colors.background.ignoresSafeArea())

                if showFirstRunHint {
                    FirstRunHintView(message: "Tap the Request tab and just say what you need.") {
                        withAnimation {
                            showFirstRunHint = false
                            hasSeenOwnerHint = true
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModeSwitcher = true
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.secondary)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .sheet(isPresented: $showModeSwitcher) {
                ModeSwitcher()
                    .presentationDetents([.medium])
            }
            .onAppear {
                if !hasSeenOwnerHint {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { showFirstRunHint = true }
                    }
                }
            }
        }
    }

    private var greetingCard: some View {
        CommanderDarkCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Your App Status")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)

                HStack(spacing: DS.Spacing.xl) {
                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(activeTasks.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.amber)
                        Text("Working on")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(completedToday.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.green)
                        Text("Done today")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: DS.Spacing.xs) {
                        Text("\(needsAttention.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(needsAttention.isEmpty ? .gray : DS.Colors.red)
                        Text(needsAttention.isEmpty ? "All good" : "Needs you")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.red)

            ForEach(needsAttention.prefix(3)) { task in
                OwnerTaskCard(task: task)
            }
        }
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
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Recently Completed")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            if completedToday.isEmpty {
                CommanderCard {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(DS.Colors.secondary.opacity(0.5))
                        Text("Nothing completed yet today")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("Completed tasks will show up here.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                }
            } else {
                ForEach(completedToday.prefix(5)) { task in
                    OwnerTaskCard(task: task)
                }
            }
        }
    }
}

struct OwnerTaskCard: View {
    let task: CommanderTask

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

                if task.status == .running {
                    ProgressView()
                        .tint(DS.Colors.amber)
                        .scaleEffect(0.8, anchor: .leading)
                }
            }
        }
    }
}
