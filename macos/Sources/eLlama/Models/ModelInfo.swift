import Foundation

public struct ModelInfo: Identifiable, Hashable, Equatable, Sendable {
    public var id: String { filePath }
    
    public let filePath: String
    public let fileName: String
    public let modelName: String
    public let publisher: String
    public let quant: String
    public let sizeBytes: Int64
    public let isProjector: Bool

    public init(
        filePath: String,
        fileName: String,
        modelName: String,
        publisher: String,
        quant: String,
        sizeBytes: Int64,
        isProjector: Bool
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.modelName = modelName
        self.publisher = publisher
        self.quant = quant
        self.sizeBytes = sizeBytes
        self.isProjector = isProjector
    }

    public var formattedSize: String {
        Self.formatBytes(sizeBytes)
    }

    public static func formatBytes(_ bytes: Int64) -> String {
        let gigabyte: Double = 1024.0 * 1024.0 * 1024.0
        let megabyte: Double = 1024.0 * 1024.0
        let kilobyte: Double = 1024.0

        let dBytes = Double(bytes)
        if bytes >= Int64(gigabyte) {
            return String(format: "%.2f GB", dBytes / gigabyte)
        } else if bytes >= Int64(megabyte) {
            return String(format: "%.2f MB", dBytes / megabyte)
        } else {
            return String(format: "%.2f KB", dBytes / kilobyte)
        }
    }
}
