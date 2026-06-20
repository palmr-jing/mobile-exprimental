import SwiftUI

// Private, voice-first 1:1 with Emma. The whole conversation lives on THIS
// screen — its own per-user channel (ChatService.emmaMessages), never posted to
// the shared team chat, so only this user ever sees it. Tap the mic to start,
// tap again to stop (no press-and-hold).
struct AskEmmaView: View {
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var prefill: String = ""
    var autoStartVoice: Bool = false
    /// Hosted as a root tab (vs. a sheet): show Sign Out instead of Cancel.
    var isTab: Bool = false
    var onSent: (() -> Void)? = nil

    @StateObject private var speech = SpeechRecognitionService()
    @State private var text = ""

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }
    private var myUid: String { authService.currentUser?.uid ?? "" }
    private var thinking: Bool {
        guard let last = chatService.emmaMessages.last else { return false }
        return last.authorUid == myUid && (last.emmaStatus == "pending" || last.emmaStatus == "processing")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if chatService.emmaMessages.isEmpty {
                    intro
                } else {
                    thread
                }
                inputBar
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isTab {
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
            .onAppear { if text.isEmpty { text = prefill } }
        }
    }

    // MARK: - Empty state

    private var intro: some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer()
            Image("PalmrMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(DS.Colors.accent)
            Text("Ask Emma")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.text)
            Text("Tap the mic and just say what you need. Emma figures out the right project and files the work — privately, just for you.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Conversation thread

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(chatService.emmaMessages) { msg in
                        MessageBubbleView(message: msg,
                                          isMine: msg.authorUid == myUid,
                                          myHandle: chatService.myHandle)
                            .id(msg.id)
                    }
                    if thinking {
                        HStack(spacing: DS.Spacing.xs) {
                            ProgressView().scaleEffect(0.7)
                            Text("Emma is thinking…")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .id("thinking")
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .onChange(of: chatService.emmaMessages.count) { _, _ in
                if let last = chatService.emmaMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input (voice-first)

    private var inputBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Tap to start, tap to stop — fills the field with the transcript to review.
            VoiceInputButton(speechService: speech, size: 60) { transcript in
                let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                text = t
            }
            HStack(spacing: DS.Spacing.sm) {
                TextField("…or type what you need", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 0.5))
                    .accessibilityIdentifier("ask-emma-input")
                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(hasText ? DS.Colors.accent : DS.Colors.secondary)
                }
                .disabled(!hasText)
                .accessibilityIdentifier("ask-emma-send")
            }
        }
        .padding(DS.Spacing.md)
    }

    private func send() {
        let message = text.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }
        text = ""
        Task { await chatService.sendToEmma(message) }
        onSent?()
    }
}
