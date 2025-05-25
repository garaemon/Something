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
        WindowGroup {
            ContentView()
        }
    }
}
