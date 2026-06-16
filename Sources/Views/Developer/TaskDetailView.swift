import SwiftUI
import FirebaseFirestore

struct TaskDetailView: View {
    let task: CommanderTask
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var speechService = SpeechService()
    @State private var outputChunks: [OutputChunk] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var selectedTab = 0
    @State private var outputListener: ListenerRegistration?
    @State private var chatListener: ListenerRegistration?
    @State private var lastSeenMessageCount = 0

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
        .onDisappear {
            stopListeners()
            speechService.stop()
        }
        .onChange(of: chatMessages.count) { oldCount, newCount in
            guard speechService.autoSpeak,
                  newCount > oldCount,
                  newCount > lastSeenMessageCount,
                  let last = chatMessages.last,
                  last.role != "user"
            else { return }
            speechService.speak(text: last.content, messageId: last.id)
        }
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
            HStack {
                Spacer()
                Button {
                    speechService.autoSpeak.toggle()
                } label: {
                    Label(
                        speechService.autoSpeak ? "Auto-speak On" : "Auto-speak",
                        systemImage: speechService.autoSpeak ? "speaker.wave.3.fill" : "speaker.slash"
                    )
                    .font(DS.Typography.caption)
                    .foregroundStyle(speechService.autoSpeak ? DS.Colors.accent : DS.Colors.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        speechService.autoSpeak
                            ? DS.Colors.accent.opacity(0.12)
                            : DS.Colors.border.opacity(0.5)
                    )
                    .clipShape(Capsule())
                }
            }

            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(chatMessages) { msg in
                        ChatBubble(message: msg, speechService: speechService)
                    }
                }
            }
            .frame(minHeight: 150)

            HStack(spacing: DS.Spacing.sm) {
                TextField("Message...", text: $chatInput)
                    .textFieldStyle(.roundedBorder)

                Button {
                    speechService.stop()
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
            if self.lastSeenMessageCount == 0 {
                self.lastSeenMessageCount = messages.count
            }
            self.chatMessages = messages
        }
    }

    private func stopListeners() {
        outputListener?.remove()
        chatListener?.remove()
    }

    private func formatDuration(_ ms: Int) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return "\(minutes)m \(remaining)s"
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
    @ObservedObject var speechService: SpeechService

    private var isUser: Bool { message.role == "user" }
    private var isSpeaking: Bool { speechService.speakingMessageId == message.id }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer() }
            VStack(alignment: isUser ? .trailing : .leading, spacing: DS.Spacing.xs) {
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

                if !isUser {
                    Button {
                        if isSpeaking {
                            speechService.stop()
                        } else {
                            speechService.speak(text: message.content, messageId: message.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                                .font(.system(size: 11))
                            if isSpeaking {
                                Text("Stop")
                                    .font(DS.Typography.small)
                            }
                        }
                        .foregroundStyle(isSpeaking ? DS.Colors.accent : DS.Colors.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
            if !isUser { Spacer() }
        }
    }
}
