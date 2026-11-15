import AppKit
import SwiftUI

/// The settings window: the launcher hot key and the mascot's skin colors.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Launcher") {
                LabeledContent("Hot key") {
                    HotKeyRecorderView(settings: settings)
                }
            }
            Section {
                ColorPicker("Head color", selection: makeColorBinding(\.mascotHeadColor), supportsOpacity: false)
                ColorPicker("Body color", selection: makeColorBinding(\.mascotBodyColor), supportsOpacity: false)
            } header: {
                Text("Mascot")
            } footer: {
                // The mascot exists only while the launcher is open, and the
                // launcher closes when this window takes focus.
                Text("Colors apply the next time the launcher opens.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    /// Bridges a "#RRGGBB" setting to the `Color` that `ColorPicker` edits.
    private func makeColorBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, String>) -> Binding<Color> {
        Binding(
            get: {
                let components = MascotModel.rgb(hex: settings[keyPath: keyPath]) ?? (red: 1, green: 1, blue: 1)
                return Color(.sRGB, red: components.red, green: components.green, blue: components.blue)
            },
            set: { newColor in
                // The scene builder reads sRGB hex, so a picker color from
                // another space, such as Display P3, is converted first.
                guard let srgbColor = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                settings[keyPath: keyPath] = MascotModel.hex(
                    red: srgbColor.redComponent, green: srgbColor.greenComponent, blue: srgbColor.blueComponent)
            })
    }
}
