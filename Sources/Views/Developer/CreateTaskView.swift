import SwiftUI

struct CreateTaskView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var project = ""
    @State private var path = ""
    @State private var taskName = ""
    @State private var description = ""
    @State private var priority = 5
    @State private var showSuccess = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        FormField(label: "Project") {
                            TextField("e.g. palmr-ios", text: $project)
                                .textFieldStyle(.roundedBorder)
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
                            Slider(value: Binding(
                                get: { Double(priority) },
                                set: { priority = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(DS.Colors.accent)
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

    private func submitTask() {
        isSubmitting = true
        Task {
            do {
                try await firestoreService.createTask(
                    project: project,
                    path: path,
                    task: taskName,
                    description: description,
                    priority: priority
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
