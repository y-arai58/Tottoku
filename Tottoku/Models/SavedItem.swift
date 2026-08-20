import Foundation
import SwiftData

enum SavedSource: String, CaseIterable, Identifiable {
    case instagram
    case x
    case threads
    case safari
    case web
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .x: "X"
        case .threads: "Threads"
        case .safari: "Safari"
        case .web: "Web"
        case .unknown: "不明"
        }
    }

    var symbolName: String {
        switch self {
        case .instagram: "camera"
        case .x: "xmark"
        case .threads: "at"
        case .safari: "safari"
        case .web, .unknown: "link"
        }
    }

    static func infer(from urlString: String) -> SavedSource {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return .unknown }
        if host.contains("instagram.com") { return .instagram }
        if host == "x.com" || host.contains("twitter.com") { return .x }
        if host.contains("threads.net") { return .threads }
        return .web
    }
}

/// 表紙に使える画像の有無。未確定のあいだ一覧は仮画像を出す。
enum CoverState: String {
    case unknown
    case none
    case artwork
}

enum ClassificationState: String {
    case pending
    case automatic
    case ruleBased
    case edited

    var displayName: String {
        switch self {
        case .pending: "未分類"
        case .automatic: "自動分類済み"
        case .ruleBased: "簡易分類済み"
        case .edited: "編集済み"
        }
    }
}

@Model
final class SavedItem {
    var id: UUID
    var urlString: String
    var sourceRawValue: String
    var title: String
    var bodyText: String
    var author: String
    var summary: String
    var categoryName: String
    var tagNames: [String]
    var thumbnailURLString: String?
    @Attribute(.externalStorage) var screenshotImageData: Data?
    /// 一覧用の縮小画像。巨大なスクリーンショットを一覧で展開しないために持つ。
    @Attribute(.externalStorage) var coverThumbnailData: Data?
    /// スクリーンショットを持つか。実データを読まずに後処理の対象を選ぶために持つ。
    var hasScreenshot: Bool = false
    var coverStateRawValue: String = CoverState.unknown.rawValue
    var recognizedText: String?
    var createdAt: Date
    var classificationStateRawValue: String

    init(
        id: UUID = UUID(),
        urlString: String,
        source: SavedSource,
        title: String,
        bodyText: String = "",
        author: String = "",
        summary: String = "",
        categoryName: String = "その他",
        tagNames: [String] = [],
        thumbnailURLString: String? = nil,
        screenshotImageData: Data? = nil,
        coverThumbnailData: Data? = nil,
        hasScreenshot: Bool = false,
        coverState: CoverState = .unknown,
        recognizedText: String? = nil,
        createdAt: Date = .now,
        classificationState: ClassificationState = .pending
    ) {
        self.id = id
        self.urlString = urlString
        self.sourceRawValue = source.rawValue
        self.title = title
        self.bodyText = bodyText
        self.author = author
        self.summary = summary
        self.categoryName = categoryName
        self.tagNames = tagNames
        self.thumbnailURLString = thumbnailURLString
        self.screenshotImageData = screenshotImageData
        self.coverThumbnailData = coverThumbnailData
        self.hasScreenshot = hasScreenshot
        self.coverStateRawValue = coverState.rawValue
        self.recognizedText = recognizedText
        self.createdAt = createdAt
        self.classificationStateRawValue = classificationState.rawValue
    }

    var source: SavedSource { SavedSource(rawValue: sourceRawValue) ?? .unknown }

    var coverState: CoverState {
        get { CoverState(rawValue: coverStateRawValue) ?? .unknown }
        set { coverStateRawValue = newValue.rawValue }
    }

    /// 表紙の画像領域を出すか。未確定のあいだは仮画像を出すので true にする。
    /// 巨大な`screenshotImageData`を読まずに判定できることが重要。
    var showsCoverArea: Bool { coverState != .none }

    /// 表紙に出せる画像が確定しているか。
    var hasCoverArtwork: Bool { coverState == .artwork }
    var classificationState: ClassificationState { ClassificationState(rawValue: classificationStateRawValue) ?? .pending }
}
