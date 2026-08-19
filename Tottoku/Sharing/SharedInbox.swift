import Foundation

enum AppGroupConfiguration {
    /// Enable this same App Group for the main app and the Share Extension in Xcode.
    static let identifier = "group.com.tottoku.app"
}

enum SharedInboxError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "共有用の保存場所を開けませんでした。"
    }
}

enum SharedInbox {
    static func enqueue(_ share: IncomingShare) throws {
        let directory = try inboxDirectory()
        let destination = directory.appending(path: "\(share.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(share).write(to: destination, options: .atomic)
    }

    static func inboxDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfiguration.identifier) else {
            throw SharedInboxError.unavailable
        }
        let directory = container.appending(path: "IncomingShares", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func pendingShares() throws -> [IncomingShare] {
        let directory = try inboxDirectory()
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try fileURLs
            .filter { $0.pathExtension == "json" }
            .map { try (decoder.decode(IncomingShare.self, from: Data(contentsOf: $0)), $0) }
            .sorted { $0.0.receivedAt < $1.0.receivedAt }
            .map(\.0)
    }

    static func remove(_ share: IncomingShare) throws {
        let fileURL = try inboxDirectory().appending(path: "\(share.id.uuidString).json")
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
