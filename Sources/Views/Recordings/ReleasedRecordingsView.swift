import SwiftUI
import AVKit

// The Released tab: class recordings released to the app from
// manage.everbot.org's Recordings tab (the `released_recordings` collection).
// One card per released class, newest-first, with its grouped camera angles
// (Front / Front-right / RealSense) playable inline.
struct ReleasedRecordingsView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var service = ReleasedRecordingsService()

    private var source: [ReleasedRecording] { TestConfig.isMockReleased ? Self.mock : service.recordings }
    private var isLoading: Bool { TestConfig.isMockReleased ? false : service.isLoading }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = service.errorMessage, !TestConfig.isMockReleased {
                    empty("exclamationmark.triangle", "Couldn't load recordings", msg)
                } else if source.isEmpty {
                    empty("video.slash", "No released recordings",
                          "Class recordings released from manage.everbot.org will appear here.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.lg) {
                            ForEach(source) { rec in
                                RecordingCard(recording: rec)
                            }
                        }
                        .padding(DS.Spacing.lg)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Released")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ReportIssueButton(tab: "Released") }
            }
        }
        .tint(DS.Colors.accent)
        // The collection is readable only to a signed-in user; start once we have
        // an authenticated session (re-runs if the user changes).
        .task(id: auth.currentUser?.uid) {
            if !TestConfig.isMockReleased, auth.currentUser != nil { service.start() }
        }
    }

    private func empty(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        EmptyStateView(icon: icon, title: title, subtitle: subtitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("released-empty")
    }

    // Deterministic fixtures for the -MOCK_RELEASED screenshot seam (inert in
    // production). Uses public sample MP4s so the inline players actually play.
    static let mock: [ReleasedRecording] = {
        let sample = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample"
        func angle(_ camera: String, _ file: String) -> ReleasedRecording.Angle {
            .init(camera: camera, storagePath: "recordings/\(file)",
                  downloadURL: URL(string: "\(sample)/\(file)"))
        }
        return [
            ReleasedRecording(
                id: "plan_1", groupKey: "g1", className: "IMA Fit + Tiny Tigers",
                device: "everbot-lubancat-2", room: nil,
                startsAt: Date(timeIntervalSince1970: 1_783_680_000),   // 2026-07-10
                releasedAt: Date(timeIntervalSince1970: 1_783_686_000),
                releasedBy: "jing@everbot.org", angleCount: 3,
                videos: [angle("front", "BigBuckBunny.mp4"),
                         angle("front-right", "ElephantsDream.mp4"),
                         angle("realsense", "ForBiggerBlazes.mp4")]),
            ReleasedRecording(
                id: "plan_2", groupKey: "g2", className: "Muay Thai Kickboxing",
                device: "everbot-lubancat-1", room: "Studio A",
                startsAt: Date(timeIntervalSince1970: 1_783_593_600),
                releasedAt: Date(timeIntervalSince1970: 1_783_596_000),
                releasedBy: "jing@everbot.org", angleCount: 3,
                videos: [angle("front", "ForBiggerEscapes.mp4"),
                         angle("front-right", "ForBiggerFun.mp4"),
                         angle("realsense", "ForBiggerJoyrides.mp4")]),
            // Reproduces the "tap play, nothing ever comes up" report offline: a
            // WebM angle iOS can't decode, plus an angle the release wrote with no
            // URL at all. Kept LAST so the one-row geometry assertions in
            // ReleasedUITests still read the first card's three angles.
            ReleasedRecording(
                id: "plan_3", groupKey: "g3", className: "Unsupported Format Class",
                device: "everbot-lubancat-1", room: nil,
                startsAt: Date(timeIntervalSince1970: 1_783_500_000),
                releasedAt: Date(timeIntervalSince1970: 1_783_501_000),
                releasedBy: "jing@everbot.org", angleCount: 2,
                videos: [
                    .init(camera: "front", storagePath: "recordings/front.webm",
                          downloadURL: URL(string: "\(sample)/front.webm")),
                    .init(camera: "realsense", storagePath: nil, downloadURL: nil),
                ]),
        ]
    }()
}

// One released class: title + date + device/room, with its grouped camera angles
// stacked below as tap-to-play inline players. The 3 angles stay together under
// this single card (they're already one doc).
private struct RecordingCard: View {
    let recording: ReleasedRecording
    @EnvironmentObject private var chatService: ChatService
    @State private var sharing = false

