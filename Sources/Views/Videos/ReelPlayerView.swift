import SwiftUI
import AVKit

// One full-screen page in the vertical Videos feed: a looping AVPlayer that
// only plays while it is the active page, with tap-to-pause and a shared mute
// toggle. Playback is driven explicitly (default controls hidden) so paging
// between reels feels like Instagram/TikTok.
struct ReelPlayerView: View {
    let video: AssignedVideo
    let isActive: Bool
    @Binding var muted: Bool
    let service: VideoService

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var failed = false
    @State private var paused = false

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("reel-player")
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.title)
                    Text("Couldn't load this video").font(.subheadline)
                }.foregroundColor(.white.opacity(0.85))
            } else {
                ProgressView().tint(.white)
            }

            // Pause affordance.
            if paused && player != nil {
                Image(systemName: "play.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { togglePause() }
        .task { await load() }
        .onChange(of: isActive) { _, active in
            if active { resume() } else { player?.pause() }
        }
        .onChange(of: muted) { _, m in player?.isMuted = m }
        .onDisappear { teardown() }
    }

    private func load() async {
        guard player == nil, !failed else { return }
        guard let url = await service.playbackURL(for: video) else { failed = true; return }
        let p = AVPlayer(url: url)
        p.isMuted = muted
        p.actionAtItemEnd = .none
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        player = p
        if isActive { paused = false; p.play() }
    }

    private func resume() {
        guard let player else { return }
        paused = false
        player.play()
    }

    private func togglePause() {
        guard let player else { return }
        if paused { player.play(); paused = false } else { player.pause(); paused = true }
    }

    private func teardown() {
        player?.pause()
        if let loopObserver { NotificationCenter.default.removeObserver(loopObserver) }
        loopObserver = nil
        player = nil
    }
}
