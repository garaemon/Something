import AppKit
import Carbon.HIToolbox
import HotKey
import SwiftUI

/// A button that shows the hot key of one binding and, once clicked, records the next
/// key press with at least one modifier, Shift included, as the new hot key. Escape
/// cancels. With the Left/Right checkbox on, the recording keeps the side of each held
/// modifier, such as Right Shift + E.
struct HotKeyRecorderView: View {
    @ObservedObject var settings: AppSettings
    let bindingID: UUID
    // The token that NSEvent returns for the local key monitor; nil while idle.
    @State private var keyDownMonitor: Any?
    // Keeps the left or right side of each held modifier in the next recording.
    @State private var keepsSides = false

    private var binding: HotKeyBinding? {
        settings.hotKeyBindings.first { $0.id == bindingID }
    }

    var body: some View {
        HStack {
            Button(action: toggleRecording) {
                Text(
                    settings.recordingBindingID == bindingID
                        ? "Type a shortcut…" : binding?.shortcutDescription ?? ""
                )
                .frame(minWidth: 120)
            }
            // The settings row is narrow, and without a fixed size SwiftUI wraps
            // the label one letter per line.
            Toggle("Left/Right", isOn: $keepsSides)
                .toggleStyle(.checkbox)
                .fixedSize()
                .help("Tell the left and right modifier keys apart the next time you record")
        }
        .onAppear { keepsSides = binding?.modifierSides.isSided ?? false }
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
        settings.recordingBindingID = bindingID
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
        // The device-dependent bits that tell left from right sit outside the
        // device-independent mask, so the raw flags go to the recorder.
        guard
            let shortcut = HotKeyRecording.makeShortcut(
                carbonKeyCode: UInt32(event.keyCode),
                modifierFlags: event.modifierFlags,
                keepsSides: keepsSides
            )
        else {
            NSSound.beep()
            return
        }
        guard
            settings.assignKeyCombo(
                shortcut.keyCombo,
                modifierSides: shortcut.modifierSides,
                toBindingID: bindingID
            )
        else {
            // Another binding holds the combination.
            NSSound.beep()
            return
        }
        stopRecording()
    }

    private func stopRecording() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        keyDownMonitor = nil
        // Another row may have started recording since; leave its state alone.
        if settings.recordingBindingID == bindingID {
            settings.recordingBindingID = nil
        }
    }
}
