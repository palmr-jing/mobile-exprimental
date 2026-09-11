# MobileCommander

The iOS version of Commander ("mobile commander") — the Emma developer console as
a native app. Scheme `MobileCommander`, bundle `ai.palmr.emma`. The Xcode project
is generated from `project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate        # regenerate MobileCommander.xcodeproj after editing project.yml
open MobileCommander.xcodeproj
```

## Testing

| Suite | Target | Backend |
| --- | --- | --- |
| Unit | `MobileCommanderTests` | none (hermetic) |
| Smoke + Scenario (UI) | `MobileCommanderUITests` | Firebase Local Emulator Suite, seeded |

```bash
SKIP_EMULATOR=1 scripts/run-tests.sh   # unit only
scripts/run-tests.sh                   # unit + UI under the emulator
```

The UI tests drive the app through a fake-auth seam (`-UITEST -FAKE_USER_EMAIL …`,
see `Sources/App/TestConfig.swift`) so they never touch Google sign-in or the live
fleet. They talk to the local emulator (auth/firestore/storage) seeded by
`scripts/seed-emulator.mjs`.

Run `scripts/run-tests.sh` for the current suite status.

## E2E pipeline → Emma dashboard project tab

`scripts/run-ios-e2e-and-publish.sh` is one end-to-end run that makes
MobileCommander show up in the Emma dashboard project tab with tests, scenarios,
unit results, and video — mirroring `palmr-coach-ios`. It:

1. syncs to `origin/main` and regenerates the Xcode project,
2. boots the simulator and builds for testing once,
3. boots + seeds the Firebase emulator under the app's project (`fir-web-codelab-8ace9`),
4. runs unit → smoke → scenario phases, recording per-phase simulator video,
5. parses each `.xcresult` for pass/fail counts,
6. trims, captions, and concatenates the clips with ffmpeg,
7. publishes via `scripts/upload-test-run.cjs` — uploads the video to Drive and
   writes the `test_runs` Firestore doc (project **"mobile commander"**) that the
   dashboard reads (`commander/src/testRuns.js` → `normalizeRun`).

```bash
scripts/run-ios-e2e-and-publish.sh                  # full run + publish
MC_E2E_DRY_RUN=1 scripts/run-ios-e2e-and-publish.sh # everything except the live Drive/Firestore write
```

Useful overrides: `MC_PROJECT_NAME`, `MC_SIMULATOR`, `PROJECT_ID`,
`COMMANDER_WORKER_DIR`, `MC_DRIVE_FOLDER`, `PALMR_E2E_DRIVE_UID`.

### Schedule (palmr-m24)
Installed as the `com.palmr.mobilecommander-e2e` LaunchAgent, firing 09:00 / 15:00
/ 21:00 local (offset 30 min from palmr-coach-ios to avoid Drive contention):

```bash
scripts/install-mobilecommander-e2e-launchd.sh   # run ON palmr-m24
launchctl start com.palmr.mobilecommander-e2e    # trigger a run by hand
```

`scripts/com.palmr.mobilecommander-e2e.plist` is a committed reference copy of the
rendered agent. Logs land in `logs/` (gitignored).

## Other scripts
- `scripts/upload-testflight.sh` — archive, export, and upload a TestFlight build.
- `scripts/snap-screens.sh` — capture the signed-in home screen to `shots/`.
