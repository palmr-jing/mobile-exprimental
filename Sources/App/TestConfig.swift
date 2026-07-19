import Foundation

// Central reader for launch arguments / environment overrides that make the app
// driveable in XCUITest without real Google auth, the Speech framework, or the
// production Firebase backend. Production builds never set these, so the seams
// are inert outside tests.
enum TestConfig {
    private static let args = ProcessInfo.processInfo.arguments
    private static let env = ProcessInfo.processInfo.environment

    /// Point Firestore/Auth/Storage at the local Firebase Emulator Suite.
    static var isUITest: Bool { args.contains("-UITEST") }

    /// Bypass Google Sign-In with a deterministic fake user.
    static var fakeUserEmail: String? { value(for: "-FAKE_USER_EMAIL") }
    static var fakeUserIsAdmin: Bool { value(for: "-FAKE_USER_ADMIN") == "1" }

    /// Drive the Videos tab from deterministic mock fixtures so the tap→play
    /// flow is UITestable without Firebase. Inert in production.
    static var isMockVideos: Bool { args.contains("-MOCK_VIDEOS") }

    /// Render the Videos tab's load-failure state with this message, so the
    /// error + "Try Again" recovery path is UITestable offline (#1069). Inert
    /// in production.
    static var mockVideosError: String? { value(for: "-MOCK_VIDEOS_ERROR") }

    /// Drive the Released tab from deterministic mock fixtures so the released
    /// recordings screen is screenshot-able without Firebase. Inert in production.
    static var isMockReleased: Bool { args.contains("-MOCK_RELEASED") }

    /// Inject a canned transcript instead of running SFSpeechRecognizer.
    static var useFakeVoice: Bool { args.contains("-FAKE_VOICE") }
    static var fakeVoiceTranscript: String { value(for: "-FAKE_VOICE_TRANSCRIPT") ?? "test dictation" }

    /// Emulator hosts (default to 127.0.0.1 when running under -UITEST). Must be
    /// IPv4, not "localhost": the simulator resolves "localhost" to IPv6 ::1 while
    /// the emulator listens on IPv4 127.0.0.1, so "localhost" leaves Firestore
    /// silently offline (queries return an empty cache with no error).
    static var firestoreHost: String { env["FIRESTORE_EMULATOR_HOST"] ?? "127.0.0.1:8080" }
    static var authHost: String { env["FIREBASE_AUTH_EMULATOR_HOST"] ?? "127.0.0.1:9099" }
    static var storageHost: String { env["FIREBASE_STORAGE_EMULATOR_HOST"] ?? "127.0.0.1:9199" }

    /// Read the value that follows a `-KEY value` launch argument pair.
    private static func value(for key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
