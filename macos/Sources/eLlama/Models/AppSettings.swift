import Foundation
import Combine

public final class AppSettings: ObservableObject, Codable, @unchecked Sendable {
    public static let shared: AppSettings = AppSettings.load()

    // MARK: - General
    @Published public var modelsDirectory: String
    @Published public var llamaCliPath: String
    @Published public var hideProjectors: Bool
    @Published public var closeToTray: Bool

    // MARK: - Hardware & Compute
    @Published public var threads: Int
    @Published public var gpuLayers: Int
    @Published public var contextSize: Int
    @Published public var batchSize: Int
    @Published public var uBatchSize: Int

    // MARK: - KV Cache & Memory
    @Published public var cacheTypeK: String
    @Published public var cacheTypeV: String
    @Published public var flashAttention: String
    @Published public var mlock: Bool
    @Published public var noMMap: Bool

    // MARK: - Sampling & Generation
    @Published public var temperature: Double
    @Published public var topP: Double
    @Published public var topK: Int
    @Published public var minP: Double
    @Published public var repeatPenalty: Double
    @Published public var repeatLastN: Int
    @Published public var maxTokens: Int

    // MARK: - Updates
    @Published public var checkForELlamaUpdates: Bool
    @Published public var checkForLlamaCppUpdates: Bool
    @Published public var installedLlamaCppVersion: String

    // MARK: - CodingKeys
    enum CodingKeys: String, CodingKey {
        case modelsDirectory = "ModelsDirectory"
        case llamaCliPath = "LlamaCliPath"
        case hideProjectors = "HideProjectors"
        case closeToTray = "CloseToTray"
        case threads = "Threads"
        case gpuLayers = "GpuLayers"
        case contextSize = "ContextSize"
        case batchSize = "BatchSize"
        case uBatchSize = "UBatchSize"
        case cacheTypeK = "CacheTypeK"
        case cacheTypeV = "CacheTypeV"
        case flashAttention = "FlashAttention"
        case mlock = "MLock"
        case noMMap = "NoMMap"
        case temperature = "Temperature"
        case topP = "TopP"
        case topK = "TopK"
        case minP = "MinP"
        case repeatPenalty = "RepeatPenalty"
        case repeatLastN = "RepeatLastN"
        case maxTokens = "MaxTokens"
        case checkForELlamaUpdates = "CheckForELlamaUpdates"
        case checkForLlamaCppUpdates = "CheckForLlamaCppUpdates"
        case installedLlamaCppVersion = "InstalledLlamaCppVersion"
    }

    public init() {
        self.modelsDirectory = Self.defaultModelsDirectory()
        self.llamaCliPath = Self.defaultLlamaCliPath()
        self.hideProjectors = true
        self.closeToTray = false

        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        self.threads = max(1, min(cpuCount, 32))
        // Default to 99 layers on Apple Silicon to offload everything to Metal unified memory
        #if arch(arm64)
        self.gpuLayers = 99
        #else
        self.gpuLayers = 33
        #endif

        self.contextSize = 8192
        self.batchSize = 512
        self.uBatchSize = 512

        self.cacheTypeK = "f16"
        self.cacheTypeV = "f16"
        self.flashAttention = "auto"
        self.mlock = false
        self.noMMap = false

        self.temperature = 0.80
        self.topP = 0.95
        self.topK = 40
        self.minP = 0.05
        self.repeatPenalty = 1.10
        self.repeatLastN = 64
        self.maxTokens = -1

        self.checkForELlamaUpdates = true
        self.checkForLlamaCppUpdates = true
        self.installedLlamaCppVersion = ""
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.modelsDirectory = try container.decodeIfPresent(String.self, forKey: .modelsDirectory) ?? Self.defaultModelsDirectory()
        self.llamaCliPath = try container.decodeIfPresent(String.self, forKey: .llamaCliPath) ?? Self.defaultLlamaCliPath()
        self.hideProjectors = try container.decodeIfPresent(Bool.self, forKey: .hideProjectors) ?? true
        self.closeToTray = try container.decodeIfPresent(Bool.self, forKey: .closeToTray) ?? false

        let defaultThreads = max(1, min(ProcessInfo.processInfo.activeProcessorCount, 32))
        self.threads = try container.decodeIfPresent(Int.self, forKey: .threads) ?? defaultThreads
        #if arch(arm64)
        let defaultGpu = 99
        #else
        let defaultGpu = 33
        #endif
        self.gpuLayers = try container.decodeIfPresent(Int.self, forKey: .gpuLayers) ?? defaultGpu
        self.contextSize = try container.decodeIfPresent(Int.self, forKey: .contextSize) ?? 8192
        self.batchSize = try container.decodeIfPresent(Int.self, forKey: .batchSize) ?? 512
        self.uBatchSize = try container.decodeIfPresent(Int.self, forKey: .uBatchSize) ?? 512

        self.cacheTypeK = try container.decodeIfPresent(String.self, forKey: .cacheTypeK) ?? "f16"
        self.cacheTypeV = try container.decodeIfPresent(String.self, forKey: .cacheTypeV) ?? "f16"
        self.flashAttention = try container.decodeIfPresent(String.self, forKey: .flashAttention) ?? "auto"
        self.mlock = try container.decodeIfPresent(Bool.self, forKey: .mlock) ?? false
        self.noMMap = try container.decodeIfPresent(Bool.self, forKey: .noMMap) ?? false

        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.80
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP) ?? 0.95
        self.topK = try container.decodeIfPresent(Int.self, forKey: .topK) ?? 40
        self.minP = try container.decodeIfPresent(Double.self, forKey: .minP) ?? 0.05
        self.repeatPenalty = try container.decodeIfPresent(Double.self, forKey: .repeatPenalty) ?? 1.10
        self.repeatLastN = try container.decodeIfPresent(Int.self, forKey: .repeatLastN) ?? 64
        self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? -1

