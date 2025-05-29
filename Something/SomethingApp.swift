//
//  SomethingApp.swift
//  Something
//
//  Created by Ryohei Ueda on 2025/05/18.
//

import SwiftUI

@main
struct SomethingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        // Use Settings to prevent a default visible window from appearing on launch.
        // This makes the app behave more like a background utility.
        Settings {
            EmptyView() // No content for the settings window itself
        }
    }
}
