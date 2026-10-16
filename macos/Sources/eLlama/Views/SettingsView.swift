import SwiftUI
import AppKit

// MARK: - Copyable URL Field
public struct CopyableUrlField: View {
    public let urlString: String
    public let isWebUiEnabled: Bool
    @State private var isHovered = false
    @State private var showCopiedPill = false

    public init(urlString: String, isWebUiEnabled: Bool) {
        self.urlString = urlString
        self.isWebUiEnabled = isWebUiEnabled
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Static output field that underlines on hover and copies on click
            Text(urlString)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isWebUiEnabled ? .primary : .secondary)
                .underline(isHovered && isWebUiEnabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isHovered && isWebUiEnabled ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor), lineWidth: 1)
                )
            .contentShape(Rectangle())
            .onHover { hovering in
                if isWebUiEnabled {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                if isWebUiEnabled {
                    copyToClipboard()
                }
            }
            .help("Click to copy URL")

            // Square copy button showing only icon
            Button(action: {
                copyToClipboard()
            }) {
                Image(systemName: showCopiedPill ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(width: 28, height: 28)
            .disabled(!isWebUiEnabled)
            .help("Copy URL to clipboard")

            // Open in browser button
            Button("Open in Browser") {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!isWebUiEnabled)
        }
        .opacity(isWebUiEnabled ? 1.0 : 0.5)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            showCopiedPill = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCopiedPill = false
            }
        }
    }
}

// MARK: - Native Mac Slider (Full-Width System Slider)
public struct NativeMacSlider: NSViewRepresentable {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double

    public init(value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0) {
        self._value = value
        self.range = range
        self.step = step
    }

    public func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.isContinuous = true
        slider.controlSize = .regular
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return slider
    }

    public func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.parent = self
        if abs(nsView.doubleValue - value) > 0.0001 {
            nsView.doubleValue = value
        }
        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject {
        var parent: NativeMacSlider

        init(_ parent: NativeMacSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSSlider) {
            var val = sender.doubleValue
            if parent.step > 0 {
                val = (val / parent.step).rounded() * parent.step
                val = max(parent.range.lowerBound, min(parent.range.upperBound, val))
            }
            if abs(parent.value - val) > 0.0001 {
                parent.value = val
            }
        }
    }
}

// MARK: - Sampling Slider (Full-Window-Extent Native Slider with Custom Input Field)
public struct SamplingSlider: View {
    public let title: String
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let step: Double
    public let format: String

    @State private var textValue: String = ""
    @FocusState private var isFieldFocused: Bool

    public init(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Spacer()
                TextField("", text: $textValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 65)
                    .focused($isFieldFocused)
                    .onChange(of: textValue) { newValue in
                        if isFieldFocused {
                            parseAndApply(newValue)
                        }
                    }
                    .onSubmit {
                        commitText()
                    }
            }

            NativeMacSlider(value: $value, range: range, step: step)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
        }
        .padding(.vertical, 3)
        .onAppear {
            updateTextFromValue()
        }
        .onChange(of: value) { _ in
            if !isFieldFocused {
                updateTextFromValue()
            }
        }
    }

    private func updateTextFromValue() {
        textValue = String(format: format, value)
    }

    private func parseAndApply(_ input: String) {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let val = Double(cleaned) {
            let clamped = max(range.lowerBound, min(range.upperBound, val))
            if abs(value - clamped) > 0.0001 {
                value = clamped
            }
        }
    }

    private func commitText() {
        parseAndApply(textValue)
        updateTextFromValue()
    }
}

