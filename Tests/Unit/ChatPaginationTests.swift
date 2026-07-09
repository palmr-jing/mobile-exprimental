import Testing
import Foundation
@testable import MobileCommander

// Covers the pure paging helpers behind "open at the latest message, page older
// ones in on scroll-up". No Firebase, so these run hermetically like the rest of
// the unit suite.
struct ChatPaginationTests {

    private func message(_ id: String, createdAt: Date? = nil) -> ChannelMessage {
        ChannelMessage(
            id: id,
            type: .text,
            text: id,
            authorUid: "u",
            authorName: "U",
            authorEmail: "u@x.com",
            createdAt: createdAt,
            attachment: nil,
            mentions: [],
            mentionsEmma: false,
            emmaStatus: nil,
            isBot: false,
            emmaThinking: false,
            replyTo: nil
        )
    }

    @Test func nextLimitGrowsByOnePage() {
        #expect(ChatPagination.nextLimit(ChatPagination.initialLimit) == ChatPagination.pageSize * 2)
        #expect(ChatPagination.nextLimit(0, pageSize: 10) == 10)
        #expect(ChatPagination.nextLimit(30, pageSize: 30) == 60)
    }

    @Test func hasEarlierOnlyWhenAFullPageCameBack() {
        // A full page back → there may be more history.
        #expect(ChatPagination.hasEarlier(receivedCount: 30, requestedLimit: 30) == true)
        // A short page → we've reached the start of the thread.
        #expect(ChatPagination.hasEarlier(receivedCount: 12, requestedLimit: 30) == false)
        // Empty channel → nothing earlier.
        #expect(ChatPagination.hasEarlier(receivedCount: 0, requestedLimit: 30) == false)
    }

    @Test func orderedAscendingReversesNewestFirstResults() {
        // Firestore returns newest-first; display wants oldest-first.
        let descending = [message("c"), message("b"), message("a")]
        #expect(ChatPagination.orderedAscending(fromDescending: descending).map(\.id) == ["a", "b", "c"])
    }

    @Test func orderedAscendingDropsDuplicateIds() {
        // Overlapping snapshots must not double-render a message.
        let descending = [message("b"), message("b"), message("a")]
        #expect(ChatPagination.orderedAscending(fromDescending: descending).map(\.id) == ["a", "b"])
    }

    @Test func orderedAscendingHandlesEmpty() {
        #expect(ChatPagination.orderedAscending(fromDescending: []).isEmpty)
    }
}
