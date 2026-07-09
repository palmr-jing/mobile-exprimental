import SwiftUI

// The Videos tab: reels + recordings released to the signed-in user from
// manage.everbot.org (commander_videos, scoped by email). A Reels/Recordings/All
// filter over a thumbnail grid; tapping a clip opens the full-screen paging feed.
struct VideosView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var service = VideoService()
    @State private var filter: Filter = .all
    @State private var feedStart: AssignedVideo?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", reels = "Reels", recordings = "Recordings"
        var id: String { rawValue }
        var kind: VideoKind? { self == .reels ? .reel : self == .recordings ? .recording : nil }
    }

    private var shown: [AssignedVideo] { AssignedVideo.filter(service.videos, kind: filter.kind) }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(12)

                Group {
                    if service.isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let msg = service.errorMessage {
                        empty("exclamationmark.triangle", "Couldn't load videos", msg)
                    } else if shown.isEmpty {
                        empty("film.stack", "No videos yet", "Reels released to you from the gym will appear here.")
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(shown) { v in Thumb(video: v) { feedStart = v } }
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Colors.background)
            .navigationTitle("Videos")
        }
        .tint(DS.Colors.accent)
        .task(id: auth.currentUser?.email) {
            if let email = auth.currentUser?.email { service.start(email: email) }
        }
        .fullScreenCover(item: $feedStart) { start in
            VideoFeedView(videos: shown, service: service, startAt: start)
        }
    }

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
                Color.clear
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .overlay {
                        ZStack {
                            Color.black
                            if let t = video.thumbnailURL {
                                AsyncImage(url: t) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { Color.black }
                            }
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 34)).foregroundColor(.white.opacity(0.9))
                            if let d = video.durationLabel {
                                VStack { Spacer(); HStack { Spacer()
                                    Text(d).font(.caption2.weight(.semibold)).foregroundColor(.white)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(.black.opacity(0.6), in: Capsule()).padding(6)
                                } }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(video.title).font(.footnote.weight(.medium))
                    .foregroundColor(DS.Colors.text).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("video-card")
    }
}
