import SwiftUI
import UIKit
import AVFoundation
import AVKit
import Photos

// Reel editor. Phase 1: filmstrip trim (a continuous strip of frames with a
// draggable trim window). Phase 2: a tool bar — Trim · Text · Speed · Mute —
// with a draggable text overlay and playback speed, all burned into the export.
struct ReelEditorView: View {
    let video: AssignedVideo
    let service: VideoService
    @Environment(\.dismiss) private var dismiss

    enum Tool: String, CaseIterable, Identifiable {
        case trim = "Trim", text = "Text", speed = "Speed"
        var id: String { rawValue }
        var icon: String { self == .trim ? "timeline.selection" : self == .text ? "textformat" : "speedometer" }
    }

    @State private var player: AVPlayer?
    @State private var asset: AVURLAsset?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var playhead: Double = 0
    @State private var thumbnails: [UIImage] = []
    @State private var loadFailed = false

    @State private var tool: Tool = .trim
    @State private var overlayText: String = ""
    @State private var textPos = CGPoint(x: 0.5, y: 0.82)  // normalized, y from top
    @State private var speed: Double = 1.0
    @State private var muted = false

    @State private var exporting = false
    @State private var exported: ExportedFile?     // drives the optional Share sheet
    @State private var savedURL: URL?              // set when saved to Photos → confirm alert
    @State private var exportError: String?
    @State private var timeObserver: Any?

