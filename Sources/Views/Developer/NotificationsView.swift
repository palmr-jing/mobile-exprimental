import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if firestoreService.notifications.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(DS.Colors.secondary.opacity(0.5))
                        Text("No notifications")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(firestoreService.notifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowBackground(notification.read ? Color.clear : DS.Colors.accent.opacity(0.03))
                                .swipeActions(edge: .trailing) {
                                    if !notification.read {
                                        Button("Read") {
                                            Task { try? await firestoreService.markNotificationRead(notificationId: notification.id) }
                                        }
                                        .tint(DS.Colors.accent)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if firestoreService.unreadCount > 0 {
                        Button("Mark All Read") {
                            Task { try? await firestoreService.markAllNotificationsRead() }
                        }
                        .font(DS.Typography.caption)
                    }
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: CommanderNotification

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: notification.type.icon)
                .foregroundStyle(notification.type.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.text)
                    .lineLimit(2)
                if let date = notification.createdAt {
                    Text(date, style: .relative)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }

            Spacer()

            if !notification.read {
                Circle()
                    .fill(DS.Colors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
