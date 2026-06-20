import SwiftUI

// Toolbar bell with an unread badge and a dropdown of recent notifications.
// Tapping a mention switches the chat to that channel. Mirrors the web
// NotificationBell.
struct NotificationBell: View {
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var chatService: ChatService
    @State private var showList = false

    var body: some View {
        Button {
            showList = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 17))
                    .foregroundStyle(DS.Colors.text)
                if notificationService.unreadCount > 0 {
                    Text("\(min(notificationService.unreadCount, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(DS.Colors.red)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .accessibilityIdentifier("notification-bell")
        .popover(isPresented: $showList) {
            notificationList
                // Bounded size so the list scrolls *inside* the popover instead
                // of growing to full content height and running off-screen.
                .frame(width: 340, height: 460)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var notificationList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notifications").font(DS.Typography.subheading)
                Spacer()
                if notificationService.unreadCount > 0 {
                    Button("Mark all read") { notificationService.markAllRead() }
                        .font(DS.Typography.caption)
                }
            }
            .padding(DS.Spacing.md)
            Divider()
            if notificationService.notifications.isEmpty {
                Text("You're all caught up.")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.secondary)
                    .padding(DS.Spacing.lg)
            } else {
                ScrollView {
                    ForEach(notificationService.notifications) { n in
                        Button {
                            if let channelId = n.channelId { chatService.setActiveChannel(channelId) }
                            notificationService.markRead(n.id)
                            showList = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.message.isEmpty ? n.text : n.message)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.text)
                                if !n.text.isEmpty {
                                    Text(n.text)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }
}
