import SwiftUI
import AppKit

public struct ModelLoadPrefsViewerWindow: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = AppSettings.shared

    public let model: ModelInfo
    public let isServeMode: Bool
    public var onLaunch: (() -> Void)?

    private enum Field: Hashable {
        case serverPort
        case contextSize
        case maxTokens
        case llamaServer
    }

    @FocusState private var focusedField: Field?

    // Server configuration state
    @State private var enableWebUI: Bool = true
    @State private var serverHost: String = "127.0.0.1"
    @State private var serverPort: Int = 8080
    @State private var serverPortString: String = "8080"
    @State private var llamaServerPath: String = ""

    // Compute state
    @State private var threads: Int = 4
    @State private var gpuLayers: Int = 99

    // Context & Batching state
    @State private var contextSize: Int = 8192
    @State private var contextSizeString: String = "8192"
    @State private var batchSize: Int = 512
    @State private var uBatchSize: Int = 512

    // Sampling state
    @State private var temperature: Double = 0.80
    @State private var topP: Double = 0.95
    @State private var topK: Int = 40
    @State private var minP: Double = 0.05
    @State private var repeatPenalty: Double = 1.10
    @State private var repeatLastN: Int = 64

    // Token limit
    @State private var maxTokens: Int = -1
    @State private var maxTokensString: String = "-1"

    // KV Cache & Memory
    @State private var cacheTypeK: String = "f16"
    @State private var cacheTypeV: String = "f16"
    @State private var flashAttention: String = "auto"
    @State private var mlock: Bool = false
    @State private var noMMap: Bool = false

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

    private var memoryEstimate: MemoryEstimate {
        MemoryEstimator.shared.estimate(
            modelSizeBytes: model.sizeBytes,
            quant: model.quant,
            contextSize: contextSize,
            uBatchSize: uBatchSize,
            cacheTypeK: cacheTypeK,
            cacheTypeV: cacheTypeV
        )
    }

    private var memoryVerdict: MemoryVerdict {
        MemoryEstimator.shared.verdict(
            for: memoryEstimate,
            thresholdPercent: settings.memoryWarnThresholdPercent
        )
    }

    private var memoryColor: Color {
        switch memoryVerdict {
        case .ok: return .green
        case .near: return .orange
        case .over: return .red
        }
    }

    public init(model: ModelInfo, isServeMode: Bool = true, onLaunch: (() -> Void)? = nil) {
        self.model = model
        self.isServeMode = isServeMode
        self.onLaunch = onLaunch
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Mode Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(isServeMode ? "SERVE MODE" : "RUN MODE")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.12, green: 0.44, blue: 0.88).opacity(0.85))
                        )

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    Text(model.quant)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.tertiaryLabelColor).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(model.modelName)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(model.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Form Content
            Form {
                if isServeMode {
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
                        .disabled(!enableWebUI)

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
                            }
                        }
                        .disabled(!enableWebUI)

                        VStack(alignment: .leading, spacing: 4) {
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
                }

                Section("Compute & Metal Offloading") {
                    LabeledContent("CPU Threads") {
                        HStack(spacing: 4) {
                            TextField("", value: $threads, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 55)
                                .multilineTextAlignment(.trailing)
                            Stepper("", onIncrement: {
                                if threads < 64 { threads += 1 }
                            }, onDecrement: {
                                if threads > 1 { threads -= 1 }
                            })
                            .labelsHidden()
                        }
                    }

                    LabeledContent("GPU Offload Layers (Metal)") {
                        HStack(spacing: 6) {
                            Button("Max (99)") {
                                gpuLayers = 99
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            TextField("", value: $gpuLayers, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 55)
                                .multilineTextAlignment(.trailing)

                            Stepper("", onIncrement: {
                                if gpuLayers < 999 { gpuLayers += 1 }
                            }, onDecrement: {
                                if gpuLayers > 0 { gpuLayers -= 1 }
                            })
                            .labelsHidden()
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

                    LabeledContent("Estimated Memory") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(memoryColor)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text("\(ModelInfo.formatBytes(memoryEstimate.totalBytes)) of \(ModelInfo.formatBytes(memoryEstimate.limitBytes))")
                                .font(.system(.body, design: .monospaced))
                            Text("(\(Int(memoryEstimate.fraction * 100))%)")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Estimated memory \(ModelInfo.formatBytes(memoryEstimate.totalBytes)) of \(ModelInfo.formatBytes(memoryEstimate.limitBytes))")
                    }

                    Text("Rough estimate: model weights + KV cache + compute buffer versus total system memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

            Divider()

            // Footer
            HStack(spacing: 12) {
                Button("Reset Defaults") {
                    resetDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Reset parameters to default values")

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if isServeMode {
                    Button(action: {
                        saveToSettings()
                        dismiss()
                        onLaunch?()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "network")
                            Text("Serve Model")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(action: {
                        saveToSettings()
                        dismiss()
                        onLaunch?()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                            Text("Run Model")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 640, maxWidth: 740, minHeight: 560, idealHeight: 620, maxHeight: 760)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onAppear {
            loadFromSettings()
        }
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

    private func loadFromSettings() {
        enableWebUI = settings.enableWebUI
        serverHost = settings.serverHost
        serverPort = settings.serverPort
        serverPortString = "\(settings.serverPort)"
        llamaServerPath = settings.llamaServerPath

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
    }

    private func saveToSettings() {
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

        settings.enableWebUI = enableWebUI
        settings.serverHost = serverHost
        settings.serverPort = serverPort
        settings.llamaServerPath = llamaServerPath

        settings.threads = threads
        settings.gpuLayers = gpuLayers
        settings.contextSize = contextSize
        settings.batchSize = batchSize
        settings.uBatchSize = uBatchSize

        settings.temperature = temperature
        settings.topP = topP
        settings.topK = topK
        settings.minP = minP
        settings.repeatPenalty = repeatPenalty
        settings.repeatLastN = repeatLastN
        settings.maxTokens = maxTokens

        settings.cacheTypeK = cacheTypeK
        settings.cacheTypeV = cacheTypeV
        settings.flashAttention = flashAttention
        settings.mlock = mlock
        settings.noMMap = noMMap

        settings.save()
    }

    private func resetDefaults() {
        settings.resetAdvancedDefaults()
        settings.resetGeneralDefaults()

        enableWebUI = settings.enableWebUI
        serverHost = settings.serverHost
        serverPort = settings.serverPort
        serverPortString = "\(settings.serverPort)"
        llamaServerPath = settings.llamaServerPath

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
    }
}
