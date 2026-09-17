import SwiftUI
import AppKit

public struct ContentView: View {
    @ObservedObject var settings = AppSettings.shared

    @State private var allModels: [ModelInfo] = []
    @State private var searchText = ""
    @State private var selectedModelId: String? = nil
    @State private var sortOrder = [KeyPathComparator(\ModelInfo.modelName)]
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var showNoModelsAlert = false
    @State private var backendReady = false
    @State private var statusMessage = "Loading models..."

    var filteredModels: [ModelInfo] {
        var list = allModels

        if settings.hideProjectors {
            list = list.filter { !$0.isProjector }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                $0.modelName.localizedCaseInsensitiveContains(query) ||
                $0.publisher.localizedCaseInsensitiveContains(query) ||
                $0.quant.localizedCaseInsensitiveContains(query) ||
                $0.fileName.localizedCaseInsensitiveContains(query)
            }
        }

        return list.sorted(using: sortOrder)
    }

    var selectedModel: ModelInfo? {
        guard let id = selectedModelId else { return nil }
        return allModels.first(where: { $0.id == id })
    }

    var totalSizeBytes: Int64 {
        filteredModels.reduce(0) { $0 + $1.sizeBytes }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter models, publisher, quant...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .frame(width: 260)

                Toggle("Hide Projectors (mmproj)", isOn: $settings.hideProjectors)
                    .onChange(of: settings.hideProjectors) { _ in
                        settings.save()
                    }

                Spacer()

                Button(action: { reloadModels() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)

                Button(action: { runSelectedModel() }) {
                    Label("Run Model", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedModel == nil || selectedModel?.isProjector == true)

                Button(action: { openSelectedInFinder() }) {
                    Label("Open in Finder", systemImage: "folder")
                }
                .disabled(selectedModel == nil)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Model Table
            Table(filteredModels, selection: $selectedModelId, sortOrder: $sortOrder) {
                TableColumn("Model Name", value: \.modelName) { model in
                    HStack(spacing: 6) {
                        Image(systemName: model.isProjector ? "eye.fill" : "cube.fill")
                            .foregroundColor(model.isProjector ? .secondary : .accentColor)
                        Text(model.modelName)
                            .foregroundColor(model.isProjector ? .secondary : .primary)
                    }
                }
                .width(min: 200, ideal: 300)

                TableColumn("Quant", value: \.quant) { model in
                    Text(model.quant)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(model.isProjector ? .secondary : .primary)
                }
                .width(min: 70, ideal: 90)

                TableColumn("Size", value: \.sizeBytes) { model in
                    Text(model.formattedSize)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(model.isProjector ? .secondary : .primary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Publisher", value: \.publisher) { model in
                    Text(model.publisher)
                        .foregroundColor(model.isProjector ? .secondary : .primary)
                }
                .width(min: 100, ideal: 140)

                TableColumn("Filename", value: \.fileName) { model in
                    Text(model.fileName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .width(min: 200, ideal: 350)
            }
            .contextMenu(forSelectionType: String.self) { items in
                if let id = items.first, let model = allModels.first(where: { $0.id == id }) {
                    if !model.isProjector {
                        Button("Run Model") {
                            runModel(model)
                        }
                    }
                    Divider()
                    Button("Copy Run Command") {
                        TerminalLauncher.shared.copyRunCommand(model: model, settings: settings)
                    }
                    Button("Copy File Path") {
                        TerminalLauncher.shared.copyFilePath(model: model)
                    }
                    Divider()
                    Button("Open in Finder") {
                        TerminalLauncher.shared.openContainingFolder(model: model, fallbackDirectory: settings.resolvedModelsDirectory)
                    }
                    Button("Refresh List") {
                        reloadModels()
                    }
                }
            } primaryAction: { items in
                if let id = items.first, let model = allModels.first(where: { $0.id == id }) {
                    runModel(model)
                }
            }

            Divider()

            // Bottom Status Strip
            HStack {
                Text("Showing \(filteredModels.count) of \(allModels.count) models (\(ModelInfo.formatBytes(totalSizeBytes)))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(backendReady ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(backendReady ? "llama.cpp: Ready" : "llama.cpp: Not Found")
                        .font(.caption)
                        .foregroundColor(backendReady ? .green : .red)
                }

                Divider()
                    .frame(height: 14)

                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 850, minHeight: 480)
        .onAppear {
            checkBackend()
            reloadModels(promptIfEmpty: true)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            checkBackend()
            reloadModels()
        }) {
            SettingsView(onSave: {
                checkBackend()
                reloadModels()
            })
        }
        .alert("No Models Found", isPresented: $showNoModelsAlert) {
            Button("Select Models Folder", role: .none) {
                chooseModelsFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No GGUF models were found in:\n\n\(settings.resolvedModelsDirectory)\n\nWould you like to select your models folder now?")
        }
    }

    private func checkBackend() {
        let path = settings.resolvedLlamaCliPath
        backendReady = FileManager.default.fileExists(atPath: path)
    }

    private func reloadModels(promptIfEmpty: Bool = false) {
        isLoading = true
        Task {
            let models = await ModelScanner.shared.scan(directory: settings.resolvedModelsDirectory)
            await MainActor.run {
                self.allModels = models
                self.isLoading = false
                if models.isEmpty && promptIfEmpty {
                    self.showNoModelsAlert = true
                }
            }
        }
    }

    private func runSelectedModel() {
        guard let model = selectedModel else { return }
        runModel(model)
    }

    private func runModel(_ model: ModelInfo) {
        if model.isProjector { return }

        guard FileManager.default.fileExists(atPath: settings.resolvedLlamaCliPath) else {
            showSettings = true
            return
        }

        do {
            try TerminalLauncher.shared.launch(model: model, settings: settings)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Launch Model"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func openSelectedInFinder() {
        guard let model = selectedModel else { return }
        TerminalLauncher.shared.openContainingFolder(model: model, fallbackDirectory: settings.resolvedModelsDirectory)
    }

    private func chooseModelsFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            settings.modelsDirectory = url.path
            settings.save()
            reloadModels()
        }
    }
}
