import SwiftUI
import AppKit

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = AppSettings.shared

    var onSave: (() -> Void)?

    // Local form state
    @State private var modelsDirectory: String = ""
    @State private var llamaCliPath: String = ""
    @State private var hideProjectors: Bool = true
    @State private var closeToTray: Bool = false

    @State private var threads: Int = 4
    @State private var gpuLayers: Int = 99
    @State private var contextSize: Int = 8192
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

    @State private var checkForELlamaUpdates: Bool = true
    @State private var checkForLlamaCppUpdates: Bool = true
    @State private var installedLlamaVersion: String = ""

    // Updater UI states
    @State private var eLlamaUpdateStatus: String = "Check for Updates"
    @State private var isCheckingELlama: Bool = false
    @State private var llamaCppUpdateStatus: String = "Download Latest llama.cpp (Metal)"
    @State private var isDownloadingLlamaCpp: Bool = false

    public init(onSave: (() -> Void)? = nil) {
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                hardwareTab
                    .tabItem { Label("Hardware & Compute", systemImage: "cpu") }
                kvCacheTab
                    .tabItem { Label("KV Cache & Memory", systemImage: "memorychip") }
                samplingTab
                    .tabItem { Label("Sampling", systemImage: "slider.horizontal.3") }
                updatesTab
                    .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
            }
            .padding(16)

            Divider()

            HStack {
                Button("Reset Defaults") {
                    resetDefaults()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    saveSettings()
                    onSave?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 640, height: 540)
        .onAppear {
            loadFromSettings()
        }
    }

    // MARK: - Tabs
    private var generalTab: some View {
        Form {
            Section("Paths") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Models Directory:")
                        .font(.headline)
                    HStack {
                        TextField("Path to models folder", text: $modelsDirectory)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseFolder()
                        }
                    }
                    Text("Resolved: \(AppSettings.resolvePath(modelsDirectory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("llama-cli Executable:")
                        .font(.headline)
                    HStack {
                        TextField("Path to llama-cli", text: $llamaCliPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseExecutable()
                        }
                    }
                    Text("Resolved: \(AppSettings.resolvePath(llamaCliPath))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Application Options") {
                Toggle("Hide Vision Projectors (mmproj)", isOn: $hideProjectors)
                Toggle("Close to Menu Bar / System Tray", isOn: $closeToTray)
            }
        }
        .formStyle(.grouped)
    }

    private var hardwareTab: some View {
        Form {
            Section("Compute & Metal Offloading") {
                Stepper("CPU Threads: \(threads)", value: $threads, in: 1...64)
                Stepper("GPU Offload Layers (Metal): \(gpuLayers)", value: $gpuLayers, in: 0...999)
                Text("Tip: On Apple Silicon with unified memory, 99 layers offloads all computation to the Metal GPU.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Context & Batching") {
                Picker("Context Size:", selection: $contextSize) {
                    Text("2048").tag(2048)
                    Text("4096").tag(4096)
                    Text("8192 (Recommended)").tag(8192)
                    Text("16384").tag(16384)
                    Text("32768").tag(32768)
                    Text("65536").tag(65536)
                    Text("131072").tag(131072)
                }

                Picker("Logical Batch Size (-b):", selection: $batchSize) {
                    Text("128").tag(128)
                    Text("256").tag(256)
                    Text("512 (Default)").tag(512)
                    Text("1024").tag(1024)
                    Text("2048").tag(2048)
                }

                Picker("Physical Batch Size (-ub):", selection: $uBatchSize) {
                    Text("128").tag(128)
                    Text("256").tag(256)
                    Text("512 (Default)").tag(512)
                    Text("1024").tag(1024)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var kvCacheTab: some View {
        Form {
            Section("KV Cache Quantization") {
                Picker("Cache Type K (-ctk):", selection: $cacheTypeK) {
                    Text("f16 (Full Precision)").tag("f16")
                    Text("q8_0 (Balanced)").tag("q8_0")
                    Text("q4_0 (Memory Efficient)").tag("q4_0")
                    Text("q4_1").tag("q4_1")
                    Text("q5_0").tag("q5_0")
                    Text("q5_1").tag("q5_1")
                }

                Picker("Cache Type V (-ctv):", selection: $cacheTypeV) {
                    Text("f16 (Full Precision)").tag("f16")
                    Text("q8_0 (Balanced)").tag("q8_0")
                    Text("q4_0 (Memory Efficient)").tag("q4_0")
                    Text("q4_1").tag("q4_1")
                    Text("q5_0").tag("q5_0")
                    Text("q5_1").tag("q5_1")
                }

                Picker("Flash Attention (-fa):", selection: $flashAttention) {
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

    private var samplingTab: some View {
        Form {
            Section("Sampling Parameters") {
                HStack {
                    Text("Temperature: \(String(format: "%.2f", temperature))")
                    Slider(value: $temperature, in: 0.0...2.0, step: 0.05)
                }

                HStack {
                    Text("Top-P: \(String(format: "%.2f", topP))")
                    Slider(value: $topP, in: 0.0...1.0, step: 0.05)
                }

                Stepper("Top-K: \(topK)", value: $topK, in: 0...200)

                HStack {
                    Text("Min-P: \(String(format: "%.2f", minP))")
                    Slider(value: $minP, in: 0.0...1.0, step: 0.01)
                }

                HStack {
                    Text("Repeat Penalty: \(String(format: "%.2f", repeatPenalty))")
                    Slider(value: $repeatPenalty, in: 1.0...2.0, step: 0.05)
                }

                Stepper("Repeat Last N: \(repeatLastN)", value: $repeatLastN, in: 0...512)

                HStack {
                    Text("Max Tokens (-n):")
                    TextField("-1 for unlimited", value: $maxTokens, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var updatesTab: some View {
        Form {
            Section("eLlama Updates") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Version: v\(UpdateManager.currentELlamaVersion)")
                            .font(.headline)
                        Toggle("Check for eLlama updates on startup", isOn: $checkForELlamaUpdates)
                    }
                    Spacer()
                    Button(action: { checkELlamaUpdate() }) {
                        if isCheckingELlama {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Text(eLlamaUpdateStatus)
                        }
                    }
                    .disabled(isCheckingELlama)
                }
            }

            Section("llama.cpp Backend (Metal)") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Installed Build: \(installedLlamaVersion.isEmpty ? "Unknown" : installedLlamaVersion)")
                            .font(.headline)
                        Toggle("Check for llama.cpp updates on startup", isOn: $checkForLlamaCppUpdates)
                    }
                    Spacer()
                    Button(action: { updateLlamaCpp() }) {
                        if isDownloadingLlamaCpp {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Text(llamaCppUpdateStatus)
                        }
                    }
                    .disabled(isDownloadingLlamaCpp)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions
    private func loadFromSettings() {
        modelsDirectory = settings.modelsDirectory
        llamaCliPath = settings.llamaCliPath
        hideProjectors = settings.hideProjectors
        closeToTray = settings.closeToTray

        threads = settings.threads
        gpuLayers = settings.gpuLayers
        contextSize = settings.contextSize
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

        checkForELlamaUpdates = settings.checkForELlamaUpdates
        checkForLlamaCppUpdates = settings.checkForLlamaCppUpdates
        installedLlamaVersion = UpdateManager.shared.detectInstalledLlamaCppBuild()
    }

    private func saveSettings() {
        settings.modelsDirectory = modelsDirectory
        settings.llamaCliPath = llamaCliPath
        settings.hideProjectors = hideProjectors
        settings.closeToTray = closeToTray

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

    private func resetDefaults() {
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

    private func checkELlamaUpdate() {
        isCheckingELlama = true
        Task {
            let res = await UpdateManager.shared.checkELlama()
            await MainActor.run {
                isCheckingELlama = false
                if res.hasUpdate, let downloadURL = res.assetDownloadURL {
                    eLlamaUpdateStatus = "Update Available: \(res.latestVersion)"
                    Task {
                        try? await UpdateManager.shared.downloadAndOpenELlamaUpdate(downloadURL: downloadURL)
                    }
                } else {
                    eLlamaUpdateStatus = "Latest is installed"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        eLlamaUpdateStatus = "Check for Updates"
                    }
                }
            }
        }
    }

    private func updateLlamaCpp() {
        isDownloadingLlamaCpp = true
        llamaCppUpdateStatus = "Downloading..."
        Task {
            do {
                _ = try await UpdateManager.shared.downloadAndInstallLlamaCpp { status in
                    DispatchQueue.main.async {
                        self.llamaCppUpdateStatus = status
                    }
                }
                await MainActor.run {
                    self.isDownloadingLlamaCpp = false
                    self.installedLlamaVersion = UpdateManager.shared.detectInstalledLlamaCppBuild()
                    self.llamaCppUpdateStatus = "Latest is installed"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.llamaCppUpdateStatus = "Download Latest llama.cpp (Metal)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingLlamaCpp = false
                    self.llamaCppUpdateStatus = "Update Failed"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.llamaCppUpdateStatus = "Download Latest llama.cpp (Metal)"
                    }
                }
            }
        }
    }
}
