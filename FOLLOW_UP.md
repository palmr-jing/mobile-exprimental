# Follow-Up — Task #760 (fix all-white/unreadable text)

**What was done**: The app's design system is light-only (hard-coded cream/white
backgrounds, near-black text tokens), but it never told iOS to opt out of dark mode.
On a dark-mode device, every element using SwiftUI's default `.primary` color — most
visibly the Ask Emma and Chat text inputs — rendered white on those light
backgrounds, which is the unreadable "all white text" jing reported. I locked the
app to light appearance so default colors resolve to the dark token everywhere, and
gave the two chat input fields an explicit dark text color as a backstop.

**What needs review**:
- Sign in on a device/simulator set to **dark mode** and walk every screen
  (Dashboard, Chat, Ask Emma, Reports, Settings, Owner views). Confirm no white-on-
  light text remains. I could only reach the login screen headless (Google auth).
- Type into both chat composers (Chat tab + Ask Emma) in dark mode and confirm the
  text you type is dark and readable.
- Decide whether locking to light is the intended product direction. The whole color
  palette is light-only, so a real dark theme is a separate, larger piece of work
  (redefine all 11 tokens in `DS.Colors` as asset-catalog/dynamic colors and re-check
  every `.white`-on-accent usage). If you want true dark-mode support instead of a
  light lock, that's the path — flag it and I'll scope it.

**Action items**:
- Push this branch to remote (the worker does this automatically).
- Human-only: sign in on a dark-mode device and eyeball the post-login screens as above.
- Optional: bump `CURRENT_PROJECT_VERSION` in `project.yml` and run
  `scripts/upload-testflight.sh` to get a build in front of jing for confirmation.

**Files changed**:
- `Resources/Info.plist` — added `UIUserInterfaceStyle = Light` so UIKit surfaces
  (alerts, photo picker, keyboard) and the whole app render light.
- `Sources/App/MobileCommanderApp.swift` — added `.preferredColorScheme(.light)` on
  the root content for the SwiftUI side (sheets, previews) with an explaining comment.
- `Sources/Views/Chat/ChatComposerView.swift` — explicit `.foregroundStyle(DS.Colors.text)`
  on the message `TextField` so typed text is dark independent of the global lock.
- `Sources/Views/Chat/AskEmmaView.swift` — same explicit text color on the Ask Emma
  `TextField`.
