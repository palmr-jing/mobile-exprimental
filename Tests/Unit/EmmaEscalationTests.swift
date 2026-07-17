import Testing
import Foundation
@testable import MobileCommander

// Locks the "recover a dropped Emma request as a task" logic: which replies count
// as a timeout, which earlier message is the dropped request, the idempotent doc
// id, and the commander_tasks title/body shape.
struct EmmaEscalationTests {
    // A tiny builder so tests don't repeat every ChannelMessage field.
    private func msg(_ id: String, text: String, uid: String = "u1", isBot: Bool = false,
                     mentionsEmma: Bool = false) -> ChannelMessage {
        ChannelMessage(
            id: id, type: .text, text: text, authorUid: uid, authorName: "", authorEmail: "",
            createdAt: nil, attachment: nil, recording: nil, mentions: [], mentionsEmma: mentionsEmma,
            emmaStatus: nil, isBot: isBot, emmaThinking: false, replyTo: nil
        )
    }

    @Test func recognisesTheWorkerTimeoutReply() {
        #expect(EmmaEscalation.isTimeoutReply("That took too long and I had to stop — try a narrower question."))
        #expect(EmmaEscalation.isTimeoutReply("That TOOK TOO LONG and I had to stop."))
        #expect(EmmaEscalation.isTimeoutReply("I had to stop before finishing."))
    }

    @Test func ignoresNormalReplies() {
        #expect(!EmmaEscalation.isTimeoutReply("Here's the summary you asked for."))
        #expect(!EmmaEscalation.isTimeoutReply(""))
        #expect(!EmmaEscalation.isTimeoutReply(nil))
    }

    @Test func precedingRequestPrefersTheAtEmmaAsk() {
        let messages = [
            msg("1", text: "morning all"),
            msg("2", text: "@emma reduce memory usage on manage.everbot.org", mentionsEmma: true),
            msg("3", text: "unrelated chatter"),
            msg("4", text: "That took too long and I had to stop.", uid: "emma-bot", isBot: true),
        ]
        let found = EmmaEscalation.precedingRequest(before: "4", in: messages)
        #expect(found?.id == "2")
    }

    @Test func precedingRequestFallsBackToNearestHuman() {
        let messages = [
            msg("1", text: "please look at the build failure"),
            msg("2", text: "That took too long and I had to stop.", uid: "emma-bot", isBot: true),
        ]
        #expect(EmmaEscalation.precedingRequest(before: "2", in: messages)?.id == "1")
    }

    @Test func precedingRequestSkipsBotsAndMissingIds() {
        let messages = [msg("only-bot", text: "hi", uid: "emma-bot", isBot: true)]
        #expect(EmmaEscalation.precedingRequest(before: "only-bot", in: messages) == nil)
        #expect(EmmaEscalation.precedingRequest(before: "does-not-exist", in: messages) == nil)
    }

    @Test func docIdIsDeterministicPerMessage() {
        #expect(EmmaEscalation.taskDocId(timeoutMessageId: "abc123") == "emma-timeout-abc123")
    }

    @Test func titleStripsMentionPrefixesAndClips() {
        #expect(EmmaEscalation.taskTitle(request: "@emma investigate the freeze") == "[Emma] investigate the freeze")
        #expect(EmmaEscalation.taskTitle(request: "line one\nline two") == "[Emma] line one")
        #expect(EmmaEscalation.taskTitle(request: "   ") == "[Emma] Emma request that timed out")
        let long = String(repeating: "x", count: 200)
        let title = EmmaEscalation.taskTitle(request: long)
        #expect(title.hasPrefix("[Emma] "))
        #expect(title.hasSuffix("…"))
        #expect(title.count < 100)
    }

    @Test func bodyCarriesRequestAndOrigin() {
        let teamBody = EmmaEscalation.taskBody(request: "@emma fix the grid", channelName: "general")
        #expect(teamBody.contains("#general"))
        #expect(teamBody.contains("fix the grid"))
        #expect(!teamBody.contains("@emma fix the grid"))  // mention stripped

        let emmaBody = EmmaEscalation.taskBody(request: "", channelName: nil)
        #expect(emmaBody.contains("Ask Emma"))
        #expect(emmaBody.contains("(no text"))
    }
}
