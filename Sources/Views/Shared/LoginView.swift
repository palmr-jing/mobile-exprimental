import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "terminal")
                        .font(.system(size: 64))
                        .foregroundStyle(DS.Colors.accent)

                    Text("Commander")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(DS.Colors.text)

                    Text("Mobile Task Control")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.secondary)
                }

                VStack(spacing: DS.Spacing.md) {
                    CommanderCard {
                        VStack(spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.green)
                                Text("Monitor tasks in real-time")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.text)
                                Spacer()
                            }
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.green)
                                Text("Create and manage work")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.text)
                                Spacer()
                            }
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.green)
                                Text("Control your worker fleet")
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.text)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }

                Spacer()

                VStack(spacing: DS.Spacing.md) {
                    Button {
                        isSigningIn = true
                        Task {
                            await authService.signInWithGoogle()
                            isSigningIn = false
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.circle.fill")
                            }
                            Text("Sign In")
                        }
                        .font(DS.Typography.subheading)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DS.Colors.dark)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .disabled(isSigningIn)

                    if let error = authService.errorMessage {
                        Text(error)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.bottom, 60)
            }
        }
    }
}
