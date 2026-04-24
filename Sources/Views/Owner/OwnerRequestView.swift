import SwiftUI

struct OwnerRequestView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedTemplate: RequestTemplate?
    @State private var customDescription = ""
    @State private var showSuccess = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    headerSection
                    templateGrid
                    if selectedTemplate != nil {
                        descriptionSection
                        submitButton
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("New Request")
            .alert("Request Sent!", isPresented: $showSuccess) {
                Button("OK") {
                    selectedTemplate = nil
                    customDescription = ""
                }
            } message: {
                Text("Your request is in the queue. You'll see progress on the Home tab.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("What do you need?")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)
            Text("Pick a category and describe what you'd like done.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.secondary)
        }
    }

    private var templateGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
            ForEach(RequestTemplate.allCases) { template in
                TemplateCard(
                    template: template,
                    isSelected: selectedTemplate == template
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTemplate = template
                    }
                }
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Describe what you need")
                .font(DS.Typography.subheading)
                .foregroundStyle(DS.Colors.text)

            if let template = selectedTemplate {
                Text(template.placeholder)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            TextEditor(text: $customDescription)
                .frame(minHeight: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
        }
    }

    private var submitButton: some View {
        Button {
            submitRequest()
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                Text("Submit Request")
            }
            .font(DS.Typography.subheading)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(customDescription.isEmpty ? DS.Colors.secondary : DS.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .disabled(customDescription.isEmpty || isSubmitting)
        .accessibilityIdentifier("submit-request-button")
    }

    private func submitRequest() {
        guard let template = selectedTemplate else { return }
        isSubmitting = true

        let taskDescription = """
        Category: \(template.displayName)
        Request: \(customDescription)

        \(template.systemPrompt)
        """

        Task {
            do {
                try await firestoreService.createTask(
                    project: template.defaultProject,
                    path: template.defaultPath,
                    task: "\(template.displayName): \(customDescription.prefix(60))",
                    description: taskDescription,
                    priority: template.defaultPriority
                )
                showSuccess = true
            } catch {
                // Handle error
            }
            isSubmitting = false
        }
    }
}

enum RequestTemplate: String, CaseIterable, Identifiable {
    case bugFix
    case newFeature
    case uiChange
    case contentUpdate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bugFix: return "Fix a Bug"
        case .newFeature: return "New Feature"
        case .uiChange: return "UI Change"
        case .contentUpdate: return "Update Content"
        }
    }

    var icon: String {
        switch self {
        case .bugFix: return "ladybug"
        case .newFeature: return "sparkles"
        case .uiChange: return "paintbrush"
        case .contentUpdate: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .bugFix: return DS.Colors.red
        case .newFeature: return DS.Colors.blue
        case .uiChange: return DS.Colors.accent
        case .contentUpdate: return DS.Colors.amber
        }
    }

    var placeholder: String {
        switch self {
        case .bugFix: return "Describe the bug — what happens vs what should happen"
        case .newFeature: return "What feature do you want? How should it work?"
        case .uiChange: return "What should look different? Colors, layout, text?"
        case .contentUpdate: return "What text, images, or content needs to change?"
        }
    }

    var systemPrompt: String {
        switch self {
        case .bugFix: return "This is a bug fix request from the app owner. Investigate the issue, find the root cause, and fix it. Run tests to verify."
        case .newFeature: return "This is a new feature request from the app owner. Implement it following existing patterns and conventions. Add basic tests."
        case .uiChange: return "This is a UI change request from the app owner. Make the visual changes as described. Ensure it looks good on different screen sizes."
        case .contentUpdate: return "This is a content update request from the app owner. Update the text/content as described. Ensure no formatting is broken."
        }
    }

    var defaultProject: String { "palmr-ios" }
    var defaultPath: String { "~/repos/palmr-ios-2" }
    var defaultPriority: Int {
        switch self {
        case .bugFix: return 3
        case .newFeature: return 5
        case .uiChange: return 5
        case .contentUpdate: return 7
        }
    }
}

struct TemplateCard: View {
    let template: RequestTemplate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: template.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(template.color)

                Text(template.displayName)
                    .font(DS.Typography.subheading)
                    .foregroundStyle(DS.Colors.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xl)
            .background(isSelected ? template.color.opacity(0.1) : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? template.color : DS.Colors.border, lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .accessibilityIdentifier("template-\(template.rawValue)")
    }
}
