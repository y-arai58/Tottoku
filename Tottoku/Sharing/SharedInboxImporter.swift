import Foundation
import FoundationModels
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

    static func refreshPlaceholderLinkTitles(in modelContext: ModelContext) async -> Int {
        guard let items = try? modelContext.fetch(FetchDescriptor<SavedItem>()) else { return 0 }
        var updatedCount = 0
        for item in items {
            if await fetchLinkTitleIfNeeded(for: item, in: modelContext) {
                updatedCount += 1
            }
        }
        return updatedCount
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

    @discardableResult
    private static func fetchLinkTitleIfNeeded(for item: SavedItem, in modelContext: ModelContext) async -> Bool {
        guard item.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: item.urlString),
              isPlaceholderTitle(item.title, for: url) else {
            return false
        }

        let systemTitle: String?
        if #available(iOS 26.4, *),
           let metadata = try? await LinkMetadata(
            fetching: url,
            timeout: .seconds(6),
            includeSubresources: false
           ) {
            systemTitle = metadata.title
        } else {
            systemTitle = nil
        }

        let trimmedSystemTitle = systemTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (isMeaningfulLinkTitle(trimmedSystemTitle, for: url)
            ? trimmedSystemTitle
            : await OpenGraphTitleFetcher.fetchTitle(from: url))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title, !title.isEmpty else { return false }

        item.title = String(title.prefix(120))
        try? modelContext.save()
        return true
    }

    private static func isPlaceholderTitle(_ title: String, for url: URL) -> Bool {
        title == url.host || title == "共有した投稿"
    }

    private static func isMeaningfulLinkTitle(_ title: String?, for url: URL) -> Bool {
        guard let title, !title.isEmpty else { return false }
        return !isPlaceholderTitle(title, for: url) && title.caseInsensitiveCompare("X") != .orderedSame
    }
}

private enum OpenGraphTitleFetcher {
    static func fetchTitle(from url: URL) async -> String? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode),
              data.count <= 1_000_000,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        return metaContent(named: "og:title", in: html)
            ?? metaContent(named: "twitter:title", in: html)
    }

    private static func metaContent(named name: String, in html: String) -> String? {
        guard let tagPattern = try? NSRegularExpression(pattern: "<meta\\b[^>]*>", options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        for match in tagPattern.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            let property = attribute(named: "property", in: tag) ?? attribute(named: "name", in: tag)
            guard property?.caseInsensitiveCompare(name) == .orderedSame,
                  let content = attribute(named: "content", in: tag) else { continue }
            return htmlUnescaped(content)
        }
        return nil
    }

    private static func attribute(named name: String, in tag: String) -> String? {
        let pattern = "\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = expression.firstMatch(in: tag, range: range) else { return nil }
        for index in 1..<match.numberOfRanges {
            guard match.range(at: index).location != NSNotFound,
                  let valueRange = Range(match.range(at: index), in: tag) else { continue }
            return String(tag[valueRange])
        }
        return nil
    }

    private static func htmlUnescaped(_ string: String) -> String {
        string
            .replacing("&amp;", with: "&")
            .replacing("&quot;", with: "\"")
            .replacing("&#39;", with: "'")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
    }
}

@Generable(description: "保存したリンクを整理する結果")
private struct GeneratedBookmarkClassification {
    @Guide(description: "指定されたカテゴリ名から1つだけ選ぶ")
    var category: String

    @Guide(description: "検索に役立つ短いタグを最大5個")
    var tags: [String]

    @Guide(description: "日本語で80文字以内の短い要約")
    var summary: String
}

private struct BookmarkClassification {
    let categoryName: String
    let tags: [String]
    let summary: String
    let state: ClassificationState
}

@MainActor
enum SavedItemClassifier {
    static func classifyPendingItems(
        in modelContext: ModelContext,
        categoryNames: [String]
    ) async -> Int {
        let availableCategories = categoryNames.isEmpty ? CategorySeed.defaults : categoryNames
        guard let items = try? modelContext.fetch(FetchDescriptor<SavedItem>()) else { return 0 }
        let pendingItems = items.filter { $0.classificationState == .pending }

        for item in pendingItems {
            let classification = await classify(item, availableCategories: availableCategories)
            item.categoryName = classification.categoryName
            item.tagNames = classification.tags
            item.summary = classification.summary
            item.classificationStateRawValue = classification.state.rawValue
            try? modelContext.save()
        }

        return pendingItems.count
    }

