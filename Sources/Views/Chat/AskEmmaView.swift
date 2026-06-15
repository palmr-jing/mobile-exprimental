import SwiftUI

// "Ask Emma" entry point: opens #general (where Emma lives), prefills an
// "@emma " prompt, and optionally auto-starts voice. The user describes what
// they want WITHOUT naming a project — the backend infers it (access-scoped).
// This replaces the manual project picker for the Owner flow.
struct AskEmmaView: View {
    @EnvironmentObject var chatService: ChatService
    @Environment(\.dismiss) private var dismiss

    var prefill: String = ""
    var autoStartVoice: Bool = false

    @StateObject private var transcriber = VoiceTranscriberFactory.make()
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Ask Emma")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                    Text("Describe what you need. Emma figures out the right project and files the work.")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.xl)

                HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                    TextField("e.g. the login button is broken", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 0.5))
                        .accessibilityIdentifier("ask-emma-input")
                    MicButton(transcriber: transcriber) { transcript in
                        text = transcript
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)

                Button {
                    send()
                } label: {
                    Text("Send to Emma")
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.secondary : DS.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if text.isEmpty { text = prefill }
                if autoStartVoice {
                    Task {
                        if !transcriber.isAuthorized { await transcriber.requestAuthorization() }
                        try? transcriber.start()
                    }
                }
            }
        }
    }

    private func send() {
        // Ensure the message reaches Emma's worker path.
        var message = text.trimmingCharacters(in: .whitespaces)
        if !Presence.mentionsEmma(message) { message = "@emma \(message)" }
        if transcriber.isRecording { transcriber.stop() }
        chatService.setActiveChannel(ChatService.generalId)
        Task { await chatService.sendText(message) }
        dismiss()
    }
}
