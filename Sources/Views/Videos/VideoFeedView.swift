import SwiftUI
import AVFoundation

// Full-screen vertical paging feed (Instagram-Reels style). Each page is a
// looping ReelPlayerView; only the visible one plays. Overlays: close, shared
// mute, per-reel title/kind/duration, and Edit (trim).
struct VideoFeedView: View {
    let videos: [AssignedVideo]
    let service: VideoService
    // Closing is owned by the parent (it clears the state that shows this feed),
    // NOT by @Environment(\.dismiss) — the feed is a plain overlay, not a modal
    // cover, so there is no presentation to dismiss.
    let onClose: () -> Void
    @EnvironmentObject private var chatService: ChatService
    @State private var currentID: String?
    @State private var muted = false
    @State private var editing: AssignedVideo?
    @State private var sharing: AssignedVideo?

    init(videos: [AssignedVideo], service: VideoService, startAt: AssignedVideo? = nil,
         onClose: @escaping () -> Void) {
        self.videos = videos
        self.service = service
        self.onClose = onClose
        _currentID = State(initialValue: startAt?.id ?? videos.first?.id)
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(videos) { video in
                    ZStack(alignment: .bottomLeading) {
                        ReelPlayerView(video: video, isActive: currentID == video.id,
                                       muted: $muted, service: service)
                        overlay(for: video)
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .ignoresSafeArea()
        .background(.black)
        .overlay(alignment: .top) { topBar }
        .task { activateAudioSession() }
        .fullScreenCover(item: $editing) { v in
            ReelEditorView(video: v, service: service)
        }
        .sheet(item: $sharing) { v in
            ShareToChatSheet(video: v, chatService: chatService)
                .presentationDetents([.medium, .large])
        }
    }

    private var topBar: some View {
        HStack {
            Button { onClose() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold)).foregroundColor(.white)
                    .padding(10).background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityIdentifier("reel-close")
            Spacer()
            Button { muted.toggle() } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3).foregroundColor(.white)
                    .padding(10).background(.black.opacity(0.35), in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func overlay(for video: AssignedVideo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(video.kind == .reel ? "REEL" : "RECORDING")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.2), in: Capsule())
                if let d = video.durationLabel {
                    Text(d).font(.caption.weight(.medium)).opacity(0.9)
                }
            }
            Text(video.title).font(.headline).accessibilityIdentifier("reel-title")
            HStack(spacing: 20) {
                Button { editing = video } label: {
                    Label("Edit", systemImage: "scissors").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("reel-edit")
                Button { sharing = video } label: {
                    Label("Send to chat", systemImage: "paperplane.fill").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("reel-share")
            }
        }
        .foregroundColor(.white)
        .padding(16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        )
    }

    // Play audio even with the ringer silenced.
    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// Share a reel/recording into chat: pick a destination (Ask Emma or a team
// channel), optionally add a caption/@emma, and post a video message that holds
// the playable URL + poster as metadata (see ChatService.reelMessagePayload) so
// Emma can fetch the clip straight from the message.
private struct ShareToChatSheet: View {
    let video: AssignedVideo
    @ObservedObject var chatService: ChatService
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var target: Target = .emma
    @State private var mentionEmma = true
    @State private var sending = false

    // Ask Emma (the private 1:1) or a named team channel.
    enum Target: Hashable { case emma, channel(String) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Send to") {
                    Picker("Destination", selection: $target) {
                        Label("Ask Emma", systemImage: "sparkles").tag(Target.emma)
                        ForEach(chatService.visibleChannels) { ch in
                            Label("#\(ch.name)", systemImage: "number").tag(Target.channel(ch.id))
                        }
                    }
                    .accessibilityIdentifier("share-destination")
                }
                Section("Message") {
                    TextField("Add a caption…", text: $caption, axis: .vertical)
                        .lineLimit(1...4)
                    if case .channel = target {
                        Toggle("Mention @emma", isOn: $mentionEmma)
                    }
                }
                Section("Sharing") {
                    HStack(spacing: 12) {
                        Image(systemName: "film").foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(video.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            if let d = video.durationLabel {
                                Text(d).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share to chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(sending)
                        .accessibilityIdentifier("share-send")
                }
            }
        }
    }

    private func send() {
        sending = true
        let channelId: String
        let emma: Bool
        switch target {
        case .emma:
            channelId = chatService.emmaChannelId; emma = true
        case .channel(let id):
            channelId = id; emma = mentionEmma
        }
        let clip = video
        let text = caption
        Task {
            await chatService.sendReel(clip, toChannel: channelId, caption: text, mentionEmma: emma)
            dismiss()
        }
    }
}
