import Foundation

@testable import Something

/// Returns an application named `name` at a fake `/Applications` path that
/// tests never touch on disk.
func makeApplication(_ name: String) -> LaunchableApplication {
    LaunchableApplication(name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))
}
