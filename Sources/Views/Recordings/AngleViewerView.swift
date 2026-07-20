import SwiftUI
import AVKit
import Combine

// Opened by tapping an angle thumbnail on the Released tab: the recording plays
// large, with a "Save to Photos" action that downloads it to the phone.
//
// Presented as a .sheet rather than .fullScreenCover deliberately — a modal
// fullScreenCover in this app has refused to re-present after one open/close on
// iPad, leaving the grid behind it dead to taps (see VideosView).
struct AngleViewerView: View {
    let angle: ReleasedRecording.Angle
    let className: String
    let subtitle: String?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var save: SaveState = .idle
    // Playback (not the Save path) failed — a container iOS can't decode, an
    // expired/denied Storage token, or a mid-stream error. Without this the
    // viewer would just show a black VideoPlayer forever, which is the exact
    // #1063 "click a video and nothing ever comes up" bug re-introduced in the
    // full-screen surface. So the same guard #1063 ran inline runs here too.
    @State private var playbackFailed = false
    @State private var playbackMessage = "This angle can't be played on iOS."
    @State private var failObserver: NSObjectProtocol?
    @State private var statusObserver: AnyCancellable?

    enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md).fill(Color.black)
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .accessibilityIdentifier("angle-player")
                    } else if playbackFailed {
                        // Words, not a black frame. The full text rides on the
                        // combined accessibility element for UITests + VoiceOver.
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                            Text(playbackMessage)
                                .font(DS.Typography.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(DS.Spacing.md)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("angle-viewer-failed")
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                // The surface the bug was actually about: tapping a Released
                // thumbnail played the class recording full-size with no Palmr
                // branding at all (#1067 only reached the tiles and the export).
                // Only when a player exists — the "can't play" message is not
                // video. Applied to the ZStack, so the mark lands inside the
                // player's rounded frame rather than out in the sheet's padding.
                .modifier(ViewerWatermark(show: player != nil))

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(angle.displayName)
                        .font(DS.Typography.subheading)
                        .foregroundStyle(DS.Colors.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                saveButton

                if case .failed(let message) = save {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("angle-download-error")
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle(className)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("angle-viewer-done")
                }
            }
        }
        .tint(DS.Colors.accent)
        .accessibilityIdentifier("angle-viewer")
        .onAppear(perform: start)
        .onDisappear(perform: teardown)
    }

    @ViewBuilder
    private var saveButton: some View {
        Button(action: download) {
            HStack(spacing: DS.Spacing.sm) {
                switch save {
                case .saving:
                    ProgressView().tint(.white)
                    Text("Saving to Photos…")
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved to Photos")
                default:
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Save to Photos")
                }
            }
            .font(DS.Typography.subheading)
            .foregroundStyle(.white)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(save == .saved ? DS.Colors.green : DS.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .disabled(save == .saving || save == .saved || angle.downloadURL == nil)
        .opacity(angle.downloadURL == nil ? 0.5 : 1)
        .accessibilityIdentifier("angle-download")
    }

    // The #1063 playability guard, ported to the full-screen viewer. A released
    // angle can be undecodable (the browser-side release pipeline can emit
    // WebM/VP9, which iOS has no decoder for) or its tokenized Storage URL can be
    // expired/403 — an AVPlayer pointed at either just renders black forever with
    // no feedback. So: reject a known-bad container by extension first (instant,
    // offline), then probe `isPlayable`, then watch for a mid-stream failure.
    // Every path ends in either a playing video or a message, never a silent
    // black player. Reuses VideoDownload's shared container set (do not duplicate).
    private func start() {
        guard player == nil, !playbackFailed, let url = angle.downloadURL else { return }

        // Catch a container iOS can't decode by extension first — the same set
        // the Save-to-Photos path uses.
        if VideoDownload.incompatibleContainers.contains(VideoDownload.fileExtension(for: url)) {
            fail("This angle's format (\(VideoDownload.fileExtension(for: url))) can't be played on iOS. Ask for an MP4 release of this class.")
            return
        }

        // Play with the ringer silenced, as the video feed does.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Probe before wiring the player so anything else undecodable — or an
        // expired/denied Storage token — surfaces a message instead of black.
        Task { @MainActor in
            let asset = AVURLAsset(url: url)
            let playable = (try? await asset.load(.isPlayable)) ?? false
            guard player == nil, !playbackFailed else { return }   // raced by teardown
            guard playable else {
                fail("This angle couldn't be loaded. Ask for an MP4 release of this class.")
                return
            }

            let item = AVPlayerItem(asset: asset)
            // An item can start loading fine and only then fail mid-stream; catch
            // both the "failed to play to end" notification and a .failed status.
            failObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
            ) { _ in
                teardown()
                fail("Playback of this angle stopped unexpectedly.")
            }
            statusObserver = item.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .sink { status in
                    if status == .failed {
                        teardown()
                        fail("This angle couldn't be played. Ask for an MP4 release of this class.")
                    }
                }

            let p = AVPlayer(playerItem: item)
            player = p
            p.play()
        }
    }

    private func fail(_ message: String) {
        playbackMessage = message
        playbackFailed = true
    }

    private func teardown() {
        player?.pause()
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        failObserver = nil
        statusObserver?.cancel()
        statusObserver = nil
        player = nil

        // Hand the audio session back. `start()` activates a .playback session to
        // silence the ringer, and leaving it active after the sheet closes keeps
        // whatever the user had playing (music, a podcast) ducked or stopped, and
        // slows the next app launch while the session is reclaimed. Off the main
        // thread — deactivation blocks until the route tears down.
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func download() {
        guard let url = angle.downloadURL, save != .saving else { return }
        save = .saving
        Task { @MainActor in
            do {
                try await VideoDownload.saveToPhotos(from: url, className: className, camera: angle.camera)
                save = .saved
            } catch {
                save = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }
}

// Brands the viewer only once the angle is actually playing — the "can't play"
// message and the black placeholder are not video. A modifier rather than an
// `if` around the ZStack so both branches keep the same view identity. (#1072)
private struct ViewerWatermark: ViewModifier {
    let show: Bool

    func body(content: Content) -> some View {
        if show {
            content.palmrWatermark()
        } else {
            content
        }
    }
}
