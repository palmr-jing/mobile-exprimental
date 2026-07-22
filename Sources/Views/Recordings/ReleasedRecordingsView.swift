import SwiftUI

// The Released tab: class recordings released to the app from
// manage.everbot.org's Recordings tab (the `released_recordings` collection).
// One card per released class, newest-first, with its grouped camera angles
// (Left / Right / Center) as thumbnails. Tapping one opens it
// full-size in AngleViewerView, where it plays large and can be saved to the
// phone's Photos library.
struct ReleasedRecordingsView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var service = ReleasedRecordingsService()
    // The viewer is presented from ONE place at the top of the screen rather
    // than from each thumbnail: a .sheet attached to a row inside the LazyVStack
    // silently never presents, because the row it's attached to is created lazily.
    @State private var opened: OpenAngle?
    // Whether the injected `-MOCK_RELEASED_ERROR` failure has been retried away.
    // Inert in production.
    @State private var mockRetried = false

    private var source: [ReleasedRecording] { TestConfig.isMockReleased ? Self.mock : service.recordings }
    private var isLoading: Bool { TestConfig.isMockReleased ? false : service.isLoading }

    // The error to show, if any. The mock seam short-circuits the live service so
    // the failure state is reachable without Firebase.
    private var errorText: String? {
        if TestConfig.isMockReleasedError {
            return mockRetried ? nil : ReleasedRecordingsService.permissionDeniedMessage
        }
        return TestConfig.isMockReleased ? nil : service.errorMessage
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = errorText {
                    // A failed load MUST offer a way out: Firestore kills the
                    // listener on error, so without this the tab stayed dead
                    // until the app was force-quit (#1068/#1070).
                    empty("exclamationmark.triangle", "Couldn't load recordings", msg,
                          actionLabel: "Try again", action: retry)
                } else if source.isEmpty {
                    empty("video.slash", "No released recordings",
                          "Class recordings released from manage.everbot.org will appear here.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.lg) {
                            ForEach(source) { rec in
                                RecordingCard(recording: rec) { angle in
                                    opened = OpenAngle(angle: angle, className: rec.className,
                                                       subtitle: rec.startsAtLabel)
                                }
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
        .sheet(item: $opened) { target in
            AngleViewerView(angle: target.angle, className: target.className,
                            subtitle: target.subtitle)
        }
        // The collection is readable only to a signed-in user, so the subscription
        // is keyed on the uid: this re-runs when the identity changes AND when the
        // tab is revisited, and the service re-attaches if the previous listener
        // died — which is what makes a transient permission-denied recoverable.
        // On sign-out (uid nil) the listener is torn down rather than left to fail
        // against the next session.
        .task(id: auth.currentUser?.uid) {
            guard !TestConfig.isMockReleased else { return }
            if let uid = auth.currentUser?.uid {
                service.start(uid: uid)
            } else {
                service.stop()
            }
        }
    }

    private func retry() {
        if TestConfig.isMockReleasedError {
            mockRetried = true
            return
        }
        service.retry(uid: auth.currentUser?.uid)
    }

    // The angle the viewer sheet is showing. Identified by class + camera, which
    // is unique across the list (one doc per class, one entry per camera).
    struct OpenAngle: Identifiable {
        let angle: ReleasedRecording.Angle
        let className: String
        let subtitle: String?
        var id: String { "\(className)-\(angle.camera)" }
    }

    @ViewBuilder
    private func empty(_ icon: String, _ title: String, _ subtitle: String,
                       actionLabel: String? = nil,
                       action: (() -> Void)? = nil) -> some View {
        let state = EmptyStateView(icon: icon, title: title, subtitle: subtitle,
                                   actionLabel: actionLabel, action: action)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Identify the container ONLY when it holds no button. A container-level
        // identifier propagates down and clobbers the child button's own
        // identifier, making it unfindable in UITests (the same trap documented
        // on RecordingCard) — and an empty-string identifier still creates the
        // flattening container, so the modifier has to be omitted outright. The
        // actionable variant is addressed via the button's "empty-state-action" id.
        if action == nil {
            state.accessibilityIdentifier("released-empty")
        } else {
            state
        }
    }

    // Deterministic fixtures for the -MOCK_RELEASED screenshot seam (inert in
    // production). The remote gtv-videos-bucket sample URLs answer 403, so the
    // FIRST angle instead points at a 17KB clip bundled with the app
    // (Resources/test-sample-clip.mp4). That gives the offline UITests a tile
    // that genuinely plays, which is what makes the full-screen viewer's
    // playback surface — and the watermark on it (#1072/#1075) — assertable on a
    // simulator with no network. The remaining angles keep the remote URLs so
    // the "couldn't load" guard still has something to fire on.
    static let mock: [ReleasedRecording] = {
        let sample = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample"
        // A bundled LANDSCAPE poster (320×180) stands in for the watcher-written
        // thumbnail_url, so the UITests exercise the real poster path offline —
        // including the scaledToFill/clipped geometry that a wide poster in a
        // 16:9 tile would otherwise use to overlap its neighbours on iPad.
        let poster = Bundle.main.url(forResource: "test-landscape", withExtension: "png")
        func angle(_ camera: String, _ file: String) -> ReleasedRecording.Angle {
            .init(camera: camera, storagePath: "recordings/\(file)",
                  downloadURL: URL(string: "\(sample)/\(file)"),
                  thumbnailURL: poster)
        }
        // Bundled, so it plays with no network. Falls back to the remote URL if
        // the resource is somehow missing rather than yielding a nil-URL tile.
        func playableAngle(_ camera: String) -> ReleasedRecording.Angle {
            guard let local = Bundle.main.url(forResource: "test-sample-clip", withExtension: "mp4") else {
                return angle(camera, "BigBuckBunny.mp4")
            }
            return .init(camera: camera, storagePath: "recordings/test-sample-clip.mp4",
                         downloadURL: local, thumbnailURL: poster)
        }
        return [
            ReleasedRecording(
                id: "plan_1", groupKey: "g1", className: "IMA Fit + Tiny Tigers",
                device: "everbot-lubancat-2", room: nil,
                startsAt: Date(timeIntervalSince1970: 1_783_680_000),   // 2026-07-10
                releasedAt: Date(timeIntervalSince1970: 1_783_686_000),
                releasedBy: "jing@everbot.org", angleCount: 3,
                videos: [playableAngle("front"),
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
            // A class released as WebM. iOS can neither play nor save that
            // container (task #1049), so the full-screen viewer must show a clear
            // "can't play" message instead of a black frame (the ported #1063
            // guard), and "Save to Photos" must say so up front instead of
            // downloading the whole file and failing at the end. The second angle
            // has no URL at all, so its tile renders "unavailable" rather than an
            // inert black rectangle. Last in the list so it doesn't shift the
            // other cards' geometry.
            ReleasedRecording(
                id: "plan_3", groupKey: "g3", className: "Kids BJJ (WebM release)",
                device: "everbot-lubancat-3", room: nil,
                startsAt: Date(timeIntervalSince1970: 1_783_500_000),
                releasedAt: Date(timeIntervalSince1970: 1_783_501_000),
                releasedBy: "jing@everbot.org", angleCount: 2,
                videos: [.init(camera: "front", storagePath: "recordings/kids-bjj.webm",
                               downloadURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/app/o/recordings%2Fkids-bjj.webm?alt=media&token=t")),
                         .init(camera: "realsense", storagePath: nil, downloadURL: nil)]),
        ]
    }()
}

// One released class: title + date + device/room, with its grouped camera angles
// below as thumbnails that open the viewer. The 3 angles stay together under
// this single card (they're already one doc).
private struct RecordingCard: View {
    let recording: ReleasedRecording
    let onOpenAngle: (ReleasedRecording.Angle) -> Void
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
                            AngleThumbnail(angle: angle) { onOpenAngle(angle) }
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

// A single camera angle: a labeled 16:9 poster tile. Tapping ANYWHERE on the
// tile opens the angle full-size in AngleViewerView, where it plays large and
// can be saved to the phone's Photos library — rather than playing inline in a
// ~110pt-wide box, which is too small to watch and offers nowhere to put a
// download action. A nil/invalid URL renders a disabled "unavailable" tile.
private struct AngleThumbnail: View {
    let angle: ReleasedRecording.Angle
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(angle.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.Colors.secondary)
                .lineLimit(1)

            // Brand the tile whenever it holds real footage — poster, or playing.
            // Logo AND wordmark, as manage stamps its reels: these tiles are a
            // third of the card wide, so the mark sits at its 56pt legibility
            // floor rather than the 14%-of-width manage uses on a full frame
            // (#1072; #1067 shipped mark-only here, which read as unbranded).
            // Applied OUTSIDE the tap Button so the mark surfaces as its own
            // accessibility element (a watermark buried inside a Button's label
            // is flattened into the button).
            tile
                .modifier(TileWatermark(show: angle.downloadURL != nil))
        }
    }

    // A real Button (not a tap gesture) so XCUITest sees `app.buttons[...]`,
    // matching the Videos grid's thumbnail cells.
    @ViewBuilder
    private var tile: some View {
        if angle.downloadURL == nil {
            poster
                .accessibilityIdentifier("angle-unavailable")
        } else {
            Button(action: onTap) { poster }
                .buttonStyle(.plain)
                // The whole tile is the tap target, not just the 26pt glyph.
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityIdentifier("angle-play")
        }
    }

    private var poster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.sm).fill(Color.black)

            // Poster behind the play glyph, written per angle by the
            // recording-posters watcher (#1071). PosterImage — not AsyncImage —
            // so a tile recycled by the LazyVStack repaints its poster from
            // cache in the first frame instead of flashing black and
            // re-downloading, which is what makes the grid feel instant the way
            // manage's /recordings does. scaledToFill is clipped below so it
            // can't inflate the tile's frame and overlap its neighbours.
            if let t = angle.thumbnailURL {
                PosterImage(url: t)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            if angle.downloadURL == nil {
                Image(systemName: "video.slash")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 3)
            }
        }
        // .clipped() constrains layout AND hit-testing to the tile, so a
        // scaledToFill poster can't inflate the frame and swallow taps meant
        // for the neighbouring angle (the iPad bug fixed in the Videos grid).
        .clipped()
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }
}

// Applies the watermark only to tiles that actually hold footage — an
// "unavailable" tile has nothing to brand. A modifier rather than an `if` around
// the tile so both branches keep the same view identity. (#1067)
private struct TileWatermark: ViewModifier {
    let show: Bool

    func body(content: Content) -> some View {
        if show {
            content.palmrWatermark()
        } else {
            content
        }
    }
}
