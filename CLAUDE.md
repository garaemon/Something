# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Something" is a macOS utility app built with SwiftUI that operates as a background service. The app is designed to be triggered via global hotkey (Cmd+Shift+X) and automatically hides when it loses focus, making it behave like a quick-access tool rather than a traditional desktop application.

## Build Commands

Build the project:
```bash
xcodebuild -project Something.xcodeproj -scheme Something -configuration Debug build
```

Build for release:
```bash
xcodebuild -project Something.xcodeproj -scheme Something -configuration Release build
```

Run the app from command line (after building):
```bash
open Something.xcodeproj/build/Debug/Something.app
```

## Architecture

### Core Components

- **SomethingApp.swift**: Main app entry point using SwiftUI's App protocol. Uses Settings scene to prevent default window appearance on launch.
- **AppDelegate.swift**: Handles app lifecycle, global hotkey registration (HotKey library), and window management. Sets activation policy to `.accessory` to keep app out of Dock.
- **SomethingWindowController.swift**: Custom NSWindowDelegate that implements auto-hide behavior when window loses focus.
- **ContentView.swift**: Main UI content displayed in the popup window.
- **PreferenceView.swift**: Preferences interface (currently basic placeholder).

### Key Behavioral Patterns

- **Background Service Pattern**: App runs as accessory (.accessory activation policy) without Dock presence
- **Global Hotkey Activation**: Uses HotKey library for Cmd+Shift+X trigger
- **Auto-Hide on Focus Loss**: Window automatically hides when user clicks away or switches apps
- **Single Window Management**: Only one popup window exists at a time, reuses existing if already open

### Dependencies

- **HotKey (v0.2.1)**: Swift Package Manager dependency for global hotkey functionality
  - Repository: https://github.com/soffes/HotKey
  - Used for: Cmd+Shift+X global hotkey registration

### Window Management Strategy

The app implements a sophisticated window lifecycle:
1. Window created on-demand when hotkey triggered
2. Custom SomethingWindowController manages window delegate responsibilities
3. Window automatically hides on focus loss (windowDidResignKey)
4. Strong references maintained in AppDelegate during window lifetime
5. Cleanup handled via closure-based callback system (onWindowRelease)

### Sandboxing

App uses macOS App Sandbox with minimal permissions:
- `com.apple.security.app-sandbox`: true
- `com.apple.security.files.user-selected.read-only`: true