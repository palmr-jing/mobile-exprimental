import SwiftUI
import AVKit

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
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)

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
        .onDisappear {
            player?.pause()
            player = nil
        }
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

    private func start() {
        guard player == nil, let url = angle.downloadURL else { return }
        // Play with the ringer silenced, as the video feed does.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        player = p
        p.play()
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
