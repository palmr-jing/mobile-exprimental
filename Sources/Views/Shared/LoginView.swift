import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "terminal")
                        .font(.system(size: 60))
                        .foregroundStyle(DS.Colors.accent)

                    Text("Commander")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Colors.text)

                    Text("Mobile Task Control")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                }

                Spacer()

                VStack(spacing: DS.Spacing.md) {
                    GoogleSignInButton(scheme: .light, style: .wide) {
                        Task { await authService.signInWithGoogle() }
                    }
                    .accessibilityIdentifier("google-sign-in")

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.red)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, 60)
            }
        }
    }
}
