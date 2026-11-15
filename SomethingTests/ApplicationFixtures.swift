import ApplicationServices
import Foundation

@testable import Something

/// Returns an application named `name` at a fake `/Applications` path that
/// tests never touch on disk.
func makeApplication(_ name: String) -> LaunchableApplication {
    LaunchableApplication(name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))
}

/// Returns a repository named `name` under a fake ghq root that tests never
/// touch on disk.
func makeRepository(_ name: String) -> GhqRepository {
    GhqRepository(name: name, url: URL(fileURLWithPath: "/ghq/\(name)"))
}

/// Returns a window of `applicationName` titled `title`. The element points
/// at the test process, so actions on it never touch another application.
func makeWindow(_ applicationName: String, _ title: String) -> SwitchableWindow {
    SwitchableWindow(
        applicationName: applicationName, title: title, processIdentifier: getpid(),
        element: AXUIElementCreateApplication(getpid()))
}
