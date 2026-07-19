# Test Report — #1076 Attaching video not working in chat

## What changed
`PhotoAttachmentLoader` now loads picked videos through a file-URL `Transferable`
(`PickedMovie`) instead of `loadTransferable(type: Data.self)`, which returns
`nil` for movies. Both chat composers (`AskEmmaView`, `ChatComposerView`) route
picks through it and surface an error on failure instead of returning silently.

## Tests
- **New:** `Tests/Unit/AttachmentLoaderTests.swift` — 8 tests covering the
  image-vs-video classification that gates the upload branch:
  - QuickTime / MPEG-4 / bare `public.movie` are recognized as video and pinned
    to a `video/*` MIME so `Presence.mediaType` renders them as a player.
  - JPEG/PNG are images; PDF and empty type lists are neither.
  - filename = `upload-<epoch>.<ext>`.

## How to run
```sh
SKIP_EMULATOR=1 scripts/run-tests.sh   # unit only (hermetic)
```

## Status
PASS — `Test run with 101 tests in 12 suites passed`, including
`Suite AttachmentLoaderTests passed`. The app module compiles clean (the unit
target `@testable import`s it).

## Not covered
The picker-to-upload round trip can't be driven in XCUITest — the system Photos
picker isn't automatable and there's no composer mock seam. The failing branch
(video classification / load path selection) is covered at the unit level; the
actual `loadTransferable(PickedMovie)` call needs an on-device check with a real
video (see FOLLOW_UP.md).
