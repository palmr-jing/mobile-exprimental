import Foundation
import Speech
import AVFoundation
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
    private var silenceTimer: Timer?
    private var levelTimer: Timer?

    var silenceTimeout: TimeInterval = 1.8
    var onAutoSend: ((String) -> Void)?

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
            startLevelMonitoring()
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

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        if supportsOnDevice {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.handleFinalResult()
                    }
                }

                if let error, self.isRecording {
                    let nsError = error as NSError
                    // Code 1 = "no speech detected", code 216 = cancelled — not real errors
                    if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 1 || nsError.code == 216) {
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    self.cleanup()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                let inputNode = self.audioEngine.inputNode
                let channelData = inputNode.outputFormat(forBus: 0).channelCount > 0
                if channelData {
                    // Simulate audio level from engine activity
                    let level = self.audioEngine.isRunning ? Float.random(in: 0.1...0.8) : 0
                    self.audioLevel = level
                }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                let text = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.onAutoSend?(text)
                }
                self.cleanup()
            }
        }
    }

    private func handleFinalResult() {
        // Final result from recognizer — stop recording
        cleanup()
    }

    private func cleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

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
