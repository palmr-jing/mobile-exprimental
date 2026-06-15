import SwiftUI

struct CreateTaskView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var project = ""
    @State private var path = ""
    @State private var taskName = ""
    @State private var description = ""
    @State private var priority = 5
    @State private var dependsOn = ""
    @State private var assignedWorker = ""
    @State private var allowParallel = false
    @State private var showSuccess = false
    @State private var isSubmitting = false
    @State private var showAskEmma = false

    private var availableProjects: [String] {
        Array(Set(firestoreService.tasks.map(\.project))).sorted()
    }

    private var availableWorkers: [String] {
        firestoreService.workers.map(\.hostname)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    Button {
                        showAskEmma = true
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "sparkles")
                            Text("Ask Emma instead — she'll pick the project")
                                .font(DS.Typography.caption)
                            Spacer()
                            Image(systemName: "chevron.right").font(DS.Typography.caption)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(DS.Colors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        FormField(label: "Project") {
                            TextField("e.g. palmr-ios", text: $project)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        if !availableProjects.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DS.Spacing.sm) {
                                    ForEach(availableProjects, id: \.self) { proj in
                                        Button {
                                            project = proj
                                        } label: {
                                            Text(proj)
                                                .font(DS.Typography.small)
                                                .foregroundStyle(project == proj ? .white : DS.Colors.text)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(project == proj ? DS.Colors.accent : DS.Colors.surface)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule().stroke(DS.Colors.border, lineWidth: project == proj ? 0 : 0.5)
                                                )
                                        }
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
                            Slider(value: Binding(
                                get: { Double(priority) },
                                set: { priority = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(DS.Colors.accent)
                        }

                        FormField(label: "Depends On (task IDs, comma separated)") {
                            TextField("e.g. 12, 15, 18", text: $dependsOn)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                        }

                        if !availableWorkers.isEmpty {
                            FormField(label: "Assign Worker") {
                                Picker("Worker", selection: $assignedWorker) {
                                    Text("Auto (any worker)").tag("")
                                    ForEach(availableWorkers, id: \.self) { worker in
                                        Text(worker).tag(worker)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(DS.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DS.Colors.border, lineWidth: 1)
                                )
                            }
                        }

                        Toggle(isOn: $allowParallel) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allow Parallel Execution")
                                    .font(DS.Typography.subheading)
                                    .foregroundStyle(DS.Colors.text)
                                Text("Let multiple workers run this task")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                        }
                        .tint(DS.Colors.accent)
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
            .sheet(isPresented: $showAskEmma) {
                AskEmmaView()
            }
        }
    }

    private var canSubmit: Bool {
        !project.isEmpty && !path.isEmpty && !taskName.isEmpty && !description.isEmpty
    }

    private func parseDependsOn() -> [Int] {
        dependsOn
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
                    dependsOn: parseDependsOn(),
                    assignedWorker: assignedWorker.isEmpty ? nil : assignedWorker,
                    allowParallel: allowParallel
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
        dependsOn = ""
        assignedWorker = ""
        allowParallel = false
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
