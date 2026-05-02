import SwiftUI

struct OwnerSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .owner
    @Environment(\.dismiss) private var dismiss
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

                if authService.isAdmin {
                    Section("Mode") {
                        Button {
                            showModeSwitcher = true
                        } label: {
                            HStack {
                                Image(systemName: "terminal")
                                    .foregroundStyle(DS.Colors.accent)
                                Text("Switch to Developer Mode")
                                    .foregroundStyle(DS.Colors.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                            }
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(DS.Colors.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showModeSwitcher) {
                ModeSwitcher()
                    .presentationDetents([.medium])
            }
        }
    }
}
