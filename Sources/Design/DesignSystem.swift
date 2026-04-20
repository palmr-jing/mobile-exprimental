import SwiftUI

enum DS {
    enum Colors {
        static let background = Color(hex: "FAF7F4")
        static let surface = Color.white
        static let text = Color(hex: "1A1A1A")
        static let secondary = Color(hex: "6B7280")
        static let accent = Color(hex: "5C6B4F")
        static let dark = Color(hex: "141413")
        static let red = Color(hex: "DC2626")
        static let amber = Color(hex: "D97706")
        static let blue = Color(hex: "2563EB")
        static let green = Color(hex: "16A34A")
        static let border = Color(hex: "E5E7EB")
    }

    enum Typography {
        static let title = Font.system(size: 28, weight: .semibold)
        static let headline = Font.system(size: 20, weight: .semibold)
        static let subheading = Font.system(size: 15, weight: .medium)
        static let body = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let small = Font.system(size: 11, weight: .medium)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CommanderCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.border, lineWidth: 0.5)
            )
    }
}

struct CommanderDarkCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DS.Spacing.lg)
            .background(DS.Colors.dark)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Text(status.displayName)
            .font(DS.Typography.small)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color)
            .clipShape(Capsule())
    }
}
