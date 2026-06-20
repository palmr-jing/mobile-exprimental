import SwiftUI

// Voice-first "Ask Emma" entry point. The big mic (VoiceInputButton: on-device
// speech, audio-level ring, haptics) is the primary action; text is the
// fallback. The request is sent WITHOUT naming a project — the backend infers
// it (access-scoped) via the @emma chat path.
struct AskEmmaView: View {
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var prefill: String = ""
    var autoStartVoice: Bool = false
    /// When hosted as a root tab (not a sheet): no Cancel button, and `send()`
    /// hands off via `onSent` instead of dismissing.
    var isTab: Bool = false
    var onSent: (() -> Void)? = nil

    @StateObject private var speech = SpeechRecognitionService()
    @State private var text = ""

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                header

                // Primary: big voice button. Transcript flows into the text field.
                VoiceInputButton(speechService: speech) { transcript in
                    let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    text = t
                }
                .padding(.top, DS.Spacing.md)

                // Fallback / review: editable text + send.
                VStack(spacing: DS.Spacing.md) {
                    TextField("…or type what you need", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 0.5))
                        .accessibilityIdentifier("ask-emma-input")

                    Button {
                        send()
                    } label: {
                        Text("Send to Emma")
                            .font(DS.Typography.subheading)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(hasText ? DS.Colors.accent : DS.Colors.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .disabled(!hasText)
                }
                .padding(.horizontal, DS.Spacing.lg)

                Spacer()
            }
            .padding(.top, DS.Spacing.lg)
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isTab {
                    // Root tab: no Cancel; surface Sign Out here since there's no Settings screen.
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) { authService.signOut() } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
            .onAppear {
                if text.isEmpty { text = prefill }
            }
        }
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(DS.Colors.accent)
            Text("Ask Emma")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)
            Text("Tap the mic and just say what you need. Emma figures out the right project and files the work.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private func send() {
        var message = text.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }
        if !Presence.mentionsEmma(message) { message = "@emma \(message)" }
        chatService.setActiveChannel(ChatService.generalId)
        Task { await chatService.sendText(message) }
        if isTab {
            text = ""
            onSent?()   // hand off to the Chat tab so the reply is visible
        } else {
            dismiss()
        }
    }
}
