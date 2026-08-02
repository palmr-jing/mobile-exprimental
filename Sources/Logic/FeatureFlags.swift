import Foundation

// Central feature flags — one edit, one source of truth, so a product decision
// isn't scattered across the codebase.
enum FeatureFlags {
    /// Burn the Palmr watermark into the *pixels* of a full-length recording
    /// saved via "Save to Photos".
    ///
    /// OFF for now (#1137): the burn-in re-encodes the entire recording, which is
    /// the slow tail users hit on long classes ("watermark step at the very end…
    /// stalling exports"). With this off, the download saves straight to Photos —
    /// no transcode — and branding relies on the render pipeline
    /// (manage.everbot.org) baking the mark into the source before release.
    ///
    /// Flip to `true` to restore the in-app in-pixel guarantee (#1075). The reel
    /// editor's watermark is unaffected either way — that path re-encodes anyway
    /// (trim/speed/mute), so its mark rides a pass it was going to run regardless.
    static let watermarkSavedVideos = false
}
