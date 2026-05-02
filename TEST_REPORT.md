# Test Report - Mobile Commander iOS

## Build Status

- **Platform**: iOS 17.0+ (Simulator: iPhone 17 Pro, iOS 26.4)
- **Build**: SUCCEEDED
- **Compiler**: Swift 5.9, Xcode (xcodegen for project generation)
- **Dependencies**: Firebase iOS SDK 11.0+ (FirebaseAuth, FirebaseFirestore, FirebaseStorage)
- **Date**: 2026-05-02

## Test Coverage

No unit tests exist yet. The app relies on Firebase backend services for data, making integration testing more relevant than unit testing.

### Recommended Tests to Add

1. **Model parsing** — Verify `CommanderTask`, `CommanderWorker`, `CommanderNotification` parse Firestore documents correctly
2. **FirestoreService** — Mock Firestore snapshots and verify published state updates
3. **Mode switching** — Verify non-admin users are locked to Owner mode
4. **Task filtering** — Verify filter/sort/search logic in TaskListView

## How to Build

```bash
# Regenerate Xcode project from project.yml
xcodegen generate

# Build for simulator
xcodebuild -project MobileCommander.xcodeproj \
  -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  build
```

## How to Run

Open `MobileCommander.xcodeproj` in Xcode, select a simulator target, and run. The app requires:
- `GoogleService-Info.plist` in Resources/ (already present)
- A Firebase project with Firestore collections: `commander_tasks`, `commander_workers`, `commander_notifications`, `commander_allowed_users`
