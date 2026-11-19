import AppKit
import SwiftUI

/// The settings window: the launcher hot key, the git repositories folder, the
/// Dock icon, the folders whose files the launcher lists, the local language model, and the
/// mascot's skin colors.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    private static let previewSize: CGFloat = 160

    var body: some View {
        Form {
            Section("Launcher") {
                LabeledContent("Hot key") {
                    HotKeyRecorderView(settings: settings)
                }
                LabeledContent("Repositories folder") {
                    HStack {
                        Text((settings.repositoryRootPath as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(settings.repositoryRootPath)
                        Button("Choose…", action: chooseRepositoryRoot)
                    }
                }
                LabeledContent("Org directory") {
                    HStack {
                        Text((settings.orgDirectoryPath as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(settings.orgDirectoryPath)
                        Button("Choose…", action: chooseOrgDirectory)
                    }
                }
                Toggle("Show icon in Dock", isOn: $settings.shouldShowDockIcon)
            }
            fileFoldersSection
            languageModelSection
            Section {
                HStack {
                    Spacer()
                    // Idle keeps the robot standing still at the center instead
                    // of replaying the entrance.
                    MascotView(
                        state: .idle,
                        query: "",
                        placement: .top,
                        model: settings.mascotModel
                    )
                    .frame(width: Self.previewSize, height: Self.previewSize)
                    Spacer()
                }
                ColorPicker(
                    "Head color",
                    selection: makeColorBinding(\.mascotHeadColor),
                    supportsOpacity: false
                )
                ColorPicker(
                    "Body color",
                    selection: makeColorBinding(\.mascotBodyColor),
                    supportsOpacity: false
                )
            } header: {
                Text("Mascot")
            } footer: {
                // The launcher's mascot exists only while the launcher is open,
                // and the launcher closes when this window takes focus.
                Text("The launcher's mascot takes the new colors the next time it opens.")
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

    private var fileFoldersSection: some View {
        Section {
            ForEach(settings.fileFolderPaths, id: \.self) { folderPath in
                HStack {
                    Text((folderPath as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folderPath)
                    Spacer()
                    Button {
                        settings.removeFileFolder(folderPath)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
            Button("Add Folder…", action: addFileFolder)
        } header: {
            Text("File Folders")
        } footer: {
            Text("The launcher lists the files under these folders when you type a query.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var languageModelSection: some View {
        Section {
            TextField("Base URL", text: $settings.llmBaseURL)
            TextField("Model", text: $settings.llmModelName, prompt: Text("gemma3"))
        } header: {
            Text("Language Model")
        } footer: {
            Text("An OpenAI-compatible server on this Mac, such as Ollama or LM Studio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addFileFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = true
        guard openPanel.runModal() == .OK else { return }
        for folderURL in openPanel.urls {
            settings.addFileFolder(folderURL.path)
        }
    }

    private func chooseRepositoryRoot() {
        chooseDirectory(for: \.repositoryRootPath)
    }

    private func chooseOrgDirectory() {
        chooseDirectory(for: \.orgDirectoryPath)
    }

    private func chooseDirectory(for pathKeyPath: ReferenceWritableKeyPath<AppSettings, String>) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(
            fileURLWithPath: settings[keyPath: pathKeyPath],
            isDirectory: true
        )
        guard openPanel.runModal() == .OK, let chosenDirectory = openPanel.url else { return }
        settings[keyPath: pathKeyPath] = chosenDirectory.path
    }

    /// Bridges a "#RRGGBB" setting to the `Color` that `ColorPicker` edits.
    private func makeColorBinding(
        _ keyPath: ReferenceWritableKeyPath<AppSettings, String>
    ) -> Binding<Color> {
        Binding(
            get: {
                let components =
                    MascotModel.rgb(hex: settings[keyPath: keyPath]) ?? (red: 1, green: 1, blue: 1)
                return Color(
                    .sRGB,
                    red: components.red,
                    green: components.green,
                    blue: components.blue
                )
            },
            set: { newColor in
                // The scene builder reads sRGB hex, so a picker color from
                // another space, such as Display P3, is converted first.
                guard let hex = MascotSceneBuilder.hex(of: NSColor(newColor)) else { return }
                settings[keyPath: keyPath] = hex
            }
        )
    }
}
