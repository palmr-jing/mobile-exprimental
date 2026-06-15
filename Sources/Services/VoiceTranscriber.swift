import Foundation

// Base type for speech-to-text in the chat composer. A class (not a Swift
// protocol) so SwiftUI can observe it via @StateObject and so MicButton can hold
// any concrete transcriber. The Speech-framework implementation and the UITest
// mock both subclass this.
class VoiceTranscriber: ObservableObject {
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isAuthorized: Bool = false

    func requestAuthorization() async {}
    func start() throws {}
    func stop() {}
}

// Picks the real or mock transcriber based on launch arguments so UI tests never
// touch the Speech framework (its permission dialogs can't be driven in CI).
enum VoiceTranscriberFactory {
    static func make() -> VoiceTranscriber {
        TestConfig.useFakeVoice ? MockVoiceTranscriber() : SpeechVoiceTranscriber()
    }
}

// Emits a canned transcript on start() so XCUITest can assert the dictation →
// composer flow without real speech.
final class MockVoiceTranscriber: VoiceTranscriber {
    override func requestAuthorization() async { isAuthorized = true }

    override func start() throws {
        isAuthorized = true
        isRecording = true
        transcript = TestConfig.fakeVoiceTranscript
    }

    override func stop() {
        isRecording = false
    }
}
