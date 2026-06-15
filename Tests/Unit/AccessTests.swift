import Testing
@testable import MobileCommander

// Mirrors the access-scope cases in commander/worker/emma.test.js so the iOS
// port stays behavior-compatible with the backend boundary.
struct AccessTests {
    private func account(admin: Bool = false, projects: [String]?) -> UserAccount {
        UserAccount(uid: "u", email: "u@x.com", displayName: "U", photoURL: nil, isAdmin: admin, projects: projects)
    }

    @Test func adminSeesEverything() {
        #expect(Access.canAccessProject("commander", account: account(admin: true, projects: [])) == true)
    }

    @Test func nilProjectsIsUnrestricted() {
        #expect(Access.canAccessProject("commander", account: account(projects: nil)) == true)
    }

    @Test func wildcardIsUnrestricted() {
        #expect(Access.canAccessProject("commander", account: account(projects: ["*"])) == true)
    }

    @Test func listScopesToNamedProjects() {
        #expect(Access.canAccessProject("commander", account: account(projects: ["commander"])) == true)
        #expect(Access.canAccessProject("commander", account: account(projects: ["other"])) == false)
    }

    @Test func failsClosedOnMissingAccount() {
        #expect(Access.canAccessProject("commander", account: nil) == false)
    }

    @Test func emailToDocIdMatchesBackendEncoding() {
        #expect(Access.emailToDocId("Tim@Everbot.org") == "tim_everbot_org")
        #expect(Access.emailToDocId("jamesdcheng@gmail.com") == "jamesdcheng_gmail_com")
    }

    @Test func accessibleProjectsUnionsTasksAndRegistryScoped() {
        let restricted = account(projects: ["commander", "palmr-ios"])
        let out = Access.accessibleProjects(
            taskProjects: ["commander", "everfit"],
            registryNames: ["commander", "palmr-ios", "secret-app"],
            account: restricted
        )
        #expect(out == ["commander", "palmr-ios"])   // sorted, includes registry-only palmr-ios, excludes secret-app
    }

    @Test func accessibleProjectsAdminGetsAll() {
        let out = Access.accessibleProjects(
            taskProjects: ["a"],
            registryNames: ["b", "c"],
            account: account(admin: true, projects: [])
        )
        #expect(out == ["a", "b", "c"])
    }
}
