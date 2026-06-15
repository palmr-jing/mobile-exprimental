import SwiftUI

// Create a private channel: name + member multi-select (roster minus self).
// Mirrors the web NewChannelModal.
struct NewChannelSheet: View {
    let roster: [RosterMember]
    let onCreate: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selected = Set<String>()

    private var others: [RosterMember] { roster.filter { !$0.isSelf && !$0.isBot } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Channel name") {
                    TextField("e.g. design", text: $name)
                        .accessibilityIdentifier("new-channel-name")
                }
                Section("Add members") {
                    if others.isEmpty {
                        Text("No other teammates yet.").foregroundStyle(DS.Colors.secondary)
                    }
                    ForEach(others) { member in
                        Button {
                            if selected.contains(member.email) { selected.remove(member.email) }
                            else { selected.insert(member.email) }
                        } label: {
                            HStack {
                                AvatarView(name: member.name, photoURL: member.photoURL, online: member.online, size: 24)
                                Text(member.name).foregroundStyle(DS.Colors.text)
                                Spacer()
                                if selected.contains(member.email) {
                                    Image(systemName: "checkmark").foregroundStyle(DS.Colors.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("New Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, Array(selected))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