    struct ExportedFile: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                preview
                Spacer(minLength: 0)
                toolPanel
                toolBar
            }
        }
        .task { await load() }
        .onDisappear { if let t = timeObserver { player?.removeTimeObserver(t) } }
        .sheet(item: $exported) { ShareSheet(items: [$0.url]) }
        .alert("Saved to Photos", isPresented: Binding(get: { savedURL != nil }, set: { if !$0 { savedURL = nil } })) {
            Button("Done") { dismiss() }
            Button("Share") { if let u = savedURL { exported = ExportedFile(url: u) } }
        } message: { Text("Your edited reel is in Photos.") }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    // MARK: preview (video + draggable text overlay)

    private var preview: some View {
        GeometryReader { geo in
            ZStack {
                if let player {
                    VideoPlayer(player: player).allowsHitTesting(false)
                } else if loadFailed {
                    ContentUnavailableView("Couldn't load video", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.white)
                } else {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if !overlayText.isEmpty {
                    Text(overlayText)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                        .position(x: geo.size.width * textPos.x, y: geo.size.height * textPos.y)
                        .gesture(DragGesture().onChanged { g in
                            textPos = CGPoint(x: min(max(g.location.x / geo.size.width, 0.05), 0.95),
                                              y: min(max(g.location.y / geo.size.height, 0.05), 0.95))
                        })
                }
            }
        }
        .aspectRatio(9.0/16.0, contentMode: .fit)
    }

    // MARK: the tool-specific panel

    @ViewBuilder private var toolPanel: some View {
        switch tool {
        case .trim: if duration > 0 { trimmer }
        case .text: textPanel
        case .speed: speedPanel
        }
    }

    private var trimmer: some View {
        VStack(spacing: 8) {
            HStack {
                Text(fmt(start)).monospacedDigit()
                Spacer()
                Text("\(fmt(max(0, end - start))) selected").fontWeight(.semibold)
                Spacer()
                Text(fmt(end)).monospacedDigit()
            }
            .font(.caption).foregroundStyle(.white.opacity(0.85)).padding(.horizontal, 16)
            FilmstripTrimmer(thumbnails: thumbnails, duration: duration,
                             start: $start, end: $end, playhead: playhead, onScrub: { seek($0) })
            .frame(height: 56).padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }

    private var textPanel: some View {
        VStack(spacing: 8) {
            TextField("Add a caption", text: $overlayText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
            Text(overlayText.isEmpty ? "Type a caption, then drag it on the video." : "Drag the caption on the video to position it.")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.bottom, 10)
    }

    private var speedPanel: some View {
        VStack(spacing: 10) {
            Picker("Speed", selection: $speed) {
                Text("0.5×").tag(0.5); Text("1×").tag(1.0); Text("1.5×").tag(1.5); Text("2×").tag(2.0)
            }
            .pickerStyle(.segmented).padding(.horizontal, 16)
            .onChange(of: speed) { _, s in player?.rate = Float(s) }
            Text("Applied to preview and the exported clip.")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.bottom, 10)
    }

    // MARK: bars

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }.foregroundStyle(.white)
            Spacer()
            Text(video.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button { Task { await finish() } } label: {
                Text(exporting ? "Saving…" : "Save").fontWeight(.semibold)
            }
            .foregroundStyle(exporting || end - start < 0.5 ? .gray : .white)
            .disabled(exporting || end - start < 0.5)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var toolBar: some View {
        HStack {
            ForEach(Tool.allCases) { t in
                Button { tool = t } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.icon).font(.system(size: 20))
                        Text(t.rawValue).font(.caption2)
                    }
                    .foregroundStyle(tool == t ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("tool-\(t.rawValue.lowercased())")
            }
            Button { muted.toggle(); player?.isMuted = muted } label: {
                VStack(spacing: 4) {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.system(size: 20))
                    Text("Mute").font(.caption2)
                }
                .foregroundStyle(muted ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .background(.black)
    }

    // MARK: helpers

    private func fmt(_ s: Double) -> String {
        let t = Int(s.rounded()); return String(format: "%d:%02d", t / 60, t % 60)
    }
    private func seek(_ s: Double) {
        player?.seek(to: CMTime(seconds: s, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func load() async {
        guard let url = await service.playbackURL(for: video) else { loadFailed = true; return }
        let a = AVURLAsset(url: url)
        do {
            let d = try await a.load(.duration)
            asset = a
            duration = max(0, CMTimeGetSeconds(d))
            end = duration
            let p = AVPlayer(url: url)
            timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { t in
                let s = CMTimeGetSeconds(t)
                playhead = s
                if s >= end { p.seek(to: CMTime(seconds: start, preferredTimescale: 600)); p.rate = Float(speed) }
            }
            player = p
            await generateThumbnails(a, duration: duration)
        } catch { loadFailed = true }
    }

    private func generateThumbnails(_ asset: AVURLAsset, duration: Double) async {
        guard duration > 0 else { return }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .positiveInfinity
        gen.requestedTimeToleranceAfter = .positiveInfinity
        gen.maximumSize = CGSize(width: 120, height: 120)
        var imgs: [UIImage] = []
        for i in 0..<12 {
            let t = duration * (Double(i) + 0.5) / 12.0
            if let cg = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)).image {
                imgs.append(UIImage(cgImage: cg))
            }
        }
        thumbnails = imgs
    }

    // Trim / speed / mute / text → an exported .mp4 (via ReelExport), then save it
    // to the user's Photos with a clear result.
    private func finish() async {
        guard let url = await export() else { return }
        if let err = await saveToPhotos(url) { exportError = err } else { savedURL = url }
    }

    private func export() async -> URL? {
        guard let assetURL = asset?.url, end > start else { return nil }
        exporting = true
        defer { exporting = false }
        do {
            return try await ReelExport.export(assetURL: assetURL, options: .init(
                start: start, end: end, speed: speed, muted: muted, text: overlayText, textPos: textPos))
        } catch {
            exportError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    private func saveToPhotos(_ url: URL) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { ok, error in
                cont.resume(returning: ok ? nil : (error?.localizedDescription
                    ?? "Couldn't save to Photos. Allow photo access in Settings and retry."))
            }
        }
    }
}

// The filmstrip: video-frame thumbnails with a draggable trim window (two
// gradient handles), dimmed outside the selection, and a playhead.
private struct FilmstripTrimmer: View {
    let thumbnails: [UIImage]
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    let playhead: Double
    let onScrub: (Double) -> Void

    private let handleW: CGFloat = 14
    private let minGap: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let startX = CGFloat(start / max(duration, 0.001)) * w
            let endX = CGFloat(end / max(duration, 0.001)) * w
            let headX = CGFloat(min(max(playhead, start), end) / max(duration, 0.001)) * w
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    if thumbnails.isEmpty {
                        Rectangle().fill(Color.white.opacity(0.08))
                    } else {
                        ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: w / CGFloat(thumbnails.count), height: 56).clipped()
                        }
                    }
                }
                .frame(width: w, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, startX))
                Rectangle().fill(.black.opacity(0.55)).frame(width: max(0, w - endX)).offset(x: endX)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .leading, endPoint: .trailing), lineWidth: 3)
                    .frame(width: max(0, endX - startX), height: 56).offset(x: startX)
                Capsule().fill(.white).frame(width: 2, height: 56).offset(x: headX - 1)
                handle.offset(x: startX - handleW).gesture(dragHandle(isStart: true, width: w))
                handle.offset(x: endX).gesture(dragHandle(isStart: false, width: w))
            }
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .top, endPoint: .bottom))
            .frame(width: handleW, height: 56)
            .overlay(Capsule().fill(.white).frame(width: 3, height: 22))
    }

    private func dragHandle(isStart: Bool, width w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0).onChanged { g in
            let t = Double(min(max(g.location.x, 0), w) / w) * duration
            if isStart { start = min(t, end - minGap); onScrub(start) }
            else { end = max(t, start + minGap); onScrub(end) }
        }
    }
}

// UIActivityViewController wrapper so a trimmed clip can be saved to Photos / shared.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
