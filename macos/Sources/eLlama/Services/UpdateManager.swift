import Foundation
import AppKit
import Combine

public struct UpdateResult: Sendable {
    public let hasUpdate: Bool
    public let currentVersion: String
    public let latestVersion: String
    public let releaseURL: String
    public let assetDownloadURL: String?

    public init(
        hasUpdate: Bool,
        currentVersion: String,
        latestVersion: String,
        releaseURL: String,
        assetDownloadURL: String?
    ) {
        self.hasUpdate = hasUpdate
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseURL = releaseURL
        self.assetDownloadURL = assetDownloadURL
    }
}

public final class UpdateManager: ObservableObject, @unchecked Sendable {
    public static let shared = UpdateManager()
    public static let currentELlamaVersion = "2.0.0"

    @Published public var eLlamaUpdateStatus: String = "Check for Updates"
    @Published public var isCheckingELlama: Bool = false
    @Published public var llamaCppUpdateStatus: String = "Download Latest llama.cpp (Metal)"
    @Published public var isDownloadingLlamaCpp: Bool = false

    private init() {}

    public func checkELlamaUpdate() {
        isCheckingELlama = true
        Task {
            let res = await checkELlama()
            await MainActor.run {
                self.isCheckingELlama = false
                if res.hasUpdate, let downloadURL = res.assetDownloadURL {
                    self.eLlamaUpdateStatus = "Update Available: \(res.latestVersion)"
                    Task {
                        try? await self.downloadAndOpenELlamaUpdate(downloadURL: downloadURL)
                    }
                } else {
                    self.eLlamaUpdateStatus = "Latest is installed"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        UpdateManager.shared.eLlamaUpdateStatus = "Check for Updates"
                    }
                }
            }
        }
    }

    public func installLlamaCpp(completion: (@Sendable () -> Void)? = nil) {
        Task {
            await MainActor.run {
                self.isDownloadingLlamaCpp = true
                self.llamaCppUpdateStatus = "Downloading..."
            }
            do {
                _ = try await downloadAndInstallLlamaCpp { status in
                    Task { @MainActor in
                        UpdateManager.shared.llamaCppUpdateStatus = status
                    }
                }
                await MainActor.run {
                    self.isDownloadingLlamaCpp = false
                    self.llamaCppUpdateStatus = "Latest is installed"
                    completion?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        UpdateManager.shared.llamaCppUpdateStatus = "Download Latest llama.cpp (Metal)"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isDownloadingLlamaCpp = false
                    self.llamaCppUpdateStatus = "Update Failed"
                    completion?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        UpdateManager.shared.llamaCppUpdateStatus = "Download Latest llama.cpp (Metal)"
                    }
                }
            }
        }
    }

    // MARK: - eLlama Updates
    public func checkELlama() async -> UpdateResult {
        guard let url = URL(string: "https://api.github.com/repos/r0bledas/eLlama/releases?per_page=5") else {
            return UpdateResult(hasUpdate: false, currentVersion: Self.currentELlamaVersion, latestVersion: Self.currentELlamaVersion, releaseURL: "https://github.com/r0bledas/eLlama/releases", assetDownloadURL: nil)
        }

        var request = URLRequest(url: url)
        request.setValue("eLlama-macOS-Updater", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = releases.first else {
                return UpdateResult(hasUpdate: false, currentVersion: Self.currentELlamaVersion, latestVersion: Self.currentELlamaVersion, releaseURL: "https://github.com/r0bledas/eLlama/releases", assetDownloadURL: nil)
            }

            let tagName = (latest["tag_name"] as? String) ?? ""
            let htmlURL = (latest["html_url"] as? String) ?? "https://github.com/r0bledas/eLlama/releases"

            var assetDownloadURL: String? = nil
            if let assets = latest["assets"] as? [[String: Any]] {
                // Look for .dmg or mac .zip
                for asset in assets {
                    let name = (asset["name"] as? String)?.lowercased() ?? ""
                    if name.hasSuffix(".dmg") || (name.contains("mac") && name.hasSuffix(".zip")) {
                        assetDownloadURL = asset["browser_download_url"] as? String
                        break
                    }
                }
            }

            let cleanLatest = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let cleanCurrent = Self.currentELlamaVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            let hasUpdate = Self.isVersion(cleanLatest, greaterThan: cleanCurrent)

            return UpdateResult(
                hasUpdate: hasUpdate,
                currentVersion: Self.currentELlamaVersion,
                latestVersion: tagName,
                releaseURL: htmlURL,
                assetDownloadURL: assetDownloadURL
            )
        } catch {
            return UpdateResult(hasUpdate: false, currentVersion: Self.currentELlamaVersion, latestVersion: Self.currentELlamaVersion, releaseURL: "https://github.com/r0bledas/eLlama/releases", assetDownloadURL: nil)
        }
    }

    // MARK: - llama.cpp Updates
    public func checkLlamaCpp() async -> UpdateResult {
        let currentBuild = detectInstalledLlamaCppBuild()

        guard let url = URL(string: "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=5") else {
            return UpdateResult(hasUpdate: false, currentVersion: currentBuild, latestVersion: currentBuild, releaseURL: "https://github.com/ggml-org/llama.cpp/releases", assetDownloadURL: nil)
        }

        var request = URLRequest(url: url)
        request.setValue("eLlama-macOS-Updater", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let latest = releases.first else {
                return UpdateResult(hasUpdate: false, currentVersion: currentBuild, latestVersion: currentBuild, releaseURL: "https://github.com/ggml-org/llama.cpp/releases", assetDownloadURL: nil)
            }

            let tagName = (latest["tag_name"] as? String) ?? ""
            let htmlURL = (latest["html_url"] as? String) ?? "https://github.com/ggml-org/llama.cpp/releases"

            var macAssetURL: String? = nil
            if let assets = latest["assets"] as? [[String: Any]] {
                #if arch(arm64)
                let archFilter = "arm64"
                #else
                let archFilter = "x64"
                #endif

                for asset in assets {
                    let name = (asset["name"] as? String)?.lowercased() ?? ""
                    if (name.contains("macos") || name.contains("osx") || name.contains("darwin")) &&
                        name.contains(archFilter) &&
                        name.hasSuffix(".zip") {
                        macAssetURL = asset["browser_download_url"] as? String
                        break
                    }
                }
            }

            let latestNum = Self.parseBuildNumber(tagName)
            let currentNum = Self.parseBuildNumber(currentBuild)

            var hasUpdate = false
            if latestNum > 0 && currentNum > 0 {
                hasUpdate = latestNum > currentNum
            } else if !tagName.isEmpty && tagName != currentBuild {
                hasUpdate = true
            }

            return UpdateResult(
                hasUpdate: hasUpdate,
                currentVersion: currentBuild,
                latestVersion: tagName,
                releaseURL: htmlURL,
                assetDownloadURL: macAssetURL
            )
        } catch {
            return UpdateResult(hasUpdate: false, currentVersion: currentBuild, latestVersion: currentBuild, releaseURL: "https://github.com/ggml-org/llama.cpp/releases", assetDownloadURL: nil)
        }
    }

    public func detectInstalledLlamaCppBuild() -> String {
        let settings = AppSettings.shared
        if !settings.installedLlamaCppVersion.isEmpty {
            return settings.installedLlamaCppVersion
        }

        let cliPath = settings.resolvedLlamaCliPath
        guard FileManager.default.fileExists(atPath: cliPath) else {
            return "Not Installed"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let range = NSRange(location: 0, length: output.utf16.count)
                if let regex = try? NSRegularExpression(pattern: #"build\s+(\d+)"#, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: output, options: [], range: range),
                   let groupRange = Range(match.range(at: 1), in: output) {
                    let build = "b" + String(output[groupRange])
                    settings.installedLlamaCppVersion = build
                    settings.save()
                    return build
                }
            }
        } catch {
            // ignore
        }

        return "Installed"
    }

    public func downloadAndInstallLlamaCpp(
        downloadURL: String? = nil,
        tagName: String? = nil,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> Bool {
        var urlToDownload = downloadURL
        var releaseTag = tagName

        if urlToDownload == nil {
            progress("Checking latest release...")
            let check = await checkLlamaCpp()
            urlToDownload = check.assetDownloadURL
            releaseTag = check.latestVersion
        }

        guard let finalURLString = urlToDownload,
              let finalURL = URL(string: finalURLString) else {
            throw UpdateError.invalidDownloadURL
        }

        progress("Downloading llama.cpp Metal build...")
        let (tempZipURL, _) = try await URLSession.shared.download(from: finalURL)

        progress("Extracting binaries...")
        let targetDir = AppSettings.appSupportDirectory.appendingPathComponent("llama.cpp", isDirectory: true)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        // Unzip using ditto
        let dittoProcess = Process()
        dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        dittoProcess.arguments = ["-x", "-k", tempZipURL.path, targetDir.path]

        try dittoProcess.run()
        dittoProcess.waitUntilExit()

        try? FileManager.default.removeItem(at: tempZipURL)

        // Ensure llama-cli and llama-server are executable (chmod +x)
        let cliURL = targetDir.appendingPathComponent("llama-cli")
        let serverURL = targetDir.appendingPathComponent("llama-server")

        if FileManager.default.fileExists(atPath: serverURL.path) {
            if var attrs = try? FileManager.default.attributesOfItem(atPath: serverURL.path) {
                attrs[.posixPermissions] = 0o755
                try? FileManager.default.setAttributes(attrs, ofItemAtPath: serverURL.path)
            }
            DispatchQueue.main.async {
                AppSettings.shared.llamaServerPath = serverURL.path
            }
        }

        if FileManager.default.fileExists(atPath: cliURL.path) {
            var attrs = try FileManager.default.attributesOfItem(atPath: cliURL.path)
            attrs[.posixPermissions] = 0o755
            try FileManager.default.setAttributes(attrs, ofItemAtPath: cliURL.path)

            DispatchQueue.main.async {
                AppSettings.shared.llamaCliPath = cliURL.path
                if let tag = releaseTag, !tag.isEmpty {
                    AppSettings.shared.installedLlamaCppVersion = tag
                }
                AppSettings.shared.save()
            }
            progress("Installation Complete!")
            return true
        }

        // Sometimes the zip extracts into a subfolder; search for llama-cli and llama-server inside targetDir
        if let enumerator = FileManager.default.enumerator(at: targetDir, includingPropertiesForKeys: nil) {
            var foundCliPath: String? = nil
            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.lastPathComponent == "llama-server" {
                    if var attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                        attrs[.posixPermissions] = 0o755
                        try? FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
                    }
                    DispatchQueue.main.async {
                        AppSettings.shared.llamaServerPath = fileURL.path
                    }
                } else if fileURL.lastPathComponent == "llama-cli" {
                    var attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    attrs[.posixPermissions] = 0o755
                    try FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
                    foundCliPath = fileURL.path
                }
            }

            if let cliPath = foundCliPath {
                DispatchQueue.main.async {
                    AppSettings.shared.llamaCliPath = cliPath
                    if let tag = releaseTag, !tag.isEmpty {
                        AppSettings.shared.installedLlamaCppVersion = tag
                    }
                    AppSettings.shared.save()
                }
                progress("Installation Complete!")
                return true
            }
        }

        throw UpdateError.binaryNotFoundAfterExtraction
    }

    public func downloadAndOpenELlamaUpdate(downloadURL: String) async throws {
        guard let url = URL(string: downloadURL) else {
            throw UpdateError.invalidDownloadURL
        }

        let (tempFile, response) = try await URLSession.shared.download(from: url)
        let suggestedName = response.suggestedFilename ?? "eLlama-update.dmg"
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let targetURL = downloadsDir.appendingPathComponent(suggestedName)

        try? FileManager.default.removeItem(at: targetURL)
        try FileManager.default.moveItem(at: tempFile, to: targetURL)

        NSWorkspace.shared.open(targetURL)
    }

    // MARK: - Helpers
    private static func parseBuildNumber(_ tag: String) -> Int {
        let clean = tag.trimmingCharacters(in: CharacterSet(charactersIn: "bBvV"))
        return Int(clean) ?? 0
    }

    private static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }

        let count = max(parts1.count, parts2.count)
        for i in 0..<count {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    public enum UpdateError: LocalizedError {
        case invalidDownloadURL
        case binaryNotFoundAfterExtraction

        public var errorDescription: String? {
            switch self {
            case .invalidDownloadURL:
                return "The download URL for the update is invalid or missing."
            case .binaryNotFoundAfterExtraction:
                return "llama-cli was not found inside the downloaded archive."
            }
        }
    }
}
