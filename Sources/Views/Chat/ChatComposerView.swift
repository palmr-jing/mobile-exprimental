import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// The message composer: text field + voice dictation + photo/video attachment +
// send, with an "@" mention autocomplete dropdown. Mirrors the web composer.
struct ChatComposerView: View {
    @EnvironmentObject var chatService: ChatService
    @StateObject private var transcriber = VoiceTranscriberFactory.make()

    @State private var input = ""
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focused: Bool

    // Pending attachment — set by photo picker or clipboard paste, cleared on send or cancel.
    @State private var pendingImageData: Data?
    @State private var pendingImageName: String?
    @State private var pendingImageMime: String?

    // Active "@" autocomplete (caret assumed at end of text on mobile).
    private var mentionQuery: String? { Presence.activeMentionQuery(input) }
    private var mentionOptions: [RosterMember] {
        guard let q = mentionQuery else { return [] }
        return Presence.matchMentionQuery(chatService.roster, query: q, selfEmail: chatService.myEmail)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty || pendingImageData != nil
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

            if let imageData = pendingImageData, let uiImage = UIImage(data: imageData) {
                pendingImagePreview(uiImage)
            }

            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                PhotosPicker(selection: $photoItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .foregroundStyle(DS.Colors.secondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityIdentifier("chat-attach-button")

                if UIPasteboard.general.hasImages {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityIdentifier("chat-paste-image")
                }

                MicButton(transcriber: transcriber) { text in
                    input = text
                }

                TextField(chatService.isUploading ? "Uploading…" : "Message", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundStyle(DS.Colors.text)
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
                        .foregroundStyle(canSend ? DS.Colors.accent : DS.Colors.secondary)
                }
                .disabled(!canSend)
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

    // MARK: - Pending image preview

    private func pendingImagePreview(_ uiImage: UIImage) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(pendingImageName ?? "Image")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(1)
                if let data = pendingImageData {
                    Text(Self.formatBytes(data.count))
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.secondary)
                }
            }

            Spacer()

            Button {
                clearPendingImage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DS.Colors.secondary)
            }
            .accessibilityIdentifier("chat-remove-attachment")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.background)
    }

    // MARK: - Actions

    private func send() {
        let text = input
        let imageData = pendingImageData
        let imageName = pendingImageName
        let imageMime = pendingImageMime
        input = ""
        clearPendingImage()
        if transcriber.isRecording { transcriber.stop() }

        Task {
            if let data = imageData {
                let name = imageName ?? "upload-\(Int(Date().timeIntervalSince1970)).jpg"
                let mime = imageMime ?? "image/jpeg"
                await chatService.attach(data: data, fileName: name, contentType: mime)
            }
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                await chatService.sendText(text)
            }
        }
    }

    private func handlePicked(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let contentType = item.supportedContentTypes.first
        let mime = contentType?.preferredMIMEType ?? "application/octet-stream"
        let ext = contentType?.preferredFilenameExtension ?? "dat"
        let name = "upload-\(Int(Date().timeIntervalSince1970)).\(ext)"

        let isImage = mime.hasPrefix("image/")
        if isImage {
            await MainActor.run {
                pendingImageData = data
                pendingImageName = name
                pendingImageMime = mime
                photoItem = nil
            }
        } else {
            await chatService.attach(data: data, fileName: name, contentType: mime)
            await MainActor.run { photoItem = nil }
        }
    }

    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        let name = "paste-\(Int(Date().timeIntervalSince1970)).jpg"
        pendingImageData = data
        pendingImageName = name
        pendingImageMime = "image/jpeg"
    }

    private func clearPendingImage() {
        pendingImageData = nil
        pendingImageName = nil
        pendingImageMime = nil
    }

    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}