    var body: some View {
        CommanderCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recording.className)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.text)
                        .accessibilityIdentifier("recording-title")
                    Spacer()
                    Button { sharing = true } label: {
                        Label("Send to chat", systemImage: "paperplane.fill")
                            .labelStyle(.iconOnly)
                            .font(.subheadline)
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .accessibilityIdentifier("recording-share")
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if let when = recording.startsAtLabel {
                        Label(when, systemImage: "calendar")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    if let device = recording.deviceLabel {
                        Label(device, systemImage: "video")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }

                if recording.videos.isEmpty {
                    Text("No camera angles in this release.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                } else {
                    // All angles in a single row — three compact tiles side by side.
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        ForEach(recording.videos) { angle in
                            AnglePlayer(angle: angle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // NOTE: no .accessibilityIdentifier here — a container-level identifier
        // propagates down and clobbers the child buttons' own identifiers
        // (recording-share / angle-play), making them untappable in UITests.
        .sheet(isPresented: $sharing) {
            ShareToChatSheet(
                title: recording.className,
                subtitle: "\(recording.videos.count) camera angles",
                icon: "video.badge.checkmark",
                chatService: chatService,
                send: { channelId, caption, mentionEmma in
                    await chatService.sendRecording(recording, toChannel: channelId,
                                                    caption: caption, mentionEmma: mentionEmma)
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
}

// A single camera angle: a labeled 16:9 tile that plays inline on tap. The
// AVPlayer is created lazily (only when tapped), so a card with three angles —
// and a list of many cards — doesn't spin up dozens of players up front.
//
// Tapping play does NOT hand the URL straight to AVPlayer. A released angle can
// be undecodable (the browser-side release pipeline can emit WebM/VP9, which iOS
// has no decoder for) or its tokenized Storage URL can be expired/403, and an
// AVPlayer pointed at either just renders black forever with no feedback — the
// "click on videos and they don't load or come up" report. So the tap runs the
// same sequence the reel player got in #1049: reject known-bad containers by
// extension, probe `isPlayable`, then watch for a mid-stream failure. Every
// path ends in either a playing video or a message, never a silent black tile.
private struct AnglePlayer: View {
    let angle: ReleasedRecording.Angle
    @State private var player: AVPlayer?
    @State private var failObserver: NSObjectProtocol?
    @State private var failed = false
    @State private var failureMessage = "Couldn't load this angle"
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(angle.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.Colors.secondary)
                .lineLimit(1)

            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.black)

                // Poster behind the play glyph (nil until the release pipeline
                // writes thumbnail_url). scaledToFill is clipped below so it can't
                // inflate the tile's frame and overlap its neighbours in the row.
                if player == nil, let t = angle.thumbnailURL {
                    AsyncImage(url: t) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.black }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }

                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .accessibilityIdentifier("angle-player")
                } else if failed {
                    // The tile is small, so the message is terse and the full text
                    // rides on the accessibility label for UITests + VoiceOver.
                    // Tap to retry: "couldn't load" can be a transient network blip,
                    // and without this the tile stays stuck on the error. A genuine
                    // format failure just re-fails instantly with the same message.
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                        Text(failureMessage)
                            .font(.system(size: 9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { failed = false; Task { await load() } }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("angle-failed")
                } else if loading {
                    ProgressView().tint(.white).accessibilityIdentifier("angle-loading")
                } else if angle.downloadURL == nil {
                    // No source at all — say so in words. A bare glyph on a black
                    // tile reads as "the app is broken" rather than "this angle
                    // wasn't released".
                    VStack(spacing: 2) {
                        Image(systemName: "video.slash").font(.caption)
                        Text("Not available").font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("angle-unavailable")
                } else {
                    Button { Task { await load() } } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("angle-play")
                }
            }
            .clipped()
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
        .onDisappear(perform: teardown)
    }

    @MainActor
    private func load() async {
        guard player == nil, !loading else { return }
        guard let url = angle.downloadURL else {
            fail("Not available"); return
        }

        // Catch a container iOS can't decode by extension first: it's instant and
        // works offline, so the user gets the real reason immediately.
        if angle.isLikelyUnsupportedFormat {
            fail("Format not supported on iOS"); return
        }

        loading = true
        // Probe before wiring the player so anything else undecodable — or an
        // expired/denied Storage token — surfaces a message instead of black.
        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard loading else { return }   // a teardown raced the probe
        loading = false
        guard playable else {
            fail("Couldn't load this angle"); return
        }

        let item = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: item)
        // An item can start loading fine and only then fail mid-stream; without
        // this the tile would freeze on a black frame with no explanation.
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { _ in
            teardown()
            fail("Couldn't load this angle")
        }
        player = p
        p.play()
    }

    private func fail(_ message: String) {
        failureMessage = message
        failed = true
        loading = false
    }

    private func teardown() {
        player?.pause()
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        failObserver = nil
        player = nil
        loading = false
    }
}
