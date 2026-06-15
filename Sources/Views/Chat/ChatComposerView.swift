import SwiftUI
import PhotosUI

// The message composer: text field + voice dictation + photo/video attachment +
// send, with an "@" mention autocomplete dropdown. Mirrors the web composer.
struct ChatComposerView: View {
    @EnvironmentObject var chatService: ChatService
    @StateObject private var transcriber = VoiceTranscriberFactory.make()

    @State private var input = ""
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focused: Bool

    // Active "@" autocomplete (caret assumed at end of text on mobile).
    private var mentionQuery: String? { Presence.activeMentionQuery(input) }
    private var mentionOptions: [RosterMember] {
        guard let q = mentionQuery else { return [] }
        return Presence.matchMentionQuery(chatService.roster, query: q, selfEmail: chatService.myEmail)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let query = mentionQuery, !mentionOptions.isEmpty, !query.isEmpty || input.hasSuffix("@") {
                MentionAutocompleteView(options: mentionOptions) { member in
                    let result = Presence.applyMention(input, caret: nil, handle: Presence.mentionHandle(email: member.email))
                    input = result.text
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)
            }

            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                PhotosPicker(selection: $photoItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Colors.secondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityIdentifier("chat-attach-button")

                MicButton(transcriber: transcriber) { text in
                    input = text
                }

                TextField(chatService.isUploading ? "Uploading…" : "Message", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.border, lineWidth: 0.5))
                    .focused($focused)
                    .accessibilityIdentifier("chat-composer-input")

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? DS.Colors.secondary : DS.Colors.accent)
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("chat-send")
            }
            .padding(DS.Spacing.sm)
        }
        .background(DS.Colors.surface)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await handlePicked(item) }
        }
    }

    private func send() {
        let text = input
        input = ""
        if transcriber.isRecording { transcriber.stop() }
        Task { await chatService.sendText(text) }
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let contentType = item.supportedContentTypes.first
        let mime = contentType?.preferredMIMEType ?? "application/octet-stream"
        let ext = contentType?.preferredFilenameExtension ?? "dat"
        let name = "upload-\(Int(Date().timeIntervalSince1970)).\(ext)"
        await chatService.attach(data: data, fileName: name, contentType: mime)
        await MainActor.run { photoItem = nil }
    }
}
