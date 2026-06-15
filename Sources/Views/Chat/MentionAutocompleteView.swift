import SwiftUI

// The "@" autocomplete dropdown shown above the composer while typing a mention.
struct MentionAutocompleteView: View {
    let options: [RosterMember]
    let onSelect: (RosterMember) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options) { member in
                Button {
                    onSelect(member)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        AvatarView(name: member.name, photoURL: member.photoURL,
                                   online: member.online, isBot: member.isBot, size: 24)
                        Text(member.name)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.text)
                        Spacer()
                        Text("@\(Presence.mentionHandle(email: member.email))")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if member.id != options.last?.id { Divider() }
            }
        }
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.border, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}
