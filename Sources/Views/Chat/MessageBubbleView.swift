import SwiftUI
import AVKit

// One chat message bubble: self / teammate / Emma styling, inline image & video
// playback, file links, the "Emma is thinking" state, Markdown for Emma replies,
// and @handle highlighting. Mirrors the web Message component.
struct MessageBubbleView: View {
    let message: ChannelMessage
    let isMine: Bool
    let myHandle: String
    // Optional reply hooks — supplied by the team Chat view. Reply on the private
    // Ask-Emma thread leaves these nil so the affordances simply don't appear.
    var onReply: ((ChannelMessage) -> Void)? = nil
    var onScrollToParent: ((String) -> Void)? = nil
    // Briefly ringed when another message's quote scrolls to this one.
    var isHighlighted: Bool = false

    // How far the bubble has been dragged in a swipe-to-reply gesture.
    @State private var dragOffset: CGFloat = 0

    private var isBot: Bool { message.isBot || message.authorUid == "emma-bot" }
    private var canReply: Bool { onReply != nil && !message.emmaThinking }
    // Swipe past this many points (rightward) commits the reply.
    private let replyTriggerDistance: CGFloat = 60

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let reply = message.replyTo { quotedParent(reply) }
                header
                attachmentView
                contentView
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(bubbleColor)
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(borderColor, lineWidth: 0.5))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.accent, lineWidth: isHighlighted ? 2 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .frame(maxWidth: 300, alignment: .leading)
            if !isMine { Spacer(minLength: 40) }
        }
        .offset(x: dragOffset)
        .animation(.interactiveSpring(), value: dragOffset)
        .contentShape(Rectangle())
        // Masked off when replies aren't available (e.g. Ask Emma) so it never
        // competes with the scroll view there.
        .gesture(swipeToReply, including: canReply ? .all : .subviews)
        .contextMenu { if canReply {
            Button {
                onReply?(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        } }
    }

    // Swipe right to reply — the iOS-native affordance. Bounded so it follows the
    // finger a little, then snaps back; only a rightward drag past the threshold
    // commits, so it never fights the vertical scroll.
    private var swipeToReply: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard canReply, value.translation.width > 0,
                      abs(value.translation.height) < abs(value.translation.width) else { return }
                dragOffset = min(value.translation.width, replyTriggerDistance + 12)
            }
            .onEnded { value in
                let committed = canReply && value.translation.width >= replyTriggerDistance
                    && abs(value.translation.height) < replyTriggerDistance
                dragOffset = 0
                if committed { onReply?(message) }
            }
    }

    // The quoted parent shown inside a reply bubble; tap scrolls to the original.
    private func quotedParent(_ reply: ReplyContext) -> some View {
        Button {
            onScrollToParent?(reply.id)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(reply.authorName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                    .lineLimit(1)
                Text(reply.text.isEmpty ? "…" : reply.text)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, DS.Spacing.sm)
            .overlay(alignment: .leading) {
                Rectangle().fill(DS.Colors.accent.opacity(0.5)).frame(width: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat-reply-quote")
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            if isBot {
                Text("BOT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(DS.Colors.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(message.authorName.isEmpty ? message.authorEmail : message.authorName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Colors.secondary)
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                Text(Self.relativeTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.secondary.opacity(0.7))
            }
        }
    }

    @ViewBuilder private var attachmentView: some View {
        if let attachment = message.attachment, let url = URL(string: attachment.url) {
            switch message.type {
            case .image:
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            case .video:
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            case .file:
                Link(destination: url) {
                    Label(attachment.name.isEmpty ? "File" : attachment.name, systemImage: "doc")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.accent)
                }
            case .text:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var contentView: some View {
        if message.emmaThinking {
            HStack(spacing: DS.Spacing.xs) {
                Text("Emma is thinking")
                    .font(DS.Typography.caption)
                    .italic()
                    .foregroundStyle(DS.Colors.secondary)
                ProgressView().scaleEffect(0.6)
            }
        } else if !message.text.isEmpty {
            Text(renderedText)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.text)
                .textSelection(.enabled)
        }
    }

    // Emma replies render as Markdown; teammate messages get @handle highlights.
    private var renderedText: AttributedString {
        if isBot {
            if let md = try? AttributedString(
                markdown: message.text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                return md
            }
            return AttributedString(message.text)
        }
        return Self.highlightMentions(message.text, myHandle: myHandle)
    }

    private var bubbleColor: Color {
        if isBot { return DS.Colors.accent.opacity(0.10) }
        return isMine ? DS.Colors.accent.opacity(0.15) : DS.Colors.border.opacity(0.5)
    }
    private var borderColor: Color {
        isBot ? DS.Colors.accent.opacity(0.4) : DS.Colors.border
    }

    // Build an AttributedString with "@token" runs tinted; the current user's own
    // handle gets a stronger highlight.
    static func highlightMentions(_ text: String, myHandle: String) -> AttributedString {
        var result = AttributedString()
        let ns = text as NSString
        guard let re = try? NSRegularExpression(pattern: #"(^|\s)(@[a-z0-9._-]+)"#, options: [.caseInsensitive]) else {
            return AttributedString(text)
        }
        var last = 0
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let tokenRange = m.range(at: 2)
            if tokenRange.location > last {
                result += AttributedString(ns.substring(with: NSRange(location: last, length: tokenRange.location - last)))
            }
            let token = ns.substring(with: tokenRange)
            var run = AttributedString(token)
            let mine = !myHandle.isEmpty && token.dropFirst().lowercased() == myHandle
            run.foregroundColor = DS.Colors.accent
            if mine { run.inlinePresentationIntent = .stronglyEmphasized }
            result += run
            last = tokenRange.location + tokenRange.length
        }
        if last < ns.length {
            result += AttributedString(ns.substring(from: last))
        }
        return result
    }

    static func relativeTime(_ date: Date?) -> String {
        guard let date else { return "now" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        let f = DateFormatter(); f.dateStyle = .short
        return f.string(from: date)
    }
}
