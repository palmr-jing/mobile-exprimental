import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .developer
    @State private var showModeSwitcher = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authService.user {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DS.Colors.accent)
                            VStack(alignment: .leading) {
                                Text(user.displayName ?? "Anonymous")
                                    .font(DS.Typography.subheading)
                                Text(user.email ?? "No email")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                    }
                }

                Section("Mode") {
                    Button {
                        showModeSwitcher = true
                    } label: {
                        HStack {
                            Image(systemName: appMode.icon)
                                .foregroundStyle(DS.Colors.accent)
                            Text(appMode.displayName)
                                .foregroundStyle(DS.Colors.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DS.Colors.secondary)
                        }
                    }
                }

                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(DS.Colors.secondary)
                    }
                    HStack {
                        Text("Firebase Project")
                        Spacer()
                        Text("fir-web-codelab-8ace9")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showModeSwitcher) {
                ModeSwitcher()
                    .presentationDetents([.medium])
            }
        }
    }
}
