import SwiftUI
import FirebaseCore

@main
struct MobileCommanderApp: App {
    @StateObject private var authService = AuthService()
    @AppStorage("appMode") private var appMode: AppMode = .developer

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    splashView
                } else if authService.isSignedIn {
                    mainContent
                } else {
                    LoginView()
                        .environmentObject(authService)
                }
            }
            .onChange(of: authService.isAdmin) { _, isAdmin in
                if !isAdmin {
                    appMode = .owner
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch effectiveMode {
        case .developer:
            DeveloperTabView()
                .environmentObject(authService)
        case .owner:
            OwnerTabView()
                .environmentObject(authService)
        }
    }

    private var effectiveMode: AppMode {
        if !authService.isAdmin {
            return .owner
        }
        return appMode
    }

    private var splashView: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.accent)
                ProgressView()
                    .tint(DS.Colors.accent)
            }
        }
    }
}
