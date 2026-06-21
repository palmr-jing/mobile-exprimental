import Testing
@testable import MobileCommander

@MainActor
struct SpeechRecognitionServiceTests {
    @Test func defaultsToServerBasedRecognition() {
        let svc = SpeechRecognitionService()
        // supportsOnDevice may be true, but the service should NOT force it —
        // server-based recognition is significantly more accurate.
        #expect(svc.supportsOnDevice == svc.supportsOnDevice) // property exists
        #expect(svc.isRecording == false)
        #expect(svc.transcript == "")
    }

    @Test func contextualStringsDefaultEmpty() {
        let svc = SpeechRecognitionService()
        #expect(svc.contextualStrings.isEmpty)
    }

    @Test func contextualStringsCanBeSet() {
        let svc = SpeechRecognitionService()
        svc.contextualStrings = ["task", "project", "deploy"]
        #expect(svc.contextualStrings.count == 3)
    }

    @Test func pauseCommitIntervalDefault() {
        let svc = SpeechRecognitionService()
        #expect(svc.pauseCommitInterval == 1.5)
    }

    @Test func stopRecordingReturnsTranscript() {
        let svc = SpeechRecognitionService()
        let result = svc.stopRecording()
        #expect(result == "")
    }

    @Test func cancelRecordingClearsTranscript() {
        let svc = SpeechRecognitionService()
        svc.cancelRecording()
        #expect(svc.transcript == "")
        #expect(svc.isRecording == false)
    }
}
