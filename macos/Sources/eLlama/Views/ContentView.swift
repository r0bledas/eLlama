import SwiftUI
import AppKit
import Combine

public enum ActiveSheet: Identifiable {
    case settings
    case modelLoadPrefs(model: ModelInfo, isServeMode: Bool)

    public var id: String {
        switch self {
        case .settings:
            return "settings"
        case .modelLoadPrefs(let model, let isServeMode):
            return "modelLoad_\(model.id)_\(isServeMode)"
        }
    }
}

public struct ContentView: View {
    @ObservedObject var settings = AppSettings.shared

    /// Width reserved for every button in the window toolbar.
    /// Each toolbar button occupies this fixed width; the macOS toolbar moves
    /// trailing buttons (Finder / Serve / Run Model) into the "»" overflow menu
    /// once the window is narrower than the sum of all toolbar item widths.
    /// Lower this value to keep the buttons visible in smaller windows.
    static let toolbarButtonWidth: CGFloat = 76

    @State private var allModels: [ModelInfo] = []
    @State private var manuallyOpenedModels: [ModelInfo] = []
    @State private var searchText = ""
    @State private var selectedModelId: String? = nil
    @State private var sortOrder = [KeyPathComparator(\ModelInfo.modelName)]
    @State private var isLoading = false
    @State private var activeSheet: ActiveSheet? = nil
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
                        Button("Serve Model...") {
                            selectedModelId = id
                            activeSheet = .modelLoadPrefs(model: model, isServeMode: true)
                        }

                        Button("Run Model") {
                            selectedModelId = id
                            runModel(model)
                        }

                        Divider()

