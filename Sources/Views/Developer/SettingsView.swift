import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firestoreService: FirestoreService
    @AppStorage("appMode") private var appMode: AppMode = .developer
    @State private var showModeSwitcher = false
    @State private var showNotifications = false

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

                        HStack {
                            Text("Role")
                            Spacer()
                            Text(authService.isAdmin ? "Admin" : "User")
                                .foregroundStyle(DS.Colors.secondary)
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

                Section("System") {
                    NavigationLink {
                        NotificationsView()
                            .environmentObject(firestoreService)
                    } label: {
                        HStack {
                            Text("Notifications")
                            Spacer()
                            if firestoreService.unreadCount > 0 {
                                Text("\(firestoreService.unreadCount)")
                                    .font(DS.Typography.small)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(DS.Colors.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack {
                        Text("Tasks")
                        Spacer()
                        Text("\(firestoreService.tasks.count)")
                            .foregroundStyle(DS.Colors.secondary)
                    }

                    HStack {
                        Text("Workers")
                        Spacer()
                        Text("\(firestoreService.workers.filter(\.isOnline).count) online")
                            .foregroundStyle(DS.Colors.secondary)
                    }

                    HStack {
                        Text("Total Cost")
                        Spacer()
                        Text(String(format: "$%.2f", firestoreService.totalCost))
                            .foregroundStyle(DS.Colors.secondary)
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
                        Text("Build")
                        Spacer()
                        Text("iOS \(appMode.rawValue)")
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
