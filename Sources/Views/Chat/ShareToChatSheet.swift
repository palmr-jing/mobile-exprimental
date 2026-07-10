import SwiftUI

// Reusable "share to chat" sheet: pick a destination (Ask Emma or a team channel),
// add a caption, optionally mention @emma, and send. The actual send is a closure
// so the same sheet serves both a single reel (Videos) and a 3-angle class
// recording bundle (Released).
struct ShareToChatSheet: View {
    let title: String
    let subtitle: String?
    var icon: String = "film"
    @ObservedObject var chatService: ChatService
    // (channelId, caption, mentionEmma) -> post it.
    let send: (_ channelId: String, _ caption: String, _ mentionEmma: Bool) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var target: Target = .emma
    @State private var mentionEmma = true
    @State private var sending = false

    // Ask Emma (the private 1:1) or a named team channel.
    enum Target: Hashable { case emma, channel(String) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Send to") {
                    Picker("Destination", selection: $target) {
                        Label("Ask Emma", systemImage: "sparkles").tag(Target.emma)
                        ForEach(chatService.visibleChannels) { ch in
                            Label("#\(ch.name)", systemImage: "number").tag(Target.channel(ch.id))
                        }
                    }
                    .accessibilityIdentifier("share-destination")
                }
                Section("Message") {
                    TextField("Add a caption…", text: $caption, axis: .vertical)
                        .lineLimit(1...4)
                    if case .channel = target {
                        Toggle("Mention @emma", isOn: $mentionEmma)
                    }
                }
                Section("Sharing") {
                    HStack(spacing: 12) {
                        Image(systemName: icon).foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                            if let subtitle {
                                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share to chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { submit() }
                        .disabled(sending)
                        .accessibilityIdentifier("share-send")
                }
            }
        }
    }

    private func submit() {
        sending = true
        let channelId: String
        let emma: Bool
        switch target {
        case .emma:
            channelId = chatService.emmaChannelId; emma = true
        case .channel(let id):
            channelId = id; emma = mentionEmma
        }
        let cap = caption
        Task {
            await send(channelId, cap, emma)
            dismiss()
        }
    }
}
