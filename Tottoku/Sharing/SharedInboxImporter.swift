import Foundation
import LinkPresentation
import SwiftData

@MainActor
enum SharedInboxImporter {
    static func importPendingShares(into modelContext: ModelContext) async -> Int {
        guard let shares = try? SharedInbox.pendingShares() else { return 0 }
        var importedCount = 0
        var importedItems: [SavedItem] = []

        for share in shares {
            let descriptor = FetchDescriptor<SavedItem>(predicate: #Predicate { $0.id == share.id })
            if (try? modelContext.fetchCount(descriptor)) ?? 0 > 0 {
                try? SharedInbox.remove(share)
                continue
            }

            let item = savedItem(from: share)
            modelContext.insert(item)
            do {
                try modelContext.save()
                try SharedInbox.remove(share)
                importedCount += 1
                importedItems.append(item)
            } catch {
                modelContext.rollback()
            }
        }

        for item in importedItems {
            await fetchLinkTitleIfNeeded(for: item, in: modelContext)
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
        if let title = share.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return String(title.prefix(80))
        }
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

    private static func fetchLinkTitleIfNeeded(for item: SavedItem, in modelContext: ModelContext) async {
        guard item.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: item.urlString),
              isPlaceholderTitle(item.title, for: url) else {
            return
        }

        guard #available(iOS 26.4, *),
              let metadata = try? await LinkMetadata(
                fetching: url,
                timeout: .seconds(6),
                includeSubresources: false
              ),
              let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return }

        item.title = String(title.prefix(120))
        try? modelContext.save()
    }

    private static func isPlaceholderTitle(_ title: String, for url: URL) -> Bool {
        title == url.host || title == "共有した投稿"
    }
}
