import HotKey
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var myHotKey: HotKey?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Bind Command + Shift + x and
        myHotKey = HotKey(key: .x, modifiers: [.command, .shift])
        myHotKey?.keyDownHandler = {
            print("Hello World")
        }
    }
}
