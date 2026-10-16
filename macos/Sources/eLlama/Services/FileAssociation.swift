import AppKit
import UniformTypeIdentifiers

public final class FileAssociation {
    public static let shared = FileAssociation()

    public static let ggufTypeIdentifier = "org.ggml.gguf"

    public static var ggufType: UTType {
        if let type = UTType(filenameExtension: "gguf") {
            return type
        }
        return UTType(exportedAs: ggufTypeIdentifier, conformingTo: .data)
    }

    public init() {}

    public var isDefaultHandler: Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: Self.ggufType) else {
            return false
        }
        return Bundle(url: appURL)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    public func setAsDefaultHandler(completion: @escaping (Bool) -> Void) {
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: Self.ggufType) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
}
