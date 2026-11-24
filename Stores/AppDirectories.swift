import Foundation

enum AppDirectories {
    static func applicationSupport() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "DoAvoid", isDirectory: true
        )
    }
}
