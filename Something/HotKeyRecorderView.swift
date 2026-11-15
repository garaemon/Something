import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A button that shows the current hot key and, once clicked, records the next
/// key press with Command, Option, or Control as the new hot key. Escape cancels.
struct HotKeyRecorderView: View {
    @ObservedObject var settings: AppSettings
    // The token that NSEvent returns for the local key monitor; nil while idle.
    @State private var keyDownMonitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(settings.isRecordingHotKey ? "Type a shortcut…" : settings.hotKeyCombo.description)
                .frame(minWidth: 120)
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if keyDownMonitor == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startRecording() {
        settings.isRecordingHotKey = true
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handleRecordedKeyDown(event) }
            // Swallow the press so that it does not also type into the window.
            return nil
        }
    }

    private func handleRecordedKeyDown(_ event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == UInt16(kVK_Escape) && modifierFlags.isEmpty {
            stopRecording()
            return
        }
        guard let keyCombo = HotKeyRecording.makeKeyCombo(
            carbonKeyCode: UInt32(event.keyCode), modifierFlags: modifierFlags)
        else {
            NSSound.beep()
            return
        }
        settings.hotKeyCombo = keyCombo
        stopRecording()
    }

    private func stopRecording() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        keyDownMonitor = nil
        settings.isRecordingHotKey = false
    }
}