                        Button("Configure Settings and Run...") {
                            selectedModelId = id
                            activeSheet = .modelLoadPrefs(model: model, isServeMode: false)
                        }
                    }

                    Divider()

                    Button("Copy Run Command") {
                        TerminalLauncher.shared.copyRunCommand(model: model, settings: settings)
                    }

                    Button("Copy Serve Command") {
                        TerminalLauncher.shared.copyServeCommand(model: model, settings: settings)
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
                        .accessibilityHidden(true)
                    Text(backendReady ? "llama.cpp: Ready" : "llama.cpp: Not Found")
                        .font(.caption)
                        .foregroundColor(backendReady ? .green : .red)
                        .accessibilityLabel(backendReady ? "Backend llama.cpp ready" : "Backend llama.cpp not found")
                }

                Divider()
                    .frame(height: 14)

                Button(action: {
                    activeSheet = .settings
                }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Settings")
                .help("Open Settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 110)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 26)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )

                    Button(action: { reloadModels() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClassicToolbarButtonStyle(isAvailable: !isLoading, width: Self.toolbarButtonWidth))
                    .disabled(isLoading)
                    .help("Reload models from directory")

                    Button(action: { openWebUI() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "globe")
                            Text("WebUI")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClassicToolbarButtonStyle(isAvailable: true, width: Self.toolbarButtonWidth))
                    .help("Open Web UI in default browser")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    Button(action: { openSelectedInFinder() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("Finder")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClassicToolbarButtonStyle(isAvailable: selectedModel != nil, width: Self.toolbarButtonWidth))
                    .disabled(selectedModel == nil)
                    .help("Open selected model in Finder")

                    let isServeAvailable = selectedModel != nil && selectedModel?.isProjector == false
                    Button(action: { serveSelectedModel() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "network")
                            Text("Serve")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClassicToolbarButtonStyle(isAvailable: isServeAvailable, width: Self.toolbarButtonWidth))
                    .disabled(!isServeAvailable)
                    .help("Configure and start llama-server")

                    let isRunAvailable = selectedModel != nil && selectedModel?.isProjector == false
                    Button(action: { runSelectedModel() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                            Text("Run Model")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(ClassicToolbarButtonStyle(isAvailable: isRunAvailable, isBlue: true, width: Self.toolbarButtonWidth))
                    .disabled(!isRunAvailable)
                    .help("Launch interactive chat in Terminal")
                }
            }
        }
        .navigationTitle("")
        .background(ClickOutsideDeselector {
            selectedModelId = nil
        })
        .onChange(of: selectedModelId) { newId in
            if let id = newId, let model = allModels.first(where: { $0.id == id }) {
                saveLastSelectedModel(model)
            }
        }
        .onAppear {
            checkBackend()
            reloadModels(promptIfEmpty: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .eLlamaOpenModelFile)) { _ in
            processPendingOpenFiles()
        }
        .sheet(item: $activeSheet, onDismiss: {
            checkBackend()
            reloadModels()
        }) { sheet in
            switch sheet {
            case .settings:
                SettingsView(
                    onSave: {
                        checkBackend()
                        reloadModels()
                    }
                )
            case .modelLoadPrefs(let model, let isServeMode):
                ModelLoadPrefsViewerWindow(
                    model: model,
                    isServeMode: isServeMode,
                    onLaunch: {
                        if isServeMode {
                            serveModel(model)
                        } else {
                            runModel(model)
                        }
                    }
                )
            }
        }
    }

    private func openSettings(for model: ModelInfo? = nil, initialTab: SettingsView.SettingsTab = .general, isServeMode: Bool = false) {
        if let model = model {
            activeSheet = .modelLoadPrefs(model: model, isServeMode: isServeMode)
        } else {
            activeSheet = .settings
        }
    }

    private func checkBackend() {
        let cliPath = settings.resolvedLlamaCliPath
        let serverPath = settings.resolvedLlamaServerPath
        backendReady = FileManager.default.fileExists(atPath: cliPath) || FileManager.default.fileExists(atPath: serverPath)
    }

    private func saveLastSelectedModel(_ model: ModelInfo) {
        settings.lastSelectedModelPath = model.filePath
        settings.lastSelectedModelFileName = model.fileName
        settings.save()
    }

    private func reloadModels(promptIfEmpty: Bool = false) {
        isLoading = true
        Task {
            let models = await ModelScanner.shared.scan(directory: settings.resolvedModelsDirectory)
            await MainActor.run {
                self.allModels = models
                self.isLoading = false

                for opened in self.manuallyOpenedModels where !self.allModels.contains(where: { $0.id == opened.id }) {
                    self.allModels.append(opened)
                }

                // By default always on launch select either the last selected / launched model
                if self.selectedModelId == nil && !models.isEmpty {
                    let candidate = models.first(where: { $0.filePath == self.settings.lastSelectedModelPath })
                        ?? models.first(where: { !self.settings.lastSelectedModelFileName.isEmpty && $0.fileName == self.settings.lastSelectedModelFileName })
                        ?? models.first(where: { !$0.isProjector })
                        ?? models.first
                    if let candidate = candidate {
                        self.selectedModelId = candidate.id
                    }
                }

                if models.isEmpty && promptIfEmpty && !self.settings.suppressNoModelsAlert {
                    self.showNoModelsFolderDialog()
                }

                self.processPendingOpenFiles()
            }
        }
    }

    private func showNoModelsFolderDialog() {
        let alert = NSAlert()
        alert.messageText = "No Models Found"
        alert.informativeText = "No GGUF models were found in:\n\n\(settings.resolvedModelsDirectory)\n\nWould you like to select your models folder now?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Select Models Folder")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't show again"

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            settings.suppressNoModelsAlert = true
            settings.save()
        }

        if response == .alertFirstButtonReturn {
            chooseModelsFolder()
        }
    }

    private func runSelectedModel() {
        guard let model = selectedModel else { return }
        runModel(model)
    }

    private func processPendingOpenFiles() {
        let urls = OpenFileHandler.shared.consumePending()
        guard !urls.isEmpty else { return }

        var lastModel: ModelInfo?
        for url in urls {
            let fileURL = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
            let fileSize = Int64(values?.totalFileSize ?? values?.fileSize ?? 0)

            guard let model = ModelScanner.parseModel(
                fileURL: fileURL,
                rootURL: fileURL.deletingLastPathComponent(),
                fileSize: fileSize
            ) else { continue }

            if !manuallyOpenedModels.contains(where: { $0.id == model.id }) {
                manuallyOpenedModels.append(model)
            }
            if !allModels.contains(where: { $0.id == model.id }) {
                allModels.append(model)
            }
            lastModel = model
        }

        if let model = lastModel {
            selectedModelId = model.id
            runModel(model)
        }
    }

    /// Optional pre-launch guardrail. Returns true when it is safe to proceed.
    /// Shows a suppressible alert when the estimated memory is near or above the
    /// system limit.
    private func confirmMemory(for model: ModelInfo) -> Bool {
        if model.isProjector || settings.suppressMemoryWarning { return true }

        let estimate = MemoryEstimator.shared.estimate(
            modelSizeBytes: model.sizeBytes,
            quant: model.quant,
            contextSize: settings.contextSize,
            uBatchSize: settings.uBatchSize,
            cacheTypeK: settings.cacheTypeK,
            cacheTypeV: settings.cacheTypeV
        )

        let verdict = MemoryEstimator.shared.verdict(
            for: estimate,
            thresholdPercent: settings.memoryWarnThresholdPercent
        )
        guard verdict != .ok else { return true }

        let alert = NSAlert()
        alert.messageText = verdict == .over ? "Not Enough Memory" : "High Memory Usage"
        alert.informativeText = """
        Estimated memory for this model is \(ModelInfo.formatBytes(estimate.totalBytes)) of \
        \(ModelInfo.formatBytes(estimate.limitBytes)) system memory (\(Int(estimate.fraction * 100))%).

        Weights: \(ModelInfo.formatBytes(estimate.weightsBytes))
        KV cache: \(ModelInfo.formatBytes(estimate.kvCacheBytes))
        Compute buffer: \(ModelInfo.formatBytes(estimate.computeBufferBytes))

        This is a rough estimate and may be inaccurate. Launching may cause severe \
        slowdowns, swapping, or the system becoming unresponsive.
        """
        alert.alertStyle = verdict == .over ? .critical : .warning
        alert.addButton(withTitle: "Proceed")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't show again"

        let response = alert.runModal()

        if alert.suppressionButton?.state == .on {
            settings.suppressMemoryWarning = true
            settings.save()
        }

        return response == .alertFirstButtonReturn
    }

    private func runModel(_ model: ModelInfo) {
        if model.isProjector { return }
        saveLastSelectedModel(model)

        guard FileManager.default.fileExists(atPath: settings.resolvedLlamaCliPath) else {
            openSettings(for: model, initialTab: .general, isServeMode: false)
            return
        }

        guard confirmMemory(for: model) else { return }

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

    private func serveSelectedModel() {
        guard let model = selectedModel else { return }
        saveLastSelectedModel(model)
        activeSheet = .modelLoadPrefs(model: model, isServeMode: true)
    }

    private func serveModel(_ model: ModelInfo) {
        if model.isProjector { return }
        saveLastSelectedModel(model)

        let serverPath = settings.resolvedLlamaServerPath
        guard FileManager.default.fileExists(atPath: serverPath) else {
            openSettings(for: model, initialTab: .general, isServeMode: true)
            return
        }

        guard confirmMemory(for: model) else { return }

        do {
            try TerminalLauncher.shared.launchServer(model: model, settings: settings)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Serve Model"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func openSelectedInFinder() {
        guard let model = selectedModel else { return }
        TerminalLauncher.shared.openContainingFolder(model: model, fallbackDirectory: settings.resolvedModelsDirectory)
    }

    private func openWebUI() {
        let urlString = settings.lastServerUrl.isEmpty ? "http://\(settings.serverHost):\(settings.serverPort)" : settings.lastServerUrl
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
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

// MARK: - Classic Toolbar Button Style
public struct ClassicToolbarButtonStyle: ButtonStyle {
    public var isAvailable: Bool = true
    public var isBlue: Bool = false
    public var width: CGFloat = 100
    public var height: CGFloat = 26

    public init(isAvailable: Bool = true, isBlue: Bool = false, width: CGFloat = 100, height: CGFloat = 26) {
        self.isAvailable = isAvailable
        self.isBlue = isBlue
        self.width = width
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: isBlue && isAvailable ? .semibold : .medium))
            .foregroundColor(foregroundColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isAvailable && !isBlue && configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 0.5)
            )
            .opacity(isAvailable ? 1.0 : 0.45)
    }

    private var foregroundColor: Color {
        if !isAvailable {
            return Color(NSColor.disabledControlTextColor)
        }
        if isBlue {
            return .white
        }
        return .primary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !isAvailable {
            return Color(NSColor.controlColor).opacity(0.35)
        }
        if isBlue {
            return isPressed ? Color(red: 0.08, green: 0.38, blue: 0.85) : Color(red: 0.12, green: 0.48, blue: 0.98)
        }
        return Color(NSColor.controlColor)
    }

    private func borderColor(isPressed: Bool) -> Color {
        if !isAvailable {
            return Color.clear
        }
        if isBlue {
            return Color.white.opacity(0.25)
        }
        return Color(NSColor.separatorColor)
    }
}

