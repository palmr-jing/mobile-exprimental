import SwiftUI

// Reusable push-to-dictate mic. Bound to any VoiceTranscriber; partial results
// stream into the composer text via the onTranscript callback. Mockable in
// UITests through VoiceTranscriberFactory.
struct MicButton: View {
    @ObservedObject var transcriber: VoiceTranscriber
    let onTranscript: (String) -> Void

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: transcriber.isRecording ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: 20))
                .foregroundStyle(transcriber.isRecording ? DS.Colors.red : DS.Colors.secondary)
                .frame(width: 36, height: 36)
        }
        .accessibilityIdentifier("chat-mic-button")
        .accessibilityLabel(transcriber.isRecording ? "Stop dictation" : "Dictate message")
        .onChange(of: transcriber.transcript) { _, newValue in
            if transcriber.isRecording { onTranscript(newValue) }
        }
    }

    private func toggle() async {
        if transcriber.isRecording {
            transcriber.stop()
            return
        }
        if !transcriber.isAuthorized { await transcriber.requestAuthorization() }
        try? transcriber.start()
        // The mock fills transcript synchronously on start; forward it once.
        if transcriber.isRecording && !transcriber.transcript.isEmpty {
            onTranscript(transcriber.transcript)
        }
    }
}
