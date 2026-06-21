## Follow-Up

**What was done**: Added an attachment button (photo picker + clipboard paste) to the Ask Emma view, matching the Chat view's implementation. Attachments are uploaded to Firebase Storage under the user's private Emma channel and posted as a single message carrying both the attachment and any text, with `mentionsEmma`/`emmaStatus` flags so Emma processes the upload.

**What needs review**:
- Verify on a real device that tapping the paperclip in Ask Emma opens the photo picker and selecting an image shows the preview
- Verify that sending an image (with or without text) creates a message in the Emma channel with the correct attachment metadata
- Verify that clipboard paste works when an image is on the clipboard
- Confirm the "Uploading..." placeholder appears in the text field during upload
- Check that the existing Chat view attachment flow is unaffected

**Action items**:
- Test on a physical device (photo picker permissions differ from simulator)
- Confirm Emma's backend worker processes messages that carry an attachment (the message shape matches team chat but targets the private `emma-{uid}` channel)
- Push to remote once reviewed

**Files changed**:
- `Sources/Services/ChatService.swift` — Added `sendToEmmaWithAttachment(text:data:fileName:contentType:)` method that uploads to the Emma channel and posts a combined attachment+text message
- `Sources/Views/Chat/AskEmmaView.swift` — Added PhotosPicker, clipboard paste button, pending image preview, and wired send path to handle attachments via the new ChatService method