public struct ClassicBlueButtonStyle: ButtonStyle {
    public var isAvailable: Bool
    public var width: CGFloat

    public init(isAvailable: Bool, width: CGFloat = 100) {
        self.isAvailable = isAvailable
        self.width = width
    }

    public func makeBody(configuration: Configuration) -> some View {
        ClassicToolbarButtonStyle(isAvailable: isAvailable, isBlue: true, width: width).makeBody(configuration: configuration)
    }
}

// MARK: - Click Outside Deselector
public struct ClickOutsideDeselector: NSViewRepresentable {
    public var onDeselect: () -> Void

    public init(onDeselect: @escaping () -> Void) {
        self.onDeselect = onDeselect
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onDeselect: onDeselect)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.setupMonitor(for: view)
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDeselect = onDeselect
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    public class Coordinator {
        public var onDeselect: () -> Void
        private var monitor: Any?

        public init(onDeselect: @escaping () -> Void) {
            self.onDeselect = onDeselect
        }

        public func setupMonitor(for view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak view, weak self] event in
                guard let self = self, let view = view, let window = view.window, event.window == window else {
                    return event
                }
                guard let cv = window.contentView else { return event }
                let pt = event.locationInWindow
                guard let hit = cv.hitTest(pt) else { return event }

                var check: NSView? = hit
                var isControlOrProtected = false
                var inTableView = false
                var clickedEmptyTableRow = false

                while let current = check {
                    if current is NSTableHeaderView || current is NSScroller || current is NSControl || current is NSButton || current is NSTextView || String(describing: type(of: current)).contains("Toolbar") || String(describing: type(of: current)).contains("Titlebar") {
                        isControlOrProtected = true
                        break
                    }
                    if let tv = current as? NSTableView {
                        inTableView = true
                        let ptInTable = tv.convert(pt, from: nil)
                        let row = tv.row(at: ptInTable)
                        if row == -1 {
                            clickedEmptyTableRow = true
                        }
                        break
                    }
                    check = current.superview
                }

                if clickedEmptyTableRow || (!inTableView && !isControlOrProtected) {
                    DispatchQueue.main.async {
                        self.onDeselect()
                    }
                }

                return event
            }
        }

        public func tearDown() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit {
            tearDown()
        }
    }
}
