import Foundation
import Speech
import AVFoundation
import Accelerate
import Combine

@MainActor
class SpeechRecognitionService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var audioLevel: Float = 0
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    // Finalized speech segments accumulated across recognizer restarts, so a long
    // dictation survives pauses, on-device end-of-utterance segmentation, and the
    // SFSpeechRecognizer ~1-minute-per-request limit. Recording only ends when the
    // user taps stop (or a real error) — never on silence.
    private var committedText = ""
    // Bumped on every new request; callbacks from a superseded task are ignored.
    private var recognitionGeneration = 0
    // Fires after a short pause to bank the current partial into committedText and
    // restart recognition. This is what keeps a long dictation intact: on-device
    // recognition often never sends `isFinal` mid-utterance and drops earlier
    // words from a long partial, so we commit at pauses instead of relying on it.
    private var commitTimer: Timer?
    var pauseCommitInterval: TimeInterval = 1.5
    var contextualStrings: [String] = []

    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    var supportsOnDevice: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    var needsPermission: Bool {
        authorizationStatus == .notDetermined
    }

    var permissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = speechStatus

        guard speechStatus == .authorized else { return false }

        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        return micStatus
    }

    func startRecording() {
        guard !isRecording else { return }
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }

        do {
            try prepareAudioSession()
            try startRecognition()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stopRecording() -> String {
        guard isRecording else { return transcript }
        let finalText = transcript
        cleanup()
        return finalText
    }

    func cancelRecording() {
        transcript = ""
        cleanup()
    }

    private func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        committedText = ""

        startRecognitionRequest()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            if let data = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                var rms: Float = 0
                vDSP_rmsqv(data, 1, &rms, vDSP_Length(buffer.frameLength))
                let level = max(0, min(1, rms * 5))
                Task { @MainActor [weak self] in
                    self?.audioLevel = level
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // Create a fresh recognition request + task that feeds off the (already
    // running) audio tap. Called on start, and again whenever the recognizer
    // finalizes a segment mid-dictation, so capture continues seamlessly.
    private func startRecognitionRequest() {
        recognitionGeneration += 1
        let gen = recognitionGeneration

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
        }
        recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                // Ignore callbacks from a superseded (restarted/cancelled) task —
                // otherwise its trailing events cascade-restart us and wipe the
                // in-progress text.
                guard let self, self.isRecording, gen == self.recognitionGeneration else { return }

                if let result {
                    let segment = result.bestTranscription.formattedString
                    self.transcript = self.committedText.isEmpty
                        ? segment
                        : (self.committedText + " " + segment)
                    if result.isFinal {
                        // The recognizer closed this segment (a pause or the
                        // ~1-min limit). Bank it and keep listening — never stop
                        // recording here; only the user's tap stops it.
                        if !segment.isEmpty { self.committedText = self.transcript }
                        self.restartRecognitionRequest()
                    } else {
                        // Live partial: (re)arm the pause-commit so this text is
                        // banked into committedText the moment speech lulls — before
                        // the on-device recognizer can drop it from a long partial.
                        self.scheduleCommit()
                    }
                }

                if let error {
                    let nsError = error as NSError
                    // 216 = WE cancelled this task (restart/stop) — ignore it, do
                    // NOT restart (that was the cascade that wiped text).
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        return
                    }
                    // No-speech-yet (1) or recognizer retry/limit (203): bank what
                    // we have and continue with a fresh request.
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 1 || nsError.code == 203) {
                        let banked = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !banked.isEmpty { self.committedText = banked }
                        self.restartRecognitionRequest()
                        return
                    }
                    // Genuine failure: keep the transcript, stop recording.
                    self.errorMessage = error.localizedDescription
                    self.cleanup()
                }
            }
        }
    }

    // Tear down just the recognition request/task (leaving the audio engine + tap
    // running) and spin up a fresh one to continue the same dictation. Starting a
    // new request bumps recognitionGeneration, so the cancelled task's late
    // callbacks are ignored by the guard above.
    private func restartRecognitionRequest() {
        guard isRecording else { return }
        commitTimer?.invalidate()
        commitTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        startRecognitionRequest()
    }

    // After a brief speech lull, bank whatever's transcribed so far into
    // committedText and restart recognition from a clean segment — so the
    // running total survives no matter how long the dictation gets. Commits at a
    // pause, so it never clips mid-word, and never stops recording.
    private func scheduleCommit() {
        commitTimer?.invalidate()
        commitTimer = Timer.scheduledTimer(withTimeInterval: pauseCommitInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                let banked = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !banked.isEmpty, banked != self.committedText else { return }
                self.committedText = banked
                self.restartRecognitionRequest()
            }
        }
    }

    private func cleanup() {
        commitTimer?.invalidate()
        commitTimer = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        audioLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
