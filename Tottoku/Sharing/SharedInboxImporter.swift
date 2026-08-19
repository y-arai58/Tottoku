import Foundation
import SwiftData

@MainActor
enum SharedInboxImporter {
    static func importPendingShares(into modelContext: ModelContext) -> Int {
        guard let shares = try? SharedInbox.pendingShares() else { return 0 }
        var importedCount = 0

        for share in shares {
            let descriptor = FetchDescriptor<SavedItem>(predicate: #Predicate { $0.id == share.id })
            if (try? modelContext.fetchCount(descriptor)) ?? 0 > 0 {
                try? SharedInbox.remove(share)
                continue
            }

            modelContext.insert(savedItem(from: share))
            do {
                try modelContext.save()
                try SharedInbox.remove(share)
                importedCount += 1
            } catch {
                modelContext.rollback()
            }
        }

        return importedCount
    }

    private static func savedItem(from share: IncomingShare) -> SavedItem {
        let urlString = share.urlString ?? ""
        return SavedItem(
            id: share.id,
            urlString: urlString,
            source: SavedSource.infer(from: urlString),
            title: title(for: share, urlString: urlString),
            bodyText: share.text.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: share.receivedAt
        )
    }

    private static func title(for share: IncomingShare, urlString: String) -> String {
        if let firstLine = share.text
            .split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return String(firstLine.prefix(80))
        }
        if let host = URL(string: urlString)?.host, !host.isEmpty {
            return host
        }
        return "共有した投稿"
    }
}
