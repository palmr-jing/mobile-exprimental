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
// and a list of many cards — doesn't spin up dozens of players up front. A
// nil/invalid URL renders a disabled "unavailable" tile instead of crashing.
private struct AnglePlayer: View {
    let angle: ReleasedRecording.Angle
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(angle.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.Colors.secondary)
                .lineLimit(1)

            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.black)

                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .accessibilityIdentifier("angle-player")
                } else if angle.downloadURL == nil {
                    Image(systemName: "video.slash")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Button(action: play) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("angle-play")
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
    }

    private func play() {
        guard let url = angle.downloadURL else { return }
        let p = AVPlayer(url: url)
        player = p
        p.play()
    }
}
