import SwiftUI
import FirebaseFirestore

struct TaskDetailView: View {
    let task: CommanderTask
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var outputChunks: [OutputChunk] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var selectedTab = 0
    @State private var outputListener: Any?
    @State private var chatListener: Any?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                metadataSection
                actionButtons
                tabContent
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Task #\(task.numId)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startListeners() }
        .onDisappear { stopListeners() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                StatusBadge(status: task.effectiveStatus)
                Spacer()
                if let worker = task.claimedBy {
                    Label(worker, systemImage: "server.rack")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }

            Text(task.task)
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)

            if !task.description.isEmpty {
                Text(task.description)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.secondary)
                    .lineLimit(5)
            }
        }
    }

    private var metadataSection: some View {
        CommanderCard {
            VStack(spacing: DS.Spacing.sm) {
                MetadataRow(label: "Project", value: task.project)
                MetadataRow(label: "Path", value: task.path)
                MetadataRow(label: "Priority", value: "\(task.priority)")
                if let cost = task.costUsd {
                    MetadataRow(label: "Cost", value: String(format: "$%.4f", cost))
                }
                if let duration = task.durationMs {
                    MetadataRow(label: "Duration", value: formatDuration(duration))
                }
                if let error = task.error {
                    MetadataRow(label: "Error", value: error, valueColor: DS.Colors.red)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            if task.status == .failed || task.status == .done {
                Button {
                    Task { try? await firestoreService.retryTask(taskId: task.id) }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }

            if task.status == .running {
                Button {
                    Task { try? await firestoreService.updateTaskStatus(taskId: task.id, status: .failed) }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DS.Colors.red)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
    }

    private var tabContent: some View {
        VStack(spacing: DS.Spacing.md) {
            Picker("Tab", selection: $selectedTab) {
                Text("Output").tag(0)
                Text("Chat").tag(1)
                Text("Result").tag(2)
            }
            .pickerStyle(.segmented)

            switch selectedTab {
            case 0:
                outputView
            case 1:
                chatView
            default:
                resultView
            }
        }
    }

    private var outputView: some View {
        CommanderDarkCard {
            ScrollView {
                if outputChunks.isEmpty {
                    Text("No output yet")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(outputChunks.map(\.text).joined())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 200)
        }
    }

    private var chatView: some View {
        VStack(spacing: DS.Spacing.md) {
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(chatMessages) { msg in
                        ChatBubble(message: msg)
                    }
                }
            }
            .frame(minHeight: 150)

            HStack(spacing: DS.Spacing.sm) {
                TextField("Message...", text: $chatInput)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let content = chatInput
                    chatInput = ""
                    Task { try? await firestoreService.sendChatMessage(taskId: task.id, content: content) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(DS.Colors.accent)
                }
                .disabled(chatInput.isEmpty)
            }
        }
    }

    private var resultView: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let result = task.resultText, !result.isEmpty {
                    Text("Result")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    Text(result)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                }
                if let followUp = task.followUp, !followUp.isEmpty {
                    Text("Follow-up")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    Text(followUp)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                }
                if task.resultText == nil && task.followUp == nil {
                    Text("No results yet")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func startListeners() {
        outputListener = firestoreService.listenToOutput(taskId: task.id) { chunks in
            self.outputChunks = chunks
        }
        chatListener = firestoreService.listenToChat(taskId: task.id) { messages in
            self.chatMessages = messages
        }
    }

    private func stopListeners() {
        (outputListener as? ListenerRegistration)?.remove()
        (chatListener as? ListenerRegistration)?.remove()
    }

    private func formatDuration(_ ms: Int) -> String {
        Formatters.duration(ms: ms)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    var valueColor: Color = DS.Colors.text

    var body: some View {
        HStack {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(valueColor)
                .lineLimit(2)
            Spacer()
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(message.content)
                .font(DS.Typography.body)
                .foregroundStyle(isUser ? .white : DS.Colors.text)
                .padding(DS.Spacing.md)
                .background(isUser ? DS.Colors.accent : DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isUser ? Color.clear : DS.Colors.border, lineWidth: 0.5)
                )
            if !isUser { Spacer() }
        }
    }
}
