# Follow-Up — Voice-First / Ask Emma (Task 725)

**What was done**: Added voice-first "Ask Emma" as the primary Owner mode entry point, with on-device speech recognition (SFSpeechRecognizer), a reusable voice input button with audio-level animation and haptics, and voice input in the task chat interface.

**What needs review**:
- Verify on a physical device that `requiresOnDeviceRecognition` works with the user's locale (fallback to server-based is automatic when on-device is unavailable)
- Confirm haptic feedback feels right on iPhone hardware (simulator doesn't produce haptics)
- Check that the "Ask Emma" tab icon (mic.fill) is visually distinct from other tabs at small sizes
- Test the auto-send silence timeout (1.8s) — may need tuning based on real usage patterns
- Confirm empty-project tasks created by `createEmmaTask` are handled correctly by the backend task router

**Action items**:
- The backend needs to handle tasks with empty `project` and `path` fields — these are "Ask Emma" tasks where the backend should infer the target project
- Add a `source: "voice"` field handler in the backend if you want analytics on voice vs text submissions
- Consider adding a test target to `project.yml` for unit testing the SpeechRecognitionService
- No deployment needed — this is a native iOS app

**Files changed**:

| File | Change |
|------|--------|
| `Sources/Services/SpeechRecognitionService.swift` | NEW — Core speech-to-text service wrapping SFSpeechRecognizer with on-device recognition, audio level monitoring, silence detection, and auto-send callback |
| `Sources/Views/Shared/VoiceInputButton.swift` | NEW — Reusable voice button (VoiceInputButton for full-size, CompactVoiceButton for inline chat) with audio-level ring animation, haptics, tap-to-dictate and hold-to-talk |
| `Sources/Views/Owner/AskEmmaView.swift` | NEW — Full-screen voice-first "Ask Emma" view with big mic button, live transcript, text fallback input, auto-send toggle |
| `Sources/Views/Owner/OwnerTabView.swift` | Added "Ask Emma" as the first (default) tab in Owner mode |
| `Sources/Views/Owner/OwnerHomeView.swift` | Added "Ask Emma" quick-action card below the greeting card |
| `Sources/Views/Developer/TaskDetailView.swift` | Added CompactVoiceButton to chat input bar with live transcript preview |
| `Sources/Services/FirestoreService.swift` | Added `createEmmaTask(message:)` for project-less voice task creation |
| `Resources/Info.plist` | Added NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription |
