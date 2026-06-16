# Follow-Up

**What was done**: Added text-to-speech for Emma (assistant) replies in the task chat view. Created a SpeechService using AVSpeechSynthesizer with silent-switch-aware audio session (`.ambient` + `.duckOthers`), added a speaker button on each Emma chat bubble, and an auto-speak toggle for hands-free mode.

**What needs review**:
- Verify the speaker button on Emma bubbles triggers playback on a real device (simulator TTS may sound robotic)
- Confirm auto-speak only fires for newly arrived messages, not historical ones on initial load
- Test that tapping Send stops any in-progress speech
- Check that the auto-speak toggle state persists across app launches (stored in UserDefaults as `emma_auto_speak`)
- Verify audio ducking works when music or other audio is playing
- Confirm silent switch on a physical device suppresses TTS output

**Action items**:
- Test on a physical iOS device — TTS voice quality and silent switch behavior can't be verified in the simulator
- If users report the voice sounds unnatural, consider downloading enhanced/premium voices in device Settings > Accessibility > Spoken Content > Voices
- Push to GitHub remote

**Files changed**:
- `Sources/Services/SpeechService.swift` — New file. AVSpeechSynthesizer wrapper with audio session config, voice selection (premium > enhanced > default), published speaking state, auto-speak persistence via UserDefaults.
- `Sources/Views/Developer/TaskDetailView.swift` — Added SpeechService as StateObject; chatView gains auto-speak capsule toggle; ChatBubble shows speaker/stop button on non-user messages; speech stops on send and on view disappear; auto-speak triggers on new Emma messages only.
- `MobileCommander.xcodeproj/project.pbxproj` — Added SpeechService.swift to file references, build files, Services group, and Sources build phase.
- `TEST_REPORT.md` — Updated with build verification results and manual testing checklist for TTS.
