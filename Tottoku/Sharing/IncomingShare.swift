import Foundation

/// A small, durable payload written by the Share Extension before the host can terminate it.
struct IncomingShare: Codable, Identifiable, Sendable {
    let id: UUID
    let urlString: String?
    let title: String?
    let text: String
    let receivedAt: Date

    init(id: UUID = UUID(), urlString: String?, title: String? = nil, text: String, receivedAt: Date = .now) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.text = text
        self.receivedAt = receivedAt
    }
}
