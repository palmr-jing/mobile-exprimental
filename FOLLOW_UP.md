# Follow-up — Task #971: read `released_recordings`, show class recordings inline

**What was done**: Added a new **Released** tab to the signed-in app that subscribes
to the Firestore `released_recordings` collection with a live snapshot listener and
lists one card per released class — newest-first — with its 3 grouped camera angles
(Front / Front-right / RealSense) playable inline. New releases from
manage.everbot.org appear without an app change, because the listener is live.

**What needs review**:
- Sign in with a real account and confirm the **Released** tab shows the live
  "IMA Fit + Tiny Tigers" doc (jing's release) — I could not do a real Google
  sign-in in the autonomous run, so the live read path is unverified end-to-end
  (it mirrors the shipping `VideoService`/`FirestoreService` listener pattern).
- Confirm inline playback of a real tokenized `download_url` on a device/simulator
  while signed in. Firebase Storage download URLs are plain tokenized HTTPS and
  play through `AVPlayer(url:)` with no extra entitlement, but I only exercised
  playback against public sample MP4s via the `-MOCK_RELEASED` fixtures, not a
  real Storage URL.
- The Released listener reads the whole collection (no `.limit`). That's fine for
  "one doc per class" today; if it grows large, add a `.limit(to:)` and/or paging.
- Sort is client-side (`released_at`, falling back to `starts_at`). No composite
  index needed. If you'd rather push the sort server-side, note that an
  `.order(by:"released_at")` query would silently drop any doc missing that field.

**Action items**:
- Push this branch (the worker pushes automatically after the task).
- Verify the production `released_recordings` read rule (`allow read: if request.auth != null`)
  is deployed in the commander repo — this app relies on it. The rule I added to
  this repo's `firestore.rules` is emulator-only and is not deployed from here.
- Release a second recording from manage.everbot.org and confirm it appears live
  on the phone without reinstalling.

**Files changed**:
- `Sources/Models/ReleasedRecording.swift` — NEW. Model (`ReleasedRecording` +
  nested `Angle`), pure Firestore parser, camera-label mapping, date/device
  labels, newest-first sort.
- `Sources/Services/ReleasedRecordingsService.swift` — NEW. `@MainActor`
  `ObservableObject` with a live `released_recordings` snapshot listener; client-side
  sort; loading/error state. Mirrors `VideoService`.
- `Sources/Views/Recordings/ReleasedRecordingsView.swift` — NEW. The Released
  screen: cards (title + date + device/room), lazy tap-to-play inline `AVKit`
  `VideoPlayer` per angle, loading/error/empty states, `-MOCK_RELEASED` fixtures.
- `Sources/Views/RootTabView.swift` — added the 4th "Released" tab (tag 3).
- `Sources/App/MobileCommanderApp.swift` — added `MockReleasedRoot` so the tab can
  be screenshotted from fixtures without a live sign-in.
- `Sources/App/TestConfig.swift` — added the `isMockReleased` (`-MOCK_RELEASED`) seam.
- `firestore.rules` — added a `released_recordings` read/write block (emulator
  parity only; not deployed from this repo).
- `Tests/Unit/ReleasedRecordingTests.swift` — NEW. 10 unit tests for the parser + sort.
- `TEST_REPORT.md`, `DEPLOY_STATUS.md` — updated for this task.
