import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The settings window: the global hot keys, the git repositories folder, the
/// Dock icon, the folders whose files the launcher lists, the local language model, and the
/// mascot's skin colors.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var commandPickerGeneration = 0

    private static let previewSize: CGFloat = 160

    var body: some View {
        Form {
            Section("Launcher") {
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
            hotKeysSection
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

    private var hotKeysSection: some View {
        Section {
            ForEach(settings.hotKeyBindings) { binding in
                HStack {
                    if case .openApplication(let target) = binding.command {
                        Image(
                            nsImage: ApplicationIconCache.shared.loadIcon(
                                for: LaunchableApplication(name: target.name, url: target.url)
                            )
                        )
                        .resizable()
                        .frame(width: 16, height: 16)
                    }
                    Picker("Command", selection: makeCommandBinding(for: binding.id)) {
                        ForEach(HotKeyCommand.plainCommands, id: \.title) { command in
                            Text(command.title).tag(Optional(command))
                        }
                        if case .openApplication = binding.command {
                            Text(binding.command.title).tag(Optional(binding.command))
                        }
                        Divider()
                        Text("Open Application…").tag(HotKeyCommand?.none)
                    }
                    .labelsHidden()
                    .id(commandPickerGeneration)
                    HotKeyRecorderView(settings: settings, bindingID: binding.id)
                    Button {
                        settings.removeHotKeyBinding(id: binding.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    // Without the last binding, an app with no Dock icon has no way in.
                    .disabled(settings.hotKeyBindings.count <= 1)
                    .help("Remove")
                }
            }
            Button("Add Hot Key", action: settings.addHotKeyBinding)
        } header: {
            Text("Hot Keys")
        } footer: {
            Text("Each hot key runs its command from any application. Bind a combination once.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // A nil selection is the "Open Application…" entry. It opens a chooser
    // instead of changing the command, so that cancelling keeps the old one.
    private func makeCommandBinding(for bindingID: UUID) -> Binding<HotKeyCommand?> {
        Binding(
            get: {
                settings.hotKeyBindings.first { $0.id == bindingID }?.command ?? .openLauncher
            },
            set: { selectedCommand in
                if let selectedCommand {
                    settings.updateCommand(selectedCommand, forBindingID: bindingID)
                } else {
                    // Run the modal panel after this view update, not inside it.
                    DispatchQueue.main.async { chooseApplication(forBindingID: bindingID) }
                }
            }
        )
    }

    private func chooseApplication(forBindingID bindingID: UUID) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.applicationBundle]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.prompt = "Choose"
        // The picker still shows "Open Application…" after a cancel, because
        // no setting changed; a new identity makes it show the saved command.
        defer { commandPickerGeneration += 1 }
        guard openPanel.runModal() == .OK, let applicationURL = openPanel.url else { return }
        let target = ApplicationTarget(
            path: applicationURL.path,
            bundleIdentifier: Bundle(url: applicationURL)?.bundleIdentifier
        )
        settings.updateCommand(.openApplication(target), forBindingID: bindingID)
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
