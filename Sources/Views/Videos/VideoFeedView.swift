import SwiftUI
import AVKit

// The Videos tab: reels released to the signed-in user from manage.everbot.org
// (commander_videos docs whose `assigned_emails` contains the user's email).
struct VideoFeedView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var service = VideoService()
    @State private var playing: AssignedVideo?

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = service.errorMessage {
                    emptyState(icon: "exclamationmark.triangle",
                               title: "Couldn't load videos", subtitle: msg)
                } else if service.videos.isEmpty {
                    emptyState(icon: "film.stack", title: "No videos yet",
                               subtitle: "Reels released to you from the gym will appear here.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(service.videos) { video in
                                VideoCard(video: video) { playing = video }
                            }
                        }
                        .padding(16)
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
        .sheet(item: $playing) { video in
            VideoPlayerSheet(video: video, service: service)
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(DS.Colors.secondary)
            Text(title).font(.headline).foregroundColor(DS.Colors.text)
            Text(subtitle).font(.subheadline).foregroundColor(DS.Colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("videos-empty")
    }
}

// One reel card: thumbnail + play glyph + title/date.
private struct VideoCard: View {
    let video: AssignedVideo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Rectangle().fill(Color.black)
                    if let thumb = video.thumbnailURL {
                        AsyncImage(url: thumb) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "play.circle")
                                .font(.system(size: 34)).foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44)).foregroundColor(.white.opacity(0.9))
                    if let d = video.durationLabel {
                        VStack { Spacer(); HStack { Spacer()
                            Text(d)
                                .font(.caption2.weight(.semibold)).foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.black.opacity(0.6)).clipShape(Capsule())
                                .padding(8)
                        } }
                    }
                }
                .frame(height: 200).clipped()

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.subheadline.weight(.semibold)).foregroundColor(DS.Colors.text)
                        .lineLimit(1)
                    if let created = video.createdAt {
                        Text(created, style: .date)
                            .font(.caption).foregroundColor(DS.Colors.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("video-card")
    }
}

// Inline player sheet. Resolves the playback URL (direct or Storage-backed),
// then hands it to AVKit — the same VideoPlayer used by chat video messages.
private struct VideoPlayerSheet: View {
    let video: AssignedVideo
    let service: VideoService
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let url {
                    VideoPlayer(player: AVPlayer(url: url))
                        .ignoresSafeArea(edges: .bottom)
                        .accessibilityIdentifier("video-player")
                } else if failed {
                    Text("Couldn't load this video.").foregroundColor(DS.Colors.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Colors.background)
            .navigationTitle(video.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task {
                if let resolved = await service.playbackURL(for: video) { url = resolved }
                else { failed = true }
            }
        }
    }
}