public typealias LiquidGlassSlider = SamplingSlider

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updateManager = UpdateManager.shared

    public enum SettingsTab: String, Hashable, CaseIterable {
        case general = "General"
        case advanced = "Advanced"
        case updates = "Updates"

        var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .advanced: return "slider.horizontal.3"
            case .updates: return "arrow.triangle.2.circlepath"
            }
        }

        var iconColor: Color {
            switch self {
            case .general: return .gray
            case .advanced: return .indigo
            case .updates: return .teal
            }
        }

        var subtitle: String {
            switch self {
            case .general: return "Model paths, server configuration, Web UI, and app options"
            case .advanced: return "Hardware compute, GPU offload layers, context size, sampling parameters, and KV cache"
            case .updates: return "eLlama releases and llama.cpp Metal build updates"
            }
        }
    }

    private enum SettingsField: Hashable {
        case modelsDirectory
        case llamaCli
        case llamaServer
        case serverPort
        case contextSize
        case maxTokens
    }

    var targetModel: ModelInfo?
    var initialTab: SettingsTab = .general
    var isServeMode: Bool = false
    var onSave: (() -> Void)?
    var onRunModel: ((ModelInfo) -> Void)?
    var onServeModel: ((ModelInfo) -> Void)?

    @State private var selectedTab: SettingsTab = .general
    @FocusState private var focusedField: SettingsField?

    // Local form state
    @State private var modelsDirectory: String = ""
    @State private var llamaCliPath: String = ""
    @State private var hideProjectors: Bool = true
    @State private var closeToTray: Bool = false
    @State private var suppressNoModelsAlert: Bool = false
    @State private var warnMemoryUsage: Bool = true
    @State private var memoryWarnThreshold: Int = 95
    @State private var isDefaultGgufHandler: Bool = false

    @State private var serverHost: String = "127.0.0.1"
    @State private var serverPort: Int = 8080
    @State private var serverPortString: String = "8080"
    @State private var llamaServerPath: String = ""
    @State private var enableWebUI: Bool = true
    @State private var copiedServerUrl: Bool = false

    private var liveServerPortString: String {
        let digits = serverPortString.filter { $0.isNumber }
        if let p = Int(digits), p >= 1, p <= 65535 {
            return "\(p)"
        }
        return "\(serverPort)"
    }

    private var liveServerUrl: String {
        "http://\(serverHost):\(liveServerPortString)"
    }

    @State private var threads: Int = 4
    @State private var gpuLayers: Int = 99
    @State private var contextSize: Int = 8192
    @State private var contextSizeString: String = "8192"
    @State private var batchSize: Int = 512
    @State private var uBatchSize: Int = 512

    @State private var cacheTypeK: String = "f16"
    @State private var cacheTypeV: String = "f16"
    @State private var flashAttention: String = "auto"
    @State private var mlock: Bool = false
    @State private var noMMap: Bool = false

    @State private var temperature: Double = 0.80
    @State private var topP: Double = 0.95
    @State private var topK: Int = 40
    @State private var minP: Double = 0.05
    @State private var repeatPenalty: Double = 1.10
    @State private var repeatLastN: Int = 64
    @State private var maxTokens: Int = -1
    @State private var maxTokensString: String = "-1"

    @State private var checkForELlamaUpdates: Bool = true
    @State private var checkForLlamaCppUpdates: Bool = true
    @State private var installedLlamaVersion: String = ""

    public init(
        targetModel: ModelInfo? = nil,
        initialTab: SettingsTab = .general,
        isServeMode: Bool = false,
        onSave: (() -> Void)? = nil,
        onRunModel: ((ModelInfo) -> Void)? = nil,
        onServeModel: ((ModelInfo) -> Void)? = nil
    ) {
        self.targetModel = targetModel
        self.initialTab = initialTab
        self.isServeMode = isServeMode
        self._selectedTab = State(initialValue: initialTab)
        self.onSave = onSave
        self.onRunModel = onRunModel
        self.onServeModel = onServeModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Tab Bar (Classic macOS Preferences Layout)
            HStack(spacing: 28) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 22))
                                .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                                .frame(height: 24)

                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(selectedTab == tab ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18) : Color.clear)
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Form Content
            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .advanced:
                    advancedTab
                case .updates:
                    updatesTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Action Footer
            HStack(spacing: 12) {
                Button("Reset Tab Defaults") {
                    resetCurrentTabDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Reset settings on this tab to default values")

                Button("Reset All...") {
                    resetAllDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Reset every setting to default values")

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if let model = targetModel {
                    if isServeMode {
                        Button(action: {
                            saveSettings()
                            onSave?()
                            dismiss()
                            onServeModel?(model)
                        }) {
                            Label("Serve Model", systemImage: "network")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)

                        Button(action: {
                            saveSettings()
                            onSave?()
                            dismiss()
                            onRunModel?(model)
                        }) {
                            Label("Run Chat", systemImage: "play.fill")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: {
                            saveSettings()
                            onSave?()
                            dismiss()
                            onRunModel?(model)
                        }) {
                            Label("Run Model", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)

                        Button(action: {
                            saveSettings()
                            onSave?()
                            dismiss()
                            onServeModel?(model)
                        }) {
                            Label("Serve", systemImage: "network")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("Save") {
                        saveSettings()
                        onSave?()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 580, idealWidth: 620, maxWidth: 720, minHeight: 480, idealHeight: 520, maxHeight: 660)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onAppear {
            selectedTab = initialTab
            loadFromSettings()
            focusedField = nil
            DispatchQueue.main.async {
                focusedField = nil
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }

    // MARK: - Tabs
    private var generalTab: some View {
        Form {
            if !settings.lastServerUrl.isEmpty || isServeMode {
                Section("Active Server & Web UI") {
                    let serverUrlString = settings.lastServerUrl.isEmpty ? liveServerUrl : settings.lastServerUrl

                    LabeledContent("Web UI Link") {
                        CopyableUrlField(urlString: serverUrlString, isWebUiEnabled: enableWebUI)
                    }

                    if !settings.lastServedModelName.isEmpty {
                        Text("Active Model: \(settings.lastServedModelName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Paths & Binaries") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Models Directory")
                        .font(.subheadline.weight(.medium))
                    HStack {
                        TextField("Path to models folder", text: $modelsDirectory)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .modelsDirectory)
                        Button("Browse...") {
                            browseFolder()
                        }
                    }
                    Text("Resolved: \(AppSettings.resolvePath(modelsDirectory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("llama-cli Executable")
                        .font(.subheadline.weight(.medium))
                    HStack {
                        TextField("Path to llama-cli", text: $llamaCliPath)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .llamaCli)
                        Button("Browse...") {
                            browseExecutable()
                        }
                    }
                    Text("Resolved: \(AppSettings.resolvePath(llamaCliPath))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("llama-server Executable")
                            .font(.subheadline.weight(.medium))
                        Text("(Leave blank to auto-detect)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        TextField("Path to llama-server", text: $llamaServerPath)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .llamaServer)
                        Button("Browse...") {
                            browseServerExecutable()
                        }
                    }
                    Text("Resolved: \(AppSettings.resolvePath(llamaServerPath.isEmpty ? settings.resolvedLlamaServerPath : llamaServerPath))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Server Configuration") {
                Toggle("Enable Web UI (--webui)", isOn: $enableWebUI)
                    .help("Enable llama-server built-in browser interface")

                LabeledContent("Web UI Link") {
                    CopyableUrlField(urlString: liveServerUrl, isWebUiEnabled: enableWebUI)
                }

                Picker("Host", selection: $serverHost) {
                    Text("127.0.0.1 (Localhost only)").tag("127.0.0.1")
                    Text("0.0.0.0 (All Interfaces)").tag("0.0.0.0")
                }

                LabeledContent("Port") {
                    HStack(spacing: 4) {
                        TextField("", text: $serverPortString, prompt: Text("8080"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .serverPort)
                            .onChange(of: serverPortString) { newValue in
                                syncPort(from: newValue)
                            }
                            .onSubmit {
                                formatPortOnSubmit()
                            }
                            .accessibilityLabel("Server port number")
                        Stepper("", onIncrement: {
                            if serverPort < 65535 {
                                serverPort += 1
                                serverPortString = "\(serverPort)"
                            }
                        }, onDecrement: {
                            if serverPort > 1 {
                                serverPort -= 1
                                serverPortString = "\(serverPort)"
                            }
                        })
                        .labelsHidden()
                        .accessibilityLabel("Server port adjustment")
                    }
                }
            }

            Section("Application Options") {
                Toggle("Hide Vision Projectors (mmproj)", isOn: $hideProjectors)
                Toggle("Close to Menu Bar / System Tray", isOn: $closeToTray)
                Toggle("Don't show alert when no models are found", isOn: $suppressNoModelsAlert)

                Toggle("Warn before launching high-memory models", isOn: $warnMemoryUsage)
                    .help("Show a confirmation when the estimated memory is near or above the system limit")

                if warnMemoryUsage {
                    LabeledContent("Warning threshold") {
                        HStack(spacing: 4) {
                            TextField("", value: $memoryWarnThreshold, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 55)
                                .multilineTextAlignment(.trailing)
                            Text("% of system memory")
                                .foregroundColor(.secondary)
                            Stepper("", onIncrement: {
                                if memoryWarnThreshold < 100 { memoryWarnThreshold += 1 }
                            }, onDecrement: {
                                if memoryWarnThreshold > 50 { memoryWarnThreshold -= 1 }
                            })
                            .labelsHidden()
                        }
                    }
                }

                LabeledContent("Default .gguf App") {
                    if isDefaultGgufHandler {
                        Label("eLlama", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Button("Set as Default") {
                            FileAssociation.shared.setAsDefaultHandler { success in
                                if success {
                                    isDefaultGgufHandler = FileAssociation.shared.isDefaultHandler
                                }
                            }
                        }
                        .controlSize(.small)
                    }
                }
                Text("When set, double-clicking a .gguf model opens and runs it with eLlama.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var advancedTab: some View {
        Form {
            Section("Compute & Metal Offloading") {
                LabeledContent("CPU Threads") {
                    HStack(spacing: 4) {
                        TextField("", value: $threads, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 55)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("CPU Threads count")
                        Stepper("", onIncrement: {
                            if threads < 64 { threads += 1 }
                        }, onDecrement: {
                            if threads > 1 { threads -= 1 }
                        })
                        .labelsHidden()
                        .accessibilityLabel("CPU Threads adjustment")
                    }
                }

                LabeledContent("GPU Offload Layers (Metal)") {
                    HStack(spacing: 6) {
                        Button("Max (99)") {
                            gpuLayers = 99
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Set GPU Offload Layers to maximum 99")

                        TextField("", value: $gpuLayers, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 55)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("GPU Offload Layers count")

                        Stepper("", onIncrement: {
                            if gpuLayers < 999 { gpuLayers += 1 }
                        }, onDecrement: {
                            if gpuLayers > 0 { gpuLayers -= 1 }
                        })
                        .labelsHidden()
                        .accessibilityLabel("GPU Offload Layers adjustment")
                    }
                }

                Text("Tip: On Apple Silicon with unified memory, 99 layers offloads all computation to the Metal GPU.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Context & Batching") {
                LabeledContent {
                    HStack(spacing: 6) {
                        TextField("", text: $contextSizeString, prompt: Text("e.g. 16384 or 16K"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 110)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .contextSize)
                            .onSubmit {
                                contextSize = parseContextSize(contextSizeString)
                                contextSizeString = "\(contextSize)"
                            }

                        Menu {
                            Button("2,048 (2K)") { setContextPreset(2048) }
                            Button("4,096 (4K)") { setContextPreset(4096) }
                            Button("8,192 (8K) - Recommended") { setContextPreset(8192) }
                            Button("16,384 (16K)") { setContextPreset(16384) }
                            Button("24,576 (24K)") { setContextPreset(24576) }
                            Button("32,768 (32K)") { setContextPreset(32768) }
                            Button("65,536 (64K)") { setContextPreset(65536) }
                            Button("131,072 (128K)") { setContextPreset(131072) }
                        } label: {
                            Text("Presets")
                        }
                        .menuStyle(.borderedButton)
                        .controlSize(.small)
                        .fixedSize()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Context Size")
                        if contextSize >= 1024 {
                            Text("\(contextSize / 1024)K tokens (\(contextSize) tokens)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Picker("Logical Batch Size (-b)", selection: $batchSize) {
                    Text("128").tag(128)
                    Text("256").tag(256)
                    Text("512 (Default)").tag(512)
                    Text("1024").tag(1024)
                    Text("2048").tag(2048)
                }

                Picker("Physical Batch Size (-ub)", selection: $uBatchSize) {
                    Text("128").tag(128)
                    Text("256").tag(256)
                    Text("512 (Default)").tag(512)
                    Text("1024").tag(1024)
                }
            }

            Section("Sampling Parameters") {
                SamplingSlider(
                    title: "Temperature",
                    value: $temperature,
                    range: 0.0...2.0,
                    step: 0.05,
                    format: "%.2f"
                )

                SamplingSlider(
                    title: "Top-P",
                    value: $topP,
                    range: 0.0...1.0,
                    step: 0.05,
                    format: "%.2f"
                )

                SamplingSlider(
                    title: "Top-K",
                    value: Binding(
                        get: { Double(topK) },
                        set: { topK = Int($0) }
                    ),
                    range: 0...200,
                    step: 1.0,
                    format: "%.0f"
                )

                SamplingSlider(
                    title: "Min-P",
                    value: $minP,
                    range: 0.0...1.0,
                    step: 0.01,
                    format: "%.2f"
                )

                SamplingSlider(
                    title: "Repeat Penalty",
                    value: $repeatPenalty,
                    range: 1.0...2.0,
                    step: 0.05,
                    format: "%.2f"
                )

                SamplingSlider(
                    title: "Repeat Last N",
                    value: Binding(
                        get: { Double(repeatLastN) },
                        set: { repeatLastN = Int($0) }
                    ),
                    range: 0...512,
                    step: 1.0,
                    format: "%.0f"
                )
            }

            Section("Token Limit") {
                LabeledContent("Max Tokens (-n)") {
                    HStack(spacing: 8) {
                        TextField("", text: $maxTokensString, prompt: Text("-1"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .maxTokens)
                            .onSubmit {
                                syncMaxTokens()
                            }
                        Text(maxTokens <= 0 ? "Unlimited" : "\(maxTokens)")
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                    }
                }
            }

            Section("KV Cache Quantization") {
                Picker("Cache Type K (-ctk)", selection: $cacheTypeK) {
                    Text("f16 (Full Precision)").tag("f16")
                    Text("q8_0 (Balanced)").tag("q8_0")
                    Text("q4_0 (Memory Efficient)").tag("q4_0")
                    Text("q4_1").tag("q4_1")
                    Text("q5_0").tag("q5_0")
                    Text("q5_1").tag("q5_1")
                }

                Picker("Cache Type V (-ctv)", selection: $cacheTypeV) {
                    Text("f16 (Full Precision)").tag("f16")
                    Text("q8_0 (Balanced)").tag("q8_0")
                    Text("q4_0 (Memory Efficient)").tag("q4_0")
                    Text("q4_1").tag("q4_1")
                    Text("q5_0").tag("q5_0")
                    Text("q5_1").tag("q5_1")
                }

                Picker("Flash Attention (-fa)", selection: $flashAttention) {
                    Text("auto (Recommended)").tag("auto")
                    Text("on (Enabled)").tag("on")
                    Text("off (Disabled)").tag("off")
                }
            }

            Section("Memory Locking") {
                Toggle("Lock model in RAM (--mlock)", isOn: $mlock)
                Toggle("Disable memory mapping (--no-mmap)", isOn: $noMMap)
            }
        }
        .formStyle(.grouped)
    }

    private var updatesTab: some View {
        Form {
            Section("eLlama Updates") {
                Toggle("Check for eLlama updates on startup", isOn: $checkForELlamaUpdates)

                LabeledContent("Current Version") {
                    Text("v\(UpdateManager.currentELlamaVersion)")
                }

                LabeledContent {
                    Button(action: { checkELlamaUpdate() }) {
                        if updateManager.isCheckingELlama {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(updateManager.eLlamaUpdateStatus)
                        }
                    }
                    .disabled(updateManager.isCheckingELlama)
                } label: {
                    Text("")
                }
            }

            Section("llama.cpp Backend (Metal)") {
                Toggle("Check for llama.cpp updates on startup", isOn: $checkForLlamaCppUpdates)

                LabeledContent("Installed Build") {
                    Text(installedLlamaVersion.isEmpty ? "Unknown" : installedLlamaVersion)
                }

                LabeledContent {
                    Button(action: { updateLlamaCpp() }) {
                        if updateManager.isDownloadingLlamaCpp {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(updateManager.llamaCppUpdateStatus)
                        }
                    }
                    .disabled(updateManager.isDownloadingLlamaCpp)
                } label: {
                    Text("")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions
    private func parseContextSize(_ input: String) -> Int {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleaned.lowercased().hasSuffix("k") {
            let numberPart = String(cleaned.dropLast())
            if let kVal = Double(numberPart) {
                return max(512, Int(kVal * 1024))
            }
        }
        if let val = Int(cleaned) {
            return max(512, val)
        }
        return contextSize
    }

    private func setContextPreset(_ size: Int) {
        contextSize = size
        contextSizeString = "\(size)"
    }

    private func syncMaxTokens() {
        let cleaned = maxTokensString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        if cleaned == "-1" || cleaned.lowercased() == "unlimited" || cleaned.isEmpty {
            maxTokens = -1
            maxTokensString = "-1"
        } else if let val = Int(cleaned) {
            maxTokens = val
            maxTokensString = "\(val)"
        }
    }

    private func syncPort(from text: String? = nil) {
        let input = text ?? serverPortString
        let digits = input.filter { $0.isNumber }
        if let val = Int(digits), val >= 1, val <= 65535 {
            serverPort = val
        }
    }

    private func formatPortOnSubmit() {
        let digits = serverPortString.filter { $0.isNumber }
        if let val = Int(digits), val >= 1, val <= 65535 {
            serverPort = val
            serverPortString = "\(val)"
        } else {
            serverPortString = "\(serverPort)"
        }
    }

    private func loadFromSettings() {
        modelsDirectory = settings.modelsDirectory
        llamaCliPath = settings.llamaCliPath
        hideProjectors = settings.hideProjectors
        closeToTray = settings.closeToTray
        suppressNoModelsAlert = settings.suppressNoModelsAlert
        warnMemoryUsage = !settings.suppressMemoryWarning
        memoryWarnThreshold = settings.memoryWarnThresholdPercent

        serverHost = settings.serverHost
        serverPort = settings.serverPort
        serverPortString = "\(settings.serverPort)"
        llamaServerPath = settings.llamaServerPath
        enableWebUI = settings.enableWebUI

        threads = settings.threads
        gpuLayers = settings.gpuLayers
        contextSize = settings.contextSize
        contextSizeString = "\(settings.contextSize)"
        batchSize = settings.batchSize
        uBatchSize = settings.uBatchSize

        cacheTypeK = settings.cacheTypeK
        cacheTypeV = settings.cacheTypeV
        flashAttention = settings.flashAttention
        mlock = settings.mlock
        noMMap = settings.noMMap

        temperature = settings.temperature
        topP = settings.topP
        topK = settings.topK
        minP = settings.minP
        repeatPenalty = settings.repeatPenalty
        repeatLastN = settings.repeatLastN
        maxTokens = settings.maxTokens
        maxTokensString = settings.maxTokens <= 0 ? "-1" : "\(settings.maxTokens)"

        checkForELlamaUpdates = settings.checkForELlamaUpdates
        checkForLlamaCppUpdates = settings.checkForLlamaCppUpdates
        installedLlamaVersion = UpdateManager.shared.detectInstalledLlamaCppBuild()
        isDefaultGgufHandler = FileAssociation.shared.isDefaultHandler
    }

    private func saveSettings() {
        contextSize = parseContextSize(contextSizeString)
        if let p = Int(serverPortString.filter({ $0.isNumber })) {
            serverPort = min(65535, max(1, p))
        }
        let cleanTokens = maxTokensString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTokens == "-1" || cleanTokens.lowercased() == "unlimited" {
            maxTokens = -1
        } else if let t = Int(cleanTokens.filter({ $0.isNumber || $0 == "-" })) {
            maxTokens = t
        }

        settings.modelsDirectory = modelsDirectory
        settings.llamaCliPath = llamaCliPath
        settings.hideProjectors = hideProjectors
        settings.closeToTray = closeToTray
        settings.suppressNoModelsAlert = suppressNoModelsAlert
        settings.suppressMemoryWarning = !warnMemoryUsage
        settings.memoryWarnThresholdPercent = min(100, max(50, memoryWarnThreshold))

        settings.serverHost = serverHost
        settings.serverPort = serverPort
        settings.llamaServerPath = llamaServerPath
        settings.enableWebUI = enableWebUI

        settings.threads = threads
        settings.gpuLayers = gpuLayers
        settings.contextSize = contextSize
        settings.batchSize = batchSize
        settings.uBatchSize = uBatchSize

        settings.cacheTypeK = cacheTypeK
        settings.cacheTypeV = cacheTypeV
        settings.flashAttention = flashAttention
        settings.mlock = mlock
        settings.noMMap = noMMap

        settings.temperature = temperature
        settings.topP = topP
        settings.topK = topK
        settings.minP = minP
        settings.repeatPenalty = repeatPenalty
        settings.repeatLastN = repeatLastN
        settings.maxTokens = maxTokens

        settings.checkForELlamaUpdates = checkForELlamaUpdates
        settings.checkForLlamaCppUpdates = checkForLlamaCppUpdates

        settings.save()
    }

    private func resetCurrentTabDefaults() {
        switch selectedTab {
        case .general:
            settings.resetGeneralDefaults()
            modelsDirectory = settings.modelsDirectory
            llamaCliPath = settings.llamaCliPath
            llamaServerPath = settings.llamaServerPath
            serverHost = settings.serverHost
            serverPort = settings.serverPort
            serverPortString = "\(settings.serverPort)"
            enableWebUI = settings.enableWebUI
            hideProjectors = settings.hideProjectors
            closeToTray = settings.closeToTray
            suppressNoModelsAlert = settings.suppressNoModelsAlert
            warnMemoryUsage = !settings.suppressMemoryWarning
            memoryWarnThreshold = settings.memoryWarnThresholdPercent

        case .advanced:
            settings.resetAdvancedDefaults()
            threads = settings.threads
            gpuLayers = settings.gpuLayers
            contextSize = settings.contextSize
            contextSizeString = "\(settings.contextSize)"
            batchSize = settings.batchSize
            uBatchSize = settings.uBatchSize
            temperature = settings.temperature
            topP = settings.topP
            topK = settings.topK
            minP = settings.minP
            repeatPenalty = settings.repeatPenalty
            repeatLastN = settings.repeatLastN
            maxTokens = settings.maxTokens
            maxTokensString = settings.maxTokens <= 0 ? "-1" : "\(settings.maxTokens)"
            cacheTypeK = settings.cacheTypeK
            cacheTypeV = settings.cacheTypeV
            flashAttention = settings.flashAttention
            mlock = settings.mlock
            noMMap = settings.noMMap

        case .updates:
            settings.resetUpdatesDefaults()
            checkForELlamaUpdates = settings.checkForELlamaUpdates
            checkForLlamaCppUpdates = settings.checkForLlamaCppUpdates
        }
    }

    private func resetAllDefaults() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings to defaults?"
        alert.informativeText = "Every setting (paths, server, compute, sampling, updates, and warnings) will be restored to its default value."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset All")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        settings.resetToDefaults()
        loadFromSettings()
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Models Folder"

        if panel.runModal() == .OK, let url = panel.url {
            modelsDirectory = url.path
        }
    }

    private func browseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select llama-cli"

        if panel.runModal() == .OK, let url = panel.url {
            llamaCliPath = url.path
        }
    }

    private func browseServerExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select llama-server"

        if panel.runModal() == .OK, let url = panel.url {
            llamaServerPath = url.path
        }
    }

    private func checkELlamaUpdate() {
        updateManager.checkELlamaUpdate()
    }

    private func updateLlamaCpp() {
        updateManager.installLlamaCpp {
            Task { @MainActor in
                self.installedLlamaVersion = UpdateManager.shared.detectInstalledLlamaCppBuild()
            }
        }
    }
}
