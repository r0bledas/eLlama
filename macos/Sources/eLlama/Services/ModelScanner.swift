import Foundation

public final class ModelScanner: Sendable {
    public static let shared = ModelScanner()

    private static let quantRegex: NSRegularExpression = {
        let pattern = #"(?:[._-])(UD-Q[0-9]_[A-Z0-9_]+|Q[0-9]_[A-Z0-9_]+|IQ[0-9]_[A-Z0-9_]+|Q[0-9]_[0-9]|BF16|F16|F32|QAT-Q[0-9]_[0-9])(?:[._-]|\.gguf)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    public init() {}

    public func scan(directory: String) async -> [ModelInfo] {
        return await Task.detached(priority: .userInitiated) {
            let resolvedPath = AppSettings.resolvePath(directory)
            let fm = FileManager.default

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: resolvedPath, isDirectory: &isDir), isDir.boolValue else {
                return []
            }

            let rootURL = URL(fileURLWithPath: resolvedPath).standardizedFileURL
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]

            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return []
            }

            var models: [ModelInfo] = []

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension.lowercased() == "gguf" else { continue }

                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    guard resourceValues.isRegularFile == true else { continue }
                    let fileSize = Int64(resourceValues.fileSize ?? 0)

                    if let model = Self.parseModel(fileURL: fileURL, rootURL: rootURL, fileSize: fileSize) {
                        models.append(model)
                    }
                } catch {
                    continue
                }
            }

            return models
        }.value
    }

    public static func parseModel(fileURL: URL, rootURL: URL, fileSize: Int64) -> ModelInfo? {
        let filename = fileURL.lastPathComponent
        let rootPath = rootURL.path
        let filePath = fileURL.path

        // Determine publisher from directory structure
        var publisher = "Local"
        if filePath.hasPrefix(rootPath) {
            let relative = String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/\\"))
            let components = relative.split(separator: "/")
            if components.count > 1 {
                publisher = String(components[0])
            }
        }

        let isProjector = filename.lowercased().hasPrefix("mmproj")

        // Quantization regex match
        var quant = "Unknown"
        var matchedQuantText: String? = nil

        let range = NSRange(location: 0, length: filename.utf16.count)
        if let match = quantRegex.firstMatch(in: filename, options: [], range: range),
           match.numberOfRanges > 1,
           let groupRange = Range(match.range(at: 1), in: filename) {
            let rawQuant = String(filename[groupRange])
            quant = rawQuant.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
            matchedQuantText = rawQuant
        }

        // Base Model Name
        var baseName = fileURL.deletingPathExtension().lastPathComponent
        if let matched = matchedQuantText,
           let range = baseName.range(of: matched, options: .caseInsensitive) {
            let prefix = String(baseName[..<range.lowerBound])
            baseName = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
        }

        if isProjector {
            let cleaned = baseName.replacingOccurrences(of: "mmproj-", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
            baseName = "[Vision Projector] " + cleaned
        }

        return ModelInfo(
            filePath: filePath,
            fileName: filename,
            modelName: baseName.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : baseName,
            publisher: publisher,
            quant: quant,
            sizeBytes: fileSize,
            isProjector: isProjector
        )
    }
}
