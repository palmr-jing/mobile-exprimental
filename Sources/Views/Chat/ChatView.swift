import SwiftUI
import UIKit

// The full team-chat screen: presence roster strip, channel selector, message
// thread, and composer. Reaches parity with the web TeamChat.
struct ChatView: View {
    @EnvironmentObject var chatService: ChatService
    @EnvironmentObject var notificationService: NotificationService
    @State private var showNewChannel = false
    // The message currently ringed after a tap on its quote.
    @State private var highlightedId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                rosterStrip
                channelSelector
                Divider()
                messageList
                ChatComposerView()
            }
            .background(DS.Colors.background)
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBell()
                }
            }
            .sheet(isPresented: $showNewChannel) {
                NewChannelSheet(roster: chatService.roster) { name, members in
                    Task { await chatService.createChannel(name: name, memberEmails: members) }
                }
            }
        }
    }

    private var rosterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(chatService.roster) { member in
                    VStack(spacing: 2) {
                        AvatarView(name: member.name, photoURL: member.photoURL,
                                   online: member.online, isBot: member.isBot, size: 32)
                        Text(member.isSelf ? "You" : member.name.split(separator: " ").first.map(String.init) ?? member.name)
                            .font(.system(size: 10))
                            .foregroundStyle(member.online ? DS.Colors.text : DS.Colors.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 56)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.surface)
    }

    private var channelSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(chatService.visibleChannels) { channel in
                    Button {
                        chatService.setActiveChannel(channel.id)
                    } label: {
                        Text("#\(channel.name)")
                            .font(DS.Typography.caption)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(channel.id == chatService.effectiveChannelId ? DS.Colors.accent.opacity(0.2) : Color.clear)
                            .foregroundStyle(channel.id == chatService.effectiveChannelId ? DS.Colors.text : DS.Colors.secondary)
                            .clipShape(Capsule())
                    }
                }
                Button {
                    showNewChannel = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.secondary)
                        .padding(DS.Spacing.xs)
                }
                .accessibilityIdentifier("chat-new-channel")
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
        }
        .background(DS.Colors.surface)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    if chatService.messages.isEmpty {
                        Text("No messages yet. Say hi 👋")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(chatService.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isMine: message.authorEmail.lowercased() == chatService.myEmail,
                            myHandle: chatService.myHandle,
                            onReply: { chatService.startReply(to: $0) },
                            onScrollToParent: { scrollToParent($0, proxy: proxy) },
                            isHighlighted: message.id == highlightedId
                        )
                        .id(message.id)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: chatService.messages.count) { _, _ in
                if let last = chatService.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // Tapping a reply's quote scrolls to the parent and briefly rings it. If the
    // parent isn't in the loaded thread the scroll is a no-op (web parity).
    private func scrollToParent(_ id: String, proxy: ScrollViewProxy) {
        guard chatService.messages.contains(where: { $0.id == id }) else { return }
        withAnimation { proxy.scrollTo(id, anchor: .center) }
        highlightedId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if highlightedId == id { highlightedId = nil }
        }
    }
}
