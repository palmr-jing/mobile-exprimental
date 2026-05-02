import SwiftUI
import FirebaseFirestore

struct TaskDetailView: View {
    let task: CommanderTask
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var outputChunks: [OutputChunk] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatInput = ""
    @State private var selectedTab = 0
    @State private var outputListener: ListenerRegistration?
    @State private var chatListener: ListenerRegistration?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        Task { try? await firestoreService.retryTask(taskId: task.id) }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DS.Colors.text)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TaskEditSheet(task: task)
                .environmentObject(firestoreService)
        }
        .alert("Delete Task", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await firestoreService.deleteTask(taskId: task.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete task #\(task.numId)?")
        }
        .onAppear { startListeners() }
        .onDisappear { stopListeners() }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                StatusBadge(status: task.effectiveStatus)
                if let review = task.reviewStatus {
                    Text(review)
                        .font(DS.Typography.small)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(review == "approved" ? DS.Colors.green : DS.Colors.amber)
                        .clipShape(Capsule())
                }
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
            }
        }
    }

    private var metadataSection: some View {
        CommanderCard {
            VStack(spacing: DS.Spacing.sm) {
                MetadataRow(label: "Project", value: task.project)
                MetadataRow(label: "Path", value: task.path)
                MetadataRow(label: "Priority", value: "\(task.priority)")
                if let worker = task.assignedWorker {
                    MetadataRow(label: "Assigned", value: worker)
                }
                if !task.dependsOn.isEmpty {
                    MetadataRow(label: "Depends", value: task.dependsOn.map { "#\($0)" }.joined(separator: ", "))
                }
                if let cost = task.costUsd {
                    MetadataRow(label: "Cost", value: String(format: "$%.4f", cost))
                }
                if let duration = task.durationMs {
                    MetadataRow(label: "Duration", value: formatDuration(duration))
                }
                if let exitCode = task.exitCode {
                    MetadataRow(label: "Exit Code", value: "\(exitCode)", valueColor: exitCode == 0 ? DS.Colors.green : DS.Colors.red)
                }
                if let error = task.error {
                    MetadataRow(label: "Error", value: error, valueColor: DS.Colors.red)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            if task.effectiveStatus == .needsReview {
                HStack(spacing: DS.Spacing.md) {
                    Button {
                        Task { try? await firestoreService.approveTask(taskId: task.id) }
                    } label: {
                        Label("Approve", systemImage: "checkmark")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.Colors.green)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }

                    Button {
                        Task { try? await firestoreService.rejectTask(taskId: task.id) }
                    } label: {
                        Label("Reject", systemImage: "xmark")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.Colors.red)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }
            }

            HStack(spacing: DS.Spacing.md) {
                if task.status == .failed || task.status == .blocked {
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

                if task.status == .pending {
                    Menu {
                        ForEach([TaskStatus.done, .blocked, .failed], id: \.self) { status in
                            Button(status.displayName) {
                                Task { try? await firestoreService.updateTaskStatus(taskId: task.id, status: status) }
                            }
                        }
                    } label: {
                        Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DS.Colors.dark)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
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
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .frame(minHeight: 200, maxHeight: 400)
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
            .frame(minHeight: 150, maxHeight: 300)

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
        VStack(spacing: DS.Spacing.md) {
            if let result = task.resultText, !result.isEmpty {
                CommanderCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Result")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(DS.Colors.text)
                        Text(result)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let followUp = task.followUp, !followUp.isEmpty {
                CommanderCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Follow-up")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(DS.Colors.text)
                        Text(followUp)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if task.resultText == nil && task.followUp == nil {
                CommanderCard {
                    Text("No results yet")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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

// MARK: - Supporting Views

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
                .lineLimit(3)
            Spacer()
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
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
                if let status = message.status, status != "done" {
                    Text(status)
                        .font(DS.Typography.small)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    let task: CommanderTask
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss
    @State private var project: String
    @State private var path: String
    @State private var taskName: String
    @State private var description: String
    @State private var priority: Int
    @State private var assignedWorker: String
    @State private var isSaving = false

    init(task: CommanderTask) {
        self.task = task
        _project = State(initialValue: task.project)
        _path = State(initialValue: task.path)
        _taskName = State(initialValue: task.task)
        _description = State(initialValue: task.description)
        _priority = State(initialValue: task.priority)
        _assignedWorker = State(initialValue: task.assignedWorker ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    FormField(label: "Project") {
                        TextField("Project", text: $project)
                            .textFieldStyle(.roundedBorder)
                    }
                    FormField(label: "Path") {
                        TextField("Path", text: $path)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    FormField(label: "Task") {
                        TextField("Task name", text: $taskName)
                            .textFieldStyle(.roundedBorder)
                    }
                    FormField(label: "Description") {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(DS.Colors.border, lineWidth: 1)
                            )
                    }
                    FormField(label: "Priority (\(priority))") {
                        Slider(value: Binding(
                            get: { Double(priority) },
                            set: { priority = Int($0) }
                        ), in: 1...10, step: 1)
                        .tint(DS.Colors.accent)
                    }
                    FormField(label: "Assigned Worker (optional)") {
                        TextField("Worker hostname", text: $assignedWorker)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle("Edit Task #\(task.numId)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveChanges() }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        var fields: [String: Any] = [
            "project": project,
            "path": path,
            "task": taskName,
            "description": description,
            "priority": priority
        ]
        if !assignedWorker.isEmpty {
            fields["assigned_worker"] = assignedWorker
        }
        Task {
            try? await firestoreService.updateTaskFields(taskId: task.id, fields: fields)
            dismiss()
        }
    }
}
