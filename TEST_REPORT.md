# Test Report — Task #947 (open chat at latest + page older messages)

## Build Status
- **Platform**: iOS Simulator — iPhone 17 Pro (iOS 26.x), Xcode 26.4
- **Status**: BUILD SUCCEEDED
  - `xcodebuild build -scheme MobileCommander` (app target)
  - `xcodebuild test -scheme MobileCommander -only-testing:MobileCommanderTests` (app + unit target)

## Tests

### Unit Tests (`Tests/Unit/`)
- **ChatPaginationTests.swift** — NEW, 5 cases over the paging helpers:
  - `nextLimitGrowsByOnePage` — the live window grows by exactly one page.
  - `hasEarlierOnlyWhenAFullPageCameBack` — a full page back means more history may exist;
    a short page (or empty channel) means we've reached the start.
  - `orderedAscendingReversesNewestFirstResults` — a newest-first Firestore snapshot is
    reversed to the oldest-first order the thread renders in.
  - `orderedAscendingDropsDuplicateIds` — overlapping snapshots don't double-render.
  - `orderedAscendingHandlesEmpty` — empty input is handled.
- **AccessTests.swift**, **PresenceTests.swift**, **SpeechRecognitionServiceTests.swift** — unchanged.

### UI Tests (`Tests/UITests/`)
- Unchanged. The scroll-anchor and load-earlier behavior is SwiftUI scroll-view behavior
  that unit tests can't observe; it needs a manual/simulator pass (see FOLLOW_UP.md).

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
- **Unit tests**: 34 tests across 4 suites — ALL PASS (incl. the 5 new pagination tests).
- **App build**: PASS (`xcodebuild build`).

## Notes
- The `FirebaseFirestore … Could not reach Cloud Firestore backend` lines during the unit
  run are expected: unit tests are hermetic and don't connect to an emulator. They don't
  affect results.
- The paging design uses a single live listener with a growing `limit` ordered by
  `createdAt` descending. Because the limit only grows, loaded messages stay resident for
  the session; Firestore's default on-disk persistence caches them across relaunches, so
  "keep earlier messages cached locally if already loaded" holds without extra code.
