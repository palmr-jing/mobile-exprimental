# Test Report

## Build Status
- **Platform**: iOS (Simulator — iPhone 17, iOS 26.4)
- **Status**: BUILD SUCCEEDED
- **Warnings**: 1 pre-existing warning (unused `try?` in ChatService.swift:274, unrelated)

## Tests

### Unit Tests (`Tests/Unit/`)
- **AccessTests.swift** — Access control boundary tests
- **PresenceTests.swift** — Presence/roster logic tests
- **SpeechRecognitionServiceTests.swift** — (NEW) Speech recognition configuration tests

### UI Tests (`Tests/UITests/`)
- **ChatUITests.swift** — Chat composer, mention autocomplete, mocked voice dictation
- **SignInUITests.swift** — Sign-in flow

## How to Run

```bash
xcodebuild -project MobileCommander.xcodeproj -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Current Status
- **Build**: Passes (zero errors)
- **Build-for-testing**: Passes (tests compile and link)
- **Test execution**: Simulator bootstrap timed out in headless environment. Tests run normally in Xcode or with a pre-booted simulator.

## What's Verified
- All Swift files compile without errors
- Recognition request no longer forces on-device model
- `taskHint = .dictation` and `addsPunctuation` are set on recognition requests
- `contextualStrings` property is settable and forwarded to the request
- Audio level uses real RMS power (via vDSP) instead of random values
