# Emma iOS — feedback & improvement plan (2026-06-16)

Source: screen recording `RPReplay_Final1781633869.MP4` (iPad Air 11" M4, 2 min),
reviewed frame-by-frame. Goal: make Emma **easy to use**, fix UI that isn't
iOS-idiomatic, **maximize speech-to-text (voice input)**, and add **text-to-speech**
so users can hear Emma's replies.

## What the video shows
Signed in as Jing Cheng (jing@everbot.org). Tour of Developer mode
(Tasks / New / Chat / Reports / Settings) and Owner mode (Home / Chat / Request /
Status), plus the Switch Mode sheet. Chat itself was not opened in the clip.

## Findings (observed, concrete)

### A. Not adapted for iPad / not iOS-idiomatic
1. **Letterboxed on iPad** — the whole app renders in a narrow iPhone-width column
   on the left ~40% of the screen; the rest is empty. (Recording predates the
   universal-device change; layouts still need to *use* the iPad width.)
2. **Tab bar renders at the top** on iPad instead of the bottom. Needs a layout
   that's right on both (e.g. `NavigationSplitView`/sidebar on iPad, bottom
   `TabView` on iPhone).
3. **Transition glitches** — screen titles overlap during tab switches
   ("Status"/"Request" superimposed). Janky.

### B. Owner Home is confusing / leaks developer jargon
4. **"Your App Status" = three bare numbers** (`0  0  83`) with tiny labels.
   "Needs Attention: **83**" is alarming and meaningless to a non-dev owner.
5. **Raw task titles leak dev detail** into the owner view — e.g.
   "Add 2 cameras to UI (Tailscale 100.101.45.67 / Local 172.27.31.39)",
   "[browser] Fix read_series live failure: '__name is not defined'". An owner
   shouldn't see IPs, stack traces, or `[browser]` prefixes.
6. **Status screen shows raw repo names** (`commander`, `everbot-robot-control`,
   `everfit`) and mixed Chinese/English task text — not owner-friendly labeling.

### C. Voice is under-used (the headline ask)
7. Voice input exists only as a small mic in the chat composer. On a touch
   device the primary way to ask Emma for something should be **voice-first**.
8. No **text-to-speech** — there's no way to *hear* Emma's replies hands-free.

## Improvement plan

### 1. Native iPad / iOS-correct layout
- Adopt `NavigationSplitView` (sidebar + detail) on `.regular` width (iPad),
  keep bottom `TabView` on `.compact` (iPhone), via size classes.
- Make Home/Status/Reports use the full width (multi-column grids on iPad).
- Fix the title-overlap transition.

### 2. Make Owner Home genuinely easy
- Replace the three bare numbers with labeled, tappable status cards
  ("Working on N", "Done today N", "Needs you: N") + plain-language subtitles.
- **Humanize task text for the owner view**: strip `[browser]`/jargon prefixes,
  hide IPs/stack traces, show a friendly one-line summary (Emma can generate a
  human title server-side; fall back to a cleaned client-side string).
- Friendly project names (map repo → display name) instead of raw repo ids.

### 3. Maximize speech-to-text (voice-first)
- A prominent **"Hold to talk / tap to dictate"** primary action on Home and in
  Chat — big mic, live partial transcript, haptics, audio-level animation.
- On-device `SFSpeechRecognizer` with `requiresOnDeviceRecognition` where
  available; auto-send option after a pause; clear recording state.
- "Ask Emma" becomes the default Owner entry point (voice → project-less request,
  backend infers the project — already wired).

### 4. Text-to-speech (hear Emma)
- Add `AVSpeechSynthesizer` playback of Emma's replies: a speaker button per
  Emma bubble + an optional "auto-speak replies" toggle (hands-free mode).
- Respect silent switch / ducking; stop on new input; pick a natural voice.

### 5. Ease-of-use polish
- First-run hint pointing at the mic ("Tap and just say what you need").
- Larger tap targets, clearer empty states, consistent iOS navigation.

## Out of scope / follow-ups
- Server-side "humanized task title" generation (Emma) — improves B5 the most.
- Real iPad-native chat (split roster + thread) once the layout work lands.
