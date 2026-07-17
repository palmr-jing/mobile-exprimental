import SwiftUI
import UIKit

// The Videos tab: reels + recordings released to the signed-in user from
// manage.everbot.org (commander_videos, scoped by email). A Reels/Recordings/All
// filter over a thumbnail grid; tapping a clip opens the full-screen paging feed.
struct VideosView: View {
    @EnvironmentObject private var auth: AuthService
    // The full-screen feed is presented at the app root (above the TabView) so it
    // covers everything, without a modal fullScreenCover (which got stuck on iPad).
    @EnvironmentObject private var feed: VideoFeedPresenter
    @StateObject private var service = VideoService()
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", reels = "Reels", recordings = "Recordings"
        var id: String { rawValue }
        var kind: VideoKind? { self == .reels ? .reel : self == .recordings ? .recording : nil }
    }

    private var source: [AssignedVideo] { TestConfig.isMockVideos ? Self.mock : service.videos }
    private var isLoading: Bool { TestConfig.isMockVideos ? false : service.isLoading }
    private var shown: [AssignedVideo] { AssignedVideo.filter(source, kind: filter.kind) }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(12)

                Group {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let msg = service.errorMessage, !TestConfig.isMockVideos {
                        empty("exclamationmark.triangle", "Couldn't load videos", msg)
                    } else if shown.isEmpty {
                        empty("film.stack", "No videos yet", "Reels released to you from the gym will appear here.")
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(shown) { v in
                                    Thumb(video: v) {
                                        feed.present(AssignedVideo.rotated(shown, first: v), service: service)
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Colors.background)
            .navigationTitle("Videos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ReportIssueButton(tab: "Videos") }
            }
        }
        .tint(DS.Colors.accent)
        .task(id: auth.currentUser?.email) {
            if !TestConfig.isMockVideos, let email = auth.currentUser?.email { service.start(email: email) }
        }
    }

    // Deterministic fixtures for the UITest/screenshot seam (inert in production).
    static let mock: [AssignedVideo] = {
        let titles = ["Muay Thai Kickboxing", "Brazilian Jiu Jitsu", "IMA MMA Class",
                      "Sparring Night", "Open Mat Rolls", "Fighter Reel", "Warmup Drills"]
        let durs = [1839, 181, 300, 95, 600, 240, 60]
        // A deliberately LANDSCAPE bundled thumbnail (320×180, wider than the
        // portrait cell) so the grid-overlap UITest keeps reproducing the iPad bug
        // where scaledToFill overflowed the cell and inflated its tap frame. A
        // bundled file loads offline in tests; real reels' thumbnails are landscape.
        let landscape = Bundle.main.url(forResource: "test-landscape", withExtension: "png")
        let hosted = titles.indices.map { i in
            AssignedVideo(id: "m\(i)", kind: i % 3 == 2 ? .recording : .reel, title: titles[i],
                          videoURL: URL(string: "https://example.com/\(i).mp4"), storagePath: nil,
                          thumbnailURL: landscape, durationSeconds: durs[i], project: "mobile commander",
                          sourceURL: nil, createdAt: Date(timeIntervalSince1970: Double(10_000 - i)))
        }
        // A browser-composed reel released as WebM (task #1049): Chrome's
        // MediaRecorder can't encode H.264, so the "Reel · N clips" upload is
        // WebM/VP9 — a container iOS can't decode. Opening it must show a clear
        // message, not a black frame that never plays. Newest so it leads the grid,
        // matching the reported screenshot.
        let webmReel = AssignedVideo(
            id: "webm", kind: .reel, title: "Reel · 30 clips",
            videoURL: URL(string: "https://firebasestorage.googleapis.com/v0/b/app/o/wallcam%2Freels%2Freel-30.webm?alt=media&token=t"),
            storagePath: "wallcam/reels/reel-30.webm", thumbnailURL: landscape,
            durationSeconds: 90, project: "mobile commander", sourceURL: nil,
            createdAt: Date(timeIntervalSince1970: 10_100))
        return [webmReel] + hosted
    }()

    private func empty(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(DS.Colors.secondary)
            Text(title).font(.headline).foregroundColor(DS.Colors.text)
            Text(subtitle).font(.subheadline).foregroundColor(DS.Colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("videos-empty")
    }
}

// One grid cell: portrait thumbnail + play glyph + duration + title. The
// thumbnail uses a clear aspect-ratio spacer with an overlay so every cell has a
// determinate height — without it, an image-fill reports no size and cells
// overlap in the LazyVGrid.
private struct Thumb: View {
    let video: AssignedVideo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Color.black
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .overlay {
                        // A landscape thumbnail scaled to fill is far WIDER than the
                        // portrait cell. `.clipShape` only masks it visually — the
                        // image still defines the cell's layout + hit frame, so cells
                        // ballooned to ~600pt and overlapped on iPad (a tap on one
                        // reel landed on the neighbour buried under it). `.clipped()`
                        // below clips layout AND hit-testing to the cell.
                        if let t = video.thumbnailURL {
                            // AsyncImage can't render file:// URLs; load those (the
                            // test/mock fixtures) synchronously via UIImage.
                            if t.isFileURL, let ui = UIImage(contentsOfFile: t.path) {
                                Image(uiImage: ui).resizable().scaledToFill()
                            } else {
                                AsyncImage(url: t) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { Color.black }
                            }
                        }
                    }
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34)).foregroundColor(.white.opacity(0.9))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let d = video.durationLabel {
                            Text(d).font(.caption2.weight(.semibold)).foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.black.opacity(0.6), in: Capsule()).padding(6)
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(video.title).font(.footnote.weight(.medium))
                    .foregroundColor(DS.Colors.text).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("video-card")
    }
}

// Drives the full-screen video feed from the app root, above the TabView, so it
// covers the whole screen WITHOUT a modal fullScreenCover — which on iPad could
// refuse to re-present after one open+close, leaving grid taps dead. Presenting
// is a plain state change: nothing can get stuck.
@MainActor
final class VideoFeedPresenter: ObservableObject {
    @Published private(set) var videos: [AssignedVideo] = []
    @Published private(set) var service: VideoService?

    var isPresenting: Bool { service != nil && !videos.isEmpty }

    func present(_ videos: [AssignedVideo], service: VideoService) {
        guard !videos.isEmpty else { return }
        withAnimation(.snappy(duration: 0.28)) {
            self.videos = videos
            self.service = service
        }
    }

    func dismiss() {
        withAnimation(.snappy(duration: 0.28)) {
            videos = []
            service = nil
        }
    }
}
