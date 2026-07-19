import SwiftUI
import UIKit
import AVFoundation

// One full-screen page in the vertical Videos feed: a looping AVPlayer that
// only plays while it is the active page, with tap-to-pause and a shared mute
// toggle. Playback is driven explicitly (default controls hidden) so paging
// between reels feels like Instagram/TikTok.
//
// The video is rendered with a raw AVPlayerLayer (PlayerLayerView), NOT SwiftUI's
// VideoPlayer. VideoPlayer wraps a modal AVPlayerViewController, and inside a
// fullScreenCover its teardown could orphan a UIKit presentation controller that
// then swallowed touches on the grid — so after opening+closing one reel, the
// next tap did nothing. A layer has no view-controller lifecycle to leak.
struct ReelPlayerView: View {
    let video: AssignedVideo
    let isActive: Bool
    @Binding var muted: Bool
    let service: VideoService

    @State private var player: AVPlayer?
    @State private var loopObserver: NSObjectProtocol?
    @State private var failObserver: NSObjectProtocol?
    @State private var failed = false
    @State private var failureMessage = "Couldn't load this video"
    @State private var paused = false

    var body: some View {
        ZStack {
            Color.black
            if let player {
                PlayerLayerView(player: player)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("reel-player")
            } else if failed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.title)
                    Text(failureMessage).font(.subheadline).multilineTextAlignment(.center)
                        .accessibilityIdentifier("reel-failed")
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 32)
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
        // Bottom-trailing: the feed's caption and action row are leading-aligned
        // and the close/mute controls sit up top, so this corner is the one spot
        // that stays clear. Raised past the home indicator. Hit testing is off,
        // so tap-to-pause still works through it.
        .overlay(alignment: .bottomTrailing) {
            if player != nil {
                PalmrWatermark()
                    .padding(.trailing, 16)
                    .padding(.bottom, 44)
                    .allowsHitTesting(false)
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

        // "Reel · N clips" cards are composed in the browser (MediaRecorder) and can
        // be WebM/VP9 — a container AVPlayer can't decode. Catch that by extension
        // up front so the user gets a clear message immediately, offline, instead of
        // a black frame that never plays.
        if video.isLikelyUnsupportedFormat {
            fail("This reel isn’t in a format iOS can play yet."); return
        }
        guard let url = await service.playbackURL(for: video) else {
            fail("This reel has no video to play."); return
        }

        // Probe playability before wiring the player: any other undecodable asset
        // (a format the extension check didn't cover) still surfaces an error rather
        // than freezing on black.
        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard !failed else { return }   // a teardown/cancel raced the probe
        guard playable else {
            fail("This reel isn’t in a format iOS can play yet."); return
        }

        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        p.isMuted = muted
        p.actionAtItemEnd = .none
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        // Surface a mid-stream decode/network failure instead of freezing on a black
        // frame — the item can start loading fine and only then fail.
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            fail(err?.localizedDescription ?? "Couldn't load this video")
        }
        player = p
        if isActive { paused = false; p.play() }
    }

    private func fail(_ message: String) {
        failureMessage = message
        failed = true
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
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        loopObserver = nil
        failObserver = nil
        player = nil
    }
}

// Renders an AVPlayer through an AVPlayerLayer — a plain layer-backed UIView with
// no AVPlayerViewController, so nothing in the UIKit presentation stack can be
// orphaned when the enclosing fullScreenCover dismisses.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player { uiView.playerLayer.player = player }
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
