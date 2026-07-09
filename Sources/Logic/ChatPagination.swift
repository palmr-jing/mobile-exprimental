import Foundation

// Pure helpers for the team-chat "open at the latest message, page older ones in
// on scroll-up" behavior. No Firebase imports so this stays trivially
// unit-testable (mirrors the Presence helper pattern).
//
// The service keeps a single live Firestore listener ordered by createdAt
// DESCENDING with a growing `limit`. The newest page is what you see on open;
// scrolling up grows the limit by one page to reveal older history. Because the
// limit only ever grows, already-loaded messages stay resident for the session,
// and Firestore's on-disk cache serves them again on relaunch.
enum ChatPagination {
    // How many messages a single page holds. Small enough that the first read is
    // cheap, large enough to fill a tall screen.
    static let pageSize = 30

    // The limit for the very first subscription to a channel.
    static var initialLimit: Int { pageSize }

    // Grow the window by one page when the user scrolls to the top and asks for
    // earlier messages.
    static func nextLimit(_ current: Int, pageSize: Int = pageSize) -> Int {
        current + pageSize
    }

    // Whether older messages may still exist beyond what we just loaded. A full
    // page back (received == requested) means Firestore had at least that many, so
    // there may be more; a short page means we've reached the start of history.
    static func hasEarlier(receivedCount: Int, requestedLimit: Int) -> Bool {
        receivedCount >= requestedLimit
    }

    // Turn a newest-first (descending) query result into the oldest-first order
    // the thread renders in, de-duplicated by id as a safety net against any
    // overlap between snapshots.
    static func orderedAscending(fromDescending descending: [ChannelMessage]) -> [ChannelMessage] {
        var seen = Set<String>()
        var out: [ChannelMessage] = []
        out.reserveCapacity(descending.count)
        for message in descending.reversed() where seen.insert(message.id).inserted {
            out.append(message)
        }
        return out
    }
}
