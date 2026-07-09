import SwiftUI
import AVFoundation

// Full-screen vertical paging feed (Instagram-Reels style). Each page is a
// looping ReelPlayerView; only the visible one plays. Overlays: close, shared
// mute, per-reel title/kind/duration, and Edit (trim).
struct VideoFeedView: View {
    let videos: [AssignedVideo]
    let service: VideoService
    @Environment(\.dismiss) private var dismiss
    @State private var currentID: String?
    @State private var muted = false
    @State private var editing: AssignedVideo?

    init(videos: [AssignedVideo], service: VideoService, startAt: AssignedVideo? = nil) {
        self.videos = videos
        self.service = service
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
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
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
            Text(video.title).font(.headline)
            Button { editing = video } label: {
                Label("Edit", systemImage: "scissors").font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("reel-edit")
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
