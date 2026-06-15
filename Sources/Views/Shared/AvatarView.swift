import SwiftUI

// Roster/message avatar with an online dot and a bot glyph. Port of the web
// Avatar component.
struct AvatarView: View {
    let name: String
    var photoURL: String?
    var online: Bool = false
    var isBot: Bool = false
    var size: CGFloat = 28

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).first.map(String.init)?.uppercased() ?? "?")
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        placeholder
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(DS.Colors.border, lineWidth: 0.5))

            Circle()
                .fill(online ? DS.Colors.green : DS.Colors.secondary)
                .frame(width: size * 0.32, height: size * 0.32)
                .overlay(Circle().stroke(DS.Colors.surface, lineWidth: 2))
        }
    }

    @ViewBuilder private var placeholder: some View {
        if isBot {
            ZStack {
                DS.Colors.accent.opacity(0.18)
                Image(systemName: "sparkles")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(DS.Colors.accent)
            }
        } else {
            ZStack {
                DS.Colors.border
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
    }
}
