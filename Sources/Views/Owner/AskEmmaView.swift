import SwiftUI

struct AskEmmaView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var textInput = ""
    @State private var showSuccess = false
    @State private var isSubmitting = false
    @State private var autoSendEnabled = true
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                DS.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    voiceSection
                    Spacer()
                    textFallbackSection
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle("Ask Emma")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Auto-send after pause", isOn: $autoSendEnabled)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
            }
            .alert("Request Sent!", isPresented: $showSuccess) {
                Button("OK") {}
            } message: {
                Text("Emma is working on it. Check the Home tab for progress.")
            }
            .onAppear {
                speechService.onAutoSend = { text in
                    guard autoSendEnabled else { return }
                    submit(text)
                }
            }
            .onChange(of: autoSendEnabled) {
                if autoSendEnabled {
                    speechService.onAutoSend = { text in
                        submit(text)
                    }
                } else {
                    speechService.onAutoSend = nil
                }
            }
        }
    }

    private var voiceSection: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.sm) {
                Text("What do you need?")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.text)

                Text(speechService.isRecording ? "Listening..." : "Tap the mic and tell Emma")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.secondary)
                    .animation(.easeInOut, value: speechService.isRecording)
            }

            VoiceInputButton(
                speechService: speechService,
                size: 88,
                onSubmit: { text in
                    submit(text)
                }
            )

            if autoSendEnabled && !speechService.isRecording {
                Text("Auto-sends after a pause")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
    }

    private var textFallbackSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Divider()
                .padding(.bottom, DS.Spacing.sm)

            Text("or type your request")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondary)

            HStack(spacing: DS.Spacing.sm) {
                TextField("Tell Emma what you need...", text: $textInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                    .onSubmit { submitTextInput() }

                Button {
                    submitTextInput()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? DS.Colors.secondary : DS.Colors.accent)
                }
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    private func submitTextInput() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textInput = ""
        isTextFieldFocused = false
        submit(text)
    }

    private func submit(_ text: String) {
        guard !isSubmitting else { return }
        isSubmitting = true

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        Task {
            do {
                try await firestoreService.createEmmaTask(message: text)
                showSuccess = true
                speechService.transcript = ""
            } catch {
                speechService.errorMessage = "Failed to send: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }
}
