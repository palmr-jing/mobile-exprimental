import SwiftUI

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
                        .accessibilityIdentifier("commander-logo")

                    Text("Commander")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Colors.text)
                        .accessibilityIdentifier("commander-title")

                    Text("Mobile Task Control")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                        .accessibilityIdentifier("commander-subtitle")
                }

                Spacer()

                VStack(spacing: DS.Spacing.md) {
                    Button {
                        Task { await authService.signInWithGoogle() }
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In")
                        }
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DS.Colors.dark)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .accessibilityIdentifier("sign-in-button")

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.red)
                            .accessibilityIdentifier("error-message")
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, 60)
            }
        }
    }
}
