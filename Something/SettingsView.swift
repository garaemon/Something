import SwiftUI

/// The content of the settings window.
struct SettingsView: View {
    var body: some View {
        Form {
            Text("No settings yet.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