        self.checkForELlamaUpdates = try container.decodeIfPresent(Bool.self, forKey: .checkForELlamaUpdates) ?? true
        self.checkForLlamaCppUpdates = try container.decodeIfPresent(Bool.self, forKey: .checkForLlamaCppUpdates) ?? true
        self.installedLlamaCppVersion = try container.decodeIfPresent(String.self, forKey: .installedLlamaCppVersion) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelsDirectory, forKey: .modelsDirectory)
        try container.encode(llamaCliPath, forKey: .llamaCliPath)
        try container.encode(hideProjectors, forKey: .hideProjectors)
        try container.encode(closeToTray, forKey: .closeToTray)
        try container.encode(threads, forKey: .threads)
        try container.encode(gpuLayers, forKey: .gpuLayers)
        try container.encode(contextSize, forKey: .contextSize)
        try container.encode(batchSize, forKey: .batchSize)
        try container.encode(uBatchSize, forKey: .uBatchSize)
        try container.encode(cacheTypeK, forKey: .cacheTypeK)
        try container.encode(cacheTypeV, forKey: .cacheTypeV)
        try container.encode(flashAttention, forKey: .flashAttention)
        try container.encode(mlock, forKey: .mlock)
        try container.encode(noMMap, forKey: .noMMap)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(topP, forKey: .topP)
        try container.encode(topK, forKey: .topK)
        try container.encode(minP, forKey: .minP)
        try container.encode(repeatPenalty, forKey: .repeatPenalty)
        try container.encode(repeatLastN, forKey: .repeatLastN)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encode(checkForELlamaUpdates, forKey: .checkForELlamaUpdates)
        try container.encode(checkForLlamaCppUpdates, forKey: .checkForLlamaCppUpdates)
        try container.encode(installedLlamaCppVersion, forKey: .installedLlamaCppVersion)
    }

    // MARK: - Paths
    public static var appSupportDirectory: URL {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("eLlama", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    public static var settingsURL: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }

    public var resolvedModelsDirectory: String {
        Self.resolvePath(modelsDirectory)
    }

    public var resolvedLlamaCliPath: String {
        Self.resolvePath(llamaCliPath)
    }

    public static func resolvePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let expanded = (trimmed as NSString).expandingTildeInPath
        if (expanded as NSString).isAbsolutePath {
            return (expanded as NSString).standardizingPath
        }
        let currentDir = FileManager.default.currentDirectoryPath
        return ((currentDir as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
    }

    public static func defaultModelsDirectory() -> String {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        let ollamaModels = (home as NSString).appendingPathComponent(".ollama/models")
        if fm.fileExists(atPath: ollamaModels) {
            return ollamaModels
        }

        let appSupportModels = appSupportDirectory.appendingPathComponent("models").path
        if fm.fileExists(atPath: appSupportModels) {
            return appSupportModels
        }

        let homeModels = (home as NSString).appendingPathComponent("models")
        if fm.fileExists(atPath: homeModels) {
            return homeModels
        }

        return appSupportModels
    }

    public static func defaultLlamaCliPath() -> String {
        let fm = FileManager.default

        let inAppSupport = appSupportDirectory.appendingPathComponent("llama.cpp/llama-cli").path
        if fm.isExecutableFile(atPath: inAppSupport) {
            return inAppSupport
        }

        let homebrewArm = "/opt/homebrew/bin/llama-cli"
        if fm.isExecutableFile(atPath: homebrewArm) {
            return homebrewArm
        }

        let usrLocal = "/usr/local/bin/llama-cli"
        if fm.isExecutableFile(atPath: usrLocal) {
            return usrLocal
        }

        let relativeCli = (fm.currentDirectoryPath as NSString).appendingPathComponent("llama.cpp/llama-cli")
        if fm.isExecutableFile(atPath: relativeCli) {
            return relativeCli
        }

        return inAppSupport
    }

    // MARK: - Persistence
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: Self.settingsURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error.localizedDescription)")
        }
    }

    public static func load() -> AppSettings {
        let url = settingsURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            let newSettings = AppSettings()
            newSettings.save()
            return newSettings
        }

        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(AppSettings.self, from: data)
            return settings
        } catch {
            print("Error loading settings: \(error.localizedDescription). Falling back to defaults.")
            let fallback = AppSettings()
            fallback.save()
            return fallback
        }
    }

    public func resetToDefaults() {
        modelsDirectory = Self.defaultModelsDirectory()
        llamaCliPath = Self.defaultLlamaCliPath()
        hideProjectors = true
        closeToTray = false

        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        threads = max(1, min(cpuCount, 32))
        #if arch(arm64)
        gpuLayers = 99
        #else
        gpuLayers = 33
        #endif

        contextSize = 8192
        batchSize = 512
        uBatchSize = 512

        cacheTypeK = "f16"
        cacheTypeV = "f16"
        flashAttention = "auto"
        mlock = false
        noMMap = false

        temperature = 0.80
        topP = 0.95
        topK = 40
        minP = 0.05
        repeatPenalty = 1.10
        repeatLastN = 64
        maxTokens = -1

        save()
    }
}
