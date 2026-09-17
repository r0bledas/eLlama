import Foundation
import AppKit

public final class TerminalLauncher: Sendable {
    public static let shared = TerminalLauncher()

    public init() {}

    public static func buildLlamaArgs(model: ModelInfo, settings: AppSettings) -> [String] {
        var args: [String] = [
            "-m", "\"\(model.filePath)\"",
            "-t", "\(settings.threads)",
            "-c", "\(settings.contextSize)"
        ]

        if settings.gpuLayers > 0 {
            args.append(contentsOf: ["-ngl", "\(settings.gpuLayers)"])
        }
        if settings.batchSize != 512 {
            args.append(contentsOf: ["-b", "\(settings.batchSize)"])
        }
        if settings.uBatchSize != 512 {
            args.append(contentsOf: ["-ub", "\(settings.uBatchSize)"])
        }

        if settings.cacheTypeK.lowercased() != "f16" {
            args.append(contentsOf: ["-ctk", settings.cacheTypeK])
        }
        if settings.cacheTypeV.lowercased() != "f16" {
            args.append(contentsOf: ["-ctv", settings.cacheTypeV])
        }

        if settings.flashAttention.lowercased() != "auto" {
            args.append(contentsOf: ["-fa", settings.flashAttention])
        }

        if settings.mlock {
            args.append("--mlock")
        }
        if settings.noMMap {
            args.append("--no-mmap")
        }

        // Sampling
        args.append(contentsOf: ["--temp", String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), settings.temperature)])
        args.append(contentsOf: ["--top-p", String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), settings.topP)])
        args.append(contentsOf: ["--top-k", "\(settings.topK)"])
        args.append(contentsOf: ["--min-p", String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), settings.minP)])
        args.append(contentsOf: ["--repeat-penalty", String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), settings.repeatPenalty)])

        if settings.repeatLastN != 64 {
            args.append(contentsOf: ["--repeat-last-n", "\(settings.repeatLastN)"])
        }
        if settings.maxTokens > 0 {
            args.append(contentsOf: ["-n", "\(settings.maxTokens)"])
        }

        return args
    }

    public static func buildCommandLine(model: ModelInfo, settings: AppSettings) -> String {
        let cliPath = settings.resolvedLlamaCliPath
        let args = buildLlamaArgs(model: model, settings: settings)
        return "\"\(cliPath)\" " + args.joined(separator: " ")
    }

    public func launch(model: ModelInfo, settings: AppSettings) throws {
        let cliPath = settings.resolvedLlamaCliPath
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw LaunchError.cliNotFound(cliPath)
        }

        let commandLine = Self.buildCommandLine(model: model, settings: settings)

        // Generate a temporary launcher script to run in Terminal.app with proper window title
        let scriptDir = FileManager.default.temporaryDirectory.appendingPathComponent("eLlama_scripts")
        try? FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)

        let safeName = model.modelName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let scriptFile = scriptDir.appendingPathComponent("run_\(safeName).command")

        let scriptContent = """
        #!/bin/bash
        echo -n -e "\\033]0;\(model.modelName)\\007"
        clear
        echo "=================================================================="
        echo " eLlama: Launching \(model.modelName)"
        echo " Quant: \(model.quant) | Size: \(model.formattedSize)"
        echo "=================================================================="
        echo ""
        \(commandLine)
        echo ""
        echo "Process exited. Press [Enter] to close..."
        read -r
        """

        try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)

        // Make executable (chmod +x)
        var attrs = try FileManager.default.attributesOfItem(atPath: scriptFile.path)
        attrs[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attrs, ofItemAtPath: scriptFile.path)

        // Launch in Terminal.app using AppleScript or NSWorkspace
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(scriptFile.path)"
        end tell
        """

        if let scriptObj = NSAppleScript(source: appleScript) {
            var errorInfo: NSDictionary? = nil
            scriptObj.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                // Fallback to NSWorkspace open file
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([scriptFile], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: config, completionHandler: nil)
            }
        } else {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([scriptFile], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"), configuration: config, completionHandler: nil)
        }
    }

    public func copyRunCommand(model: ModelInfo, settings: AppSettings) {
        let command = Self.buildCommandLine(model: model, settings: settings)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    public func copyFilePath(model: ModelInfo) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.filePath, forType: .string)
    }

    public func openContainingFolder(model: ModelInfo, fallbackDirectory: String) {
        if FileManager.default.fileExists(atPath: model.filePath) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: model.filePath)])
        } else {
            let dir = AppSettings.resolvePath(fallbackDirectory)
            NSWorkspace.shared.open(URL(fileURLWithPath: dir))
        }
    }

    public enum LaunchError: LocalizedError {
        case cliNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .cliNotFound(let path):
                return "llama-cli was not found at: \(path)\n\nPlease install llama.cpp in Settings or configure the path."
            }
        }
    }
}
