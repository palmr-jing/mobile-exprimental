import SwiftUI

struct WorkersView: View {
    @EnvironmentObject var firestoreService: FirestoreService

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                summaryCard

                if firestoreService.workers.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundStyle(DS.Colors.secondary.opacity(0.5))
                        Text("No workers online")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("Start a worker with: cd worker && node index.js")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DS.Spacing.lg)], spacing: DS.Spacing.lg) {
                        ForEach(firestoreService.workers) { worker in
                            WorkerDetailCard(worker: worker)
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Workers")
    }

    private var summaryCard: some View {
        CommanderDarkCard {
            HStack(spacing: DS.Spacing.xl) {
                VStack {
                    Text("\(firestoreService.workers.filter(\.isOnline).count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.green)
                    Text("Online")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.gray)
                }

                VStack {
                    let total = firestoreService.workers.reduce(0) { $0 + $1.activeTaskCount }
                    Text("\(total)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.amber)
                    Text("Active")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.gray)
                }

                VStack {
                    let cost = firestoreService.workers.reduce(0.0) { $0 + $1.totalCost }
                    Text("$\(cost, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Total Cost")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct WorkerDetailCard: View {
    let worker: CommanderWorker

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Circle()
                        .fill(worker.isOnline ? DS.Colors.green : DS.Colors.secondary)
                        .frame(width: 10, height: 10)
                    Text(worker.hostname)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    Spacer()
                    Text(worker.isOnline ? "Online" : "Offline")
                        .font(DS.Typography.caption)
                        .foregroundStyle(worker.isOnline ? DS.Colors.green : DS.Colors.secondary)
                }

                HStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading) {
                        Text("Tasks Active")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("\(worker.activeTaskCount)")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(DS.Colors.text)
                    }

                    VStack(alignment: .leading) {
                        Text("Completed")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("\(worker.tasksCompleted)")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(DS.Colors.text)
                    }

                    VStack(alignment: .leading) {
                        Text("Cost")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                        Text("$\(worker.totalCost, specifier: "%.2f")")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(DS.Colors.text)
                    }
                }

                if let heartbeat = worker.lastHeartbeat {
                    Text("Last seen: \(heartbeat, style: .relative) ago")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
        }
    }
}