    private static func classify(
        _ item: SavedItem,
        availableCategories: [String]
    ) async -> BookmarkClassification {
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else {
            return ruleBasedClassification(for: item, availableCategories: availableCategories)
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You organize a personal bookmark library. Return only information grounded in the supplied link title and text.
            Choose one category exactly from the allowed category names. Use Japanese for tags and summary.
            If the content is too limited to classify, choose その他 and use no invented details.
            """
        )
        let prompt = """
        Allowed category names: \(availableCategories.joined(separator: ", "))
        Source: \(item.source.displayName)
        Title: \(item.title)
        Text: \(item.bodyText)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedBookmarkClassification.self,
                options: GenerationOptions(temperature: 0.1, maximumResponseTokens: 180)
            )
            let content = response.content
            return BookmarkClassification(
                categoryName: normalizedCategory(content.category, availableCategories: availableCategories),
                tags: normalizedTags(content.tags),
                summary: normalizedSummary(content.summary, fallback: item.title),
                state: .automatic
            )
        } catch {
            return ruleBasedClassification(for: item, availableCategories: availableCategories)
        }
    }

    private static func ruleBasedClassification(
        for item: SavedItem,
        availableCategories: [String]
    ) -> BookmarkClassification {
        let text = "\(item.title) \(item.bodyText)".localizedLowercase
        let keywordCategories: [(String, [String])] = [
            ("食べ物", ["カフェ", "レストラン", "料理", "グルメ", "ランチ", "スイーツ", "food", "cafe"]),
            ("コスメ", ["コスメ", "メイク", "美容", "スキンケア", "リップ", "cosmetic", "makeup"]),
            ("服", ["服", "コーデ", "ファッション", "スニーカー", "バッグ", "fashion"]),
            ("旅行", ["旅行", "ホテル", "観光", "旅", "trip", "travel"]),
            ("インテリア", ["インテリア", "家具", "部屋", "収納", "interior"]),
            ("健康", ["健康", "運動", "筋トレ", "ヨガ", "健康", "workout", "health"]),
            ("買い物", ["購入", "買い物", "おすすめ", "セール", "amazon", "楽天"]),
            ("技術", ["swift", "react", "プログラミング", "開発", "ai", "code", "tech"]),
            ("勉強", ["勉強", "学習", "本", "講座", "study", "learn"])
        ]
        let inferredCategory = keywordCategories
            .first(where: { _, keywords in keywords.contains(where: text.contains) })
            .map(\.0)
        let category = inferredCategory
            .flatMap { matchedCategory in availableCategories.first { $0 == matchedCategory } }
            ?? fallbackCategory(from: availableCategories)

        return BookmarkClassification(
            categoryName: category,
            tags: hashtags(in: item.bodyText),
            summary: normalizedSummary(item.title, fallback: "保存したリンク"),
            state: .ruleBased
        )
    }

    private static func normalizedCategory(_ category: String, availableCategories: [String]) -> String {
        availableCategories.first { $0.caseInsensitiveCompare(category) == .orderedSame }
            ?? fallbackCategory(from: availableCategories)
    }

    private static func fallbackCategory(from categories: [String]) -> String {
        categories.first(where: { $0 == "その他" }) ?? categories.first ?? "その他"
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        var uniqueTags: [String] = []
        for tag in tags {
            let normalized = tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacing("#", with: "")
            guard !normalized.isEmpty, !uniqueTags.contains(normalized) else { continue }
            uniqueTags.append(normalized)
        }
        return Array(uniqueTags.prefix(5))
    }

    private static func hashtags(in text: String) -> [String] {
        normalizedTags(text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { $0.hasPrefix("#") }
            .map(String.init))
    }

    private static func normalizedSummary(_ summary: String, fallback: String) -> String {
        let value = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((value.isEmpty ? fallback : value).prefix(80))
    }
}
