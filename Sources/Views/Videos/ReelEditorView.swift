import SwiftUI
import UIKit
import AVFoundation
import AVKit

// A lightweight reel editor: preview the clip, trim it with start/end handles,
// then export the trimmed segment and share/save it. Mirrors the core
// "trim + export" of the everbot web Reel Editor, on iOS.
struct ReelEditorView: View {
    let video: AssignedVideo
    let service: VideoService
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var asset: AVURLAsset?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var loadFailed = false
    @State private var exporting = false
    @State private var exported: ExportedFile?
    @State private var exportError: String?

    struct ExportedFile: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let player {
                    VideoPlayer(player: player).frame(maxHeight: 340).cornerRadius(12)
                } else if loadFailed {
                    ContentUnavailableView("Couldn't load video", systemImage: "exclamationmark.triangle")
                        .frame(maxHeight: 340)
                } else {
                    ProgressView().frame(maxHeight: 340).frame(maxWidth: .infinity)
                }

                if duration > 0 { trimControls }
                Spacer()
            }
            .padding()
            .navigationTitle("Edit reel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(exporting ? "Exporting…" : "Export") { Task { await export() } }
                        .disabled(exporting || duration == 0 || end - start < 0.5)
                }
            }
            .task { await load() }
            .sheet(item: $exported) { ShareSheet(items: [$0.url]) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private var trimControls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Start \(fmt(start))")
                Spacer()
                Text("Trim \(fmt(max(0, end - start)))").fontWeight(.semibold)
                Spacer()
                Text("End \(fmt(end))")
            }
            .font(.caption).foregroundColor(.secondary)

            Slider(value: $start, in: 0...duration) { editing in if !editing { seek(start) } }
                .onChange(of: start) { _, v in if v > end - 0.5 { start = max(0, end - 0.5) } }
            Slider(value: $end, in: 0...duration) { editing in if !editing { seek(end) } }
                .onChange(of: end) { _, v in if v < start + 0.5 { end = min(duration, start + 0.5) } }
        }
    }

    private func fmt(_ s: Double) -> String {
        let t = Int(s.rounded()); return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func seek(_ s: Double) {
        player?.seek(to: CMTime(seconds: s, preferredTimescale: 600),
                     toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func load() async {
        guard let url = await service.playbackURL(for: video) else { loadFailed = true; return }
        let a = AVURLAsset(url: url)
        do {
            let d = try await a.load(.duration)
            asset = a
            duration = max(0, CMTimeGetSeconds(d))
            end = duration
            player = AVPlayer(url: url)
        } catch {
            loadFailed = true
        }
    }

    private func export() async {
        guard let asset, end > start else { return }
        exporting = true
        defer { exporting = false }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            exportError = "Couldn't create an export session."; return
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("trim-\(UUID().uuidString).mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { cont.resume() }
        }
        if session.status == .completed {
            exported = ExportedFile(url: out)
        } else {
            exportError = session.error?.localizedDescription ?? "Export didn't complete."
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
