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

    private var greetingCard: some View {
        CommanderDarkCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Your App Status")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.white)

                HStack(spacing: DS.Spacing.xl) {
                    VStack {
                        Text("\(activeTasks.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.amber)
                        Text("In Progress")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        Text("\(completedToday.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.green)
                        Text("Done Today")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                    VStack {
                        Text("\(needsAttention.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(needsAttention.isEmpty ? .gray : DS.Colors.red)
                        Text("Attention")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle.fill")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.red)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                ForEach(needsAttention.prefix(3)) { task in
                    OwnerTaskCard(task: task)
                }
            }
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Working On")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                ForEach(activeTasks) { task in
                    OwnerTaskCard(task: task)
                }
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                    ForEach(completedToday.prefix(5)) { task in
                        OwnerTaskCard(task: task)
                    }
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
