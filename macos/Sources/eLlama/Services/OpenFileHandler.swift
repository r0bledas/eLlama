import Foundation

public extension Notification.Name {
    static let eLlamaOpenModelFile = Notification.Name("com.raudel.ellama.openModelFile")
}

public final class OpenFileHandler: @unchecked Sendable {
    public static let shared = OpenFileHandler()

    private var pending: [URL] = []
    private let lock = NSLock()

    public init() {}

    public func handle(urls: [URL]) {
        let ggufURLs = urls.filter { $0.pathExtension.lowercased() == "gguf" }
        guard !ggufURLs.isEmpty else { return }

        lock.lock()
        pending.append(contentsOf: ggufURLs)
        lock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .eLlamaOpenModelFile, object: nil)
        }
    }

    public func consumePending() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        let urls = pending
        pending.removeAll()
        return urls
    }
}
