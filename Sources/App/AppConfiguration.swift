import Foundation

enum AppConfiguration {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    static var isTesting: Bool {
        isUITesting ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil ||
        ProcessInfo.processInfo.environment.keys.contains(where: { $0.hasPrefix("XCTest") }) ||
        ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"]?.contains("libXCTestBundleInject") == true
    }
}
