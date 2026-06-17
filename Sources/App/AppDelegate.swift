import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

// UIKit app delegate, adopted via @UIApplicationDelegateAdaptor. We need it for
// the three things SwiftUI's App lifecycle can't do directly: GoogleSignIn URL
// callbacks, APNs device-token registration, and FCM token delivery.
final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // On a dev-login launch, pin the app mode so the landing layout is
        // deterministic (the "appMode" AppStorage key has inconsistent defaults
        // across views, so persisted state alone isn't reliable). Defaults to
        // developer; override with -DEV_MODE owner.
        if TestConfig.devLogin {
            UserDefaults.standard.set(TestConfig.devMode ?? "developer", forKey: "appMode")
        }

        // Route the SDKs at the local emulator when running UI tests so E2E is
        // hermetic and never touches the live fleet.
        if TestConfig.isUITest {
            let fs = Firestore.firestore()
            let settings = fs.settings
            let (fsHost, fsPort) = Self.split(TestConfig.firestoreHost, 8080)
            settings.host = "\(fsHost):\(fsPort)"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            fs.settings = settings

            let (authHost, authPort) = Self.split(TestConfig.authHost, 9099)
            Auth.auth().useEmulator(withHost: authHost, port: authPort)

            let (stHost, stPort) = Self.split(TestConfig.storageHost, 9199)
            Storage.storage().useEmulator(withHost: stHost, port: stPort)
        }

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // GoogleSignIn completes its OAuth flow by opening a URL back into the app.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // APNs handed us a device token — pass it to FCM so it can mint a push token.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // FCM registration token — persisted per-user by PushService so the backend
    // can deliver mention pushes.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        PushService.shared.updateToken(fcmToken)
    }

    // Show banners for pushes that arrive while the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private static func split(_ hostPort: String, _ defaultPort: Int) -> (String, Int) {
        let parts = hostPort.split(separator: ":")
        let host = parts.first.map(String.init) ?? "localhost"
        let port = parts.count > 1 ? Int(parts[1]) ?? defaultPort : defaultPort
        return (host, port)
    }
}
