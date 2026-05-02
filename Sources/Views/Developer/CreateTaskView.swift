import SwiftUI

struct CreateTaskView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var project = ""
    @State private var path = ""
    @State private var taskName = ""
    @State private var description = ""
    @State private var priority = 5
    @State private var assignedWorker = ""
    @State private var dependsOnText = ""
    @State private var showSuccess = false
    @State private var isSubmitting = false
    @State private var showProjectPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        FormField(label: "Project") {
                            HStack {
                                TextField("e.g. palmr-ios", text: $project)
                                    .textFieldStyle(.roundedBorder)
                                if !firestoreService.projects.isEmpty {
                                    Menu {
                                        ForEach(firestoreService.projects, id: \.self) { proj in
                                            Button(proj) {
                                                project = proj
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down.circle")
                                            .foregroundStyle(DS.Colors.accent)
                                    }
                                }
                            }
                        }

                        FormField(label: "Working Directory") {
                            TextField("e.g. ~/repos/palmr-ios", text: $path)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        FormField(label: "Task Name") {
                            TextField("Short description of the task", text: $taskName)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormField(label: "Description") {
                            TextEditor(text: $description)
                                .frame(minHeight: 120)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DS.Colors.border, lineWidth: 1)
                                )
                        }

                        FormField(label: "Priority (\(priority))") {
                            HStack {
                                Text("High")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.red)
                                Slider(value: Binding(
                                    get: { Double(priority) },
                                    set: { priority = Int($0) }
                                ), in: 1...10, step: 1)
                                .tint(DS.Colors.accent)
                                Text("Low")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                        }

                        FormField(label: "Assigned Worker (optional)") {
                            if firestoreService.workers.isEmpty {
                                TextField("Worker hostname", text: $assignedWorker)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                Menu {
                                    Button("None") { assignedWorker = "" }
                                    ForEach(firestoreService.workers.filter(\.isOnline)) { worker in
                                        Button(worker.hostname) {
                                            assignedWorker = worker.hostname
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(assignedWorker.isEmpty ? "Select worker..." : assignedWorker)
                                            .foregroundStyle(assignedWorker.isEmpty ? DS.Colors.secondary : DS.Colors.text)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(DS.Colors.secondary)
                                    }
                                    .padding(10)
                                    .background(DS.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(DS.Colors.border, lineWidth: 1)
                                    )
                                }
                            }
                        }

                        FormField(label: "Depends On (comma-separated IDs)") {
                            TextField("e.g. 45, 46", text: $dependsOnText)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    Button {
                        submitTask()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Create Task")
                        }
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? DS.Colors.dark : DS.Colors.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("New Task")
            .alert("Task Created", isPresented: $showSuccess) {
                Button("OK") { clearForm() }
            } message: {
                Text("Task has been added to the queue.")
            }
        }
    }

    private var canSubmit: Bool {
        !project.isEmpty && !path.isEmpty && !taskName.isEmpty && !description.isEmpty
    }

    private var parsedDependencies: [Int] {
        dependsOnText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func submitTask() {
        isSubmitting = true
        Task {
            do {
                try await firestoreService.createTask(
                    project: project,
                    path: path,
                    task: taskName,
                    description: description,
                    priority: priority,
                    assignedWorker: assignedWorker.isEmpty ? nil : assignedWorker,
                    dependsOn: parsedDependencies
                )
                showSuccess = true
            } catch {
                // Handle error
            }
            isSubmitting = false
        }
    }

    private func clearForm() {
        project = ""
        path = ""
        taskName = ""
        description = ""
        priority = 5
        assignedWorker = ""
        dependsOnText = ""
    }
}

struct FormField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondary)
            content
        }
    }
}
