import SwiftUI

/// The settings window content: the launcher hot key and Restore Defaults.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Launcher") {
                LabeledContent("Hot key") {
                    HotKeyRecorderView(settings: settings)
                }
            }
            HStack {
                Spacer()
                Button("Restore Defaults", action: settings.resetToDefaults)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
