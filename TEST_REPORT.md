# Test Report — Task #835 (reply-to-message parity)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.x)
- **Status**: BUILD SUCCEEDED (`xcodebuild build-for-testing`, both app and test targets)

## Tests

### Unit Tests (`Tests/Unit/`)
- **AccessTests.swift** — access-control boundaries (unchanged).
- **PresenceTests.swift** — roster/mention logic, plus 3 NEW cases for the reply feature:
  - `replyPreviewUsesTextTruncatedTo120` — text preview truncates at 120 chars with an ellipsis.
  - `replyPreviewLabelsMediaWhenNoText` — image/video/file get emoji labels (📷/🎬/📎).
  - `replyAutoTagPrependsEmmaOnlyForBotReplies` — `@emma` is prepended only when replying to an Emma message and not already mentioned; never for human replies.
- **SpeechRecognitionServiceTests.swift** — speech config (unchanged).

### UI Tests (`Tests/UITests/`)
- **ChatUITests.swift** — composer/mention/voice, plus 1 NEW case:
  - `testReplyBarAppearsAndCancels` — sends a message, long-presses it, taps **Reply** from the context menu, asserts the reply bar appears, then cancels it.
- **SignInUITests.swift** — sign-in flow (unchanged).

## How to Run
```bash
# Unit tests only (hermetic, no emulator):
SKIP_EMULATOR=1 scripts/run-tests.sh

# Or directly:
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderTests

# UI tests run under the Firebase emulator:
scripts/run-tests.sh
```

## Current Status
- **Unit tests**: 29 tests across 3 suites — ALL PASS (incl. the 3 new reply tests).
- **Build-for-testing**: PASS for both `MobileCommanderTests` and `MobileCommanderUITests` (UI test compiles and links).
- **UI test execution**: not run here — it needs the Firebase Local Emulator Suite seeded
  via `scripts/seed-emulator.mjs`. The test compiles; run it with `scripts/run-tests.sh`.

## Notes
- The `FirebaseFirestore … Could not reach Cloud Firestore backend` lines during the unit run
  are expected: unit tests are hermetic and don't connect to an emulator. They don't affect results.
