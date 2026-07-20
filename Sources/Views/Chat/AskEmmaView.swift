import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

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
    @State private var thinkingElapsed = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var pendingImageName: String?
    @State private var pendingImageMime: String?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty || pendingImageData != nil
    }
    private var myUid: String { authService.currentUser?.uid ?? "" }
    private var thinking: Bool {
        guard let last = chatService.emmaMessages.last else { return false }
        return last.authorUid == myUid && (last.emmaStatus == "pending" || last.emmaStatus == "processing")
    }

    private var thinkingLabel: String {
        if thinkingElapsed < 5 { return "Emma is thinking…" }
        if thinkingElapsed < 120 {
            return "Emma is thinking… (\(thinkingElapsed)s)"
        }
        let min = thinkingElapsed / 60
        let sec = thinkingElapsed % 60
        return "Still working… (\(min):\(String(format: "%02d", sec)))"
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
                        ReportIssueButton(tab: "Ask Emma")
                    }
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
            .onReceive(ticker) { _ in
                if thinking { thinkingElapsed += 1 }
            }
            .onChange(of: thinking) { _, isThinking in
                if isThinking { thinkingElapsed = 0 }
            }
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
                            Text(thinkingLabel)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondary)
                                .contentTransition(.numericText())
                                .animation(.default, value: thinkingElapsed)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .id("thinking")
                    }
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: chatService.emmaMessages.count) { _, _ in
                if thinking {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                } else if let last = chatService.emmaMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input (voice-first)

    private var inputBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            VoiceInputButton(speechService: speech, size: 60) { transcript in
                let t = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                text = t
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
                .accessibilityIdentifier("ask-emma-attach-button")

                if UIPasteboard.general.hasImages {
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityIdentifier("ask-emma-paste-image")
                }

                TextField(chatService.isUploading ? "Uploading…" : "…or type what you need", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundStyle(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 0.5))
                    .accessibilityIdentifier("ask-emma-input")

                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? DS.Colors.accent : DS.Colors.secondary)
                }
                .disabled(!canSend)
                .accessibilityIdentifier("ask-emma-send")
            }
        }
        .padding(DS.Spacing.md)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await handlePicked(item) }
        }
    }

    private func send() {
        let message = text.trimmingCharacters(in: .whitespaces)
        let imageData = pendingImageData
        let imageName = pendingImageName
        let imageMime = pendingImageMime
        guard !message.isEmpty || imageData != nil else { return }
        text = ""
        clearPendingImage()

        Task {
            if let data = imageData {
                let name = imageName ?? "upload-\(Int(Date().timeIntervalSince1970)).jpg"
                let mime = imageMime ?? "image/jpeg"
                await chatService.sendToEmmaWithAttachment(
                    text: message, data: data, fileName: name, contentType: mime
                )
            } else {
                await chatService.sendToEmma(message)
            }
        }
        onSent?()
    }

    // MARK: - Attachment helpers

    private func handlePicked(_ item: PhotosPickerItem) async {
        let loaded: PhotoAttachmentLoader.Loaded
        do {
            loaded = try await PhotoAttachmentLoader.load(item)
        } catch {
            // A video used to fail here silently (loadTransferable(Data) is nil for
            // movies) — surface it instead so the user knows the pick didn't take.
            await MainActor.run {
                chatService.uploadError = "Couldn't read that attachment. Try a different file."
                photoItem = nil
            }
            return
        }

        if loaded.isImage {
            await MainActor.run {
                pendingImageData = loaded.data
                pendingImageName = loaded.fileName
                pendingImageMime = loaded.mime
                photoItem = nil
            }
        } else {
            await MainActor.run { photoItem = nil }
            await chatService.sendToEmmaWithAttachment(
                text: "", data: loaded.data, fileName: loaded.fileName, contentType: loaded.mime
            )
        }
    }

    private func pasteFromClipboard() {
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        pendingImageData = data
        pendingImageName = "paste-\(Int(Date().timeIntervalSince1970)).jpg"
        pendingImageMime = "image/jpeg"
    }

    private func clearPendingImage() {
        pendingImageData = nil
        pendingImageName = nil
        pendingImageMime = nil
    }

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
                    Text(ChatComposerView.formatBytes(data.count))
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
            .accessibilityIdentifier("ask-emma-remove-attachment")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.background)
    }
}
