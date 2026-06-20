# Follow-Up

**What was done**: Fixed keyboard blocking tab bar switching and added photo upload/paste support to the Chat composer. Users can now dismiss the keyboard by swiping down or tapping the message area, pick images from their camera roll with a preview before sending, and paste images from their clipboard.

**What needs review**:
- Tap the Chat text field, start typing, then swipe down on the message list — keyboard should dismiss and tab bar should be tappable
- Same test on the Ask Emma tab — swipe down or tap the conversation thread should dismiss the keyboard
- In Chat, pick a photo via the paperclip — verify the thumbnail preview appears above the composer with the file name and size
- Tap the X on the preview to remove it without sending
- Pick a photo, type some text, then tap send — both the image and text should send (image first, then text)
- Copy an image to clipboard in another app, return to Chat, verify the paste button (clipboard icon) appears, tap it, confirm the preview shows
- Test picking a video — it should still upload immediately (no preview), matching prior behavior

**Action items**:
- Run on a real device to test clipboard paste (UIPasteboard may behave differently in Simulator)
- Test with large photos (10MB+) to confirm upload doesn't timeout or crash
- Consider adding a progress indicator during upload when an image is pending

**Files changed**:
- `Sources/Views/Chat/ChatView.swift` — Added `scrollDismissesKeyboard(.interactively)` and tap-to-dismiss on the message list
- `Sources/Views/Chat/AskEmmaView.swift` — Same keyboard dismissal on the Ask Emma conversation thread
- `Sources/Views/Chat/ChatComposerView.swift` — Added pending image state with thumbnail preview, clipboard paste button, wired attachment into send flow with preview-before-send for images
