import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

/// 一覧の表紙に使う画像の準備。
/// スクリーンショットの実データは巨大なので、主スレッドで全展開しないための入口をここに集める。
enum CoverArtwork {
    /// 一覧のセルに載せる縮小画像の最大辺。
    static let listMaxPixelSize: CGFloat = 520
    /// 詳細画面に載せる画像の最大辺。
    static let detailMaxPixelSize: CGFloat = 1400

    /// ImageIOのサムネイル生成を使い、元画像を全展開せずに縮小JPEGを作る。
    /// 主スレッドから呼ばないこと。
    static func downsampledJPEGData(from imageData: Data, maxPixelSize: CGFloat) -> Data? {
        guard !imageData.isEmpty,
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// 投稿の中身の画像かどうか。
    /// Xは文字だけの投稿でもog:imageにプロフィール画像やロゴを返すため、それらを表紙にしない。
    static func isContentImageURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        // abs.twimg.com はXの固定アセット（ロゴ・共有カード）専用ホスト。
        if host == "abs.twimg.com" { return false }
        if path.contains("profile_images") || path.contains("profile_banners") || path.contains("default_profile") {
            return false
        }
        // pbs.twimg.com では投稿画像が /media/ 配下にしか置かれない。
        if host.hasSuffix("twimg.com") { return path.contains("/media/") }

        let fileName = url.lastPathComponent.lowercased()
        if fileName.contains("favicon") || fileName.contains("apple-touch-icon") { return false }
        return true
    }

    /// 保存が「中身の画像」のURLを持っているか。実データを読まずに文字列だけで判定する。
    static func hasContentThumbnailURL(_ item: SavedItem) -> Bool {
        guard let thumbnailURLString = item.thumbnailURLString,
              !thumbnailURLString.isEmpty,
              let url = URL(string: thumbnailURLString) else { return false }
        return isContentImageURL(url)
    }
}

/// 表紙の状態を少しずつ確定させる後処理。
/// 未確定のあいだ一覧は仮画像を出すので、この処理が終わる前でも通常どおり操作できる。
@MainActor
enum CoverArtworkPreparer {
    /// すでに保存されているプロフィール画像やロゴのURLを表紙から外す。
    /// 文字列の判定だけなので、実データは読まない。
    @discardableResult
    static func clearNonContentThumbnails(in modelContext: ModelContext) -> Int {
        guard let items = try? modelContext.fetch(FetchDescriptor<SavedItem>()) else { return 0 }
        var clearedCount = 0
        for item in items {
            guard let thumbnailURLString = item.thumbnailURLString, !thumbnailURLString.isEmpty else { continue }
            guard let url = URL(string: thumbnailURLString), !CoverArtwork.isContentImageURL(url) else { continue }
            item.thumbnailURLString = nil
            if !item.hasScreenshot, item.coverState == .artwork {
                item.coverState = .none
            }
            clearedCount += 1
        }
        if clearedCount > 0 { try? modelContext.save() }
        return clearedCount
    }

    /// 表紙が未確定の保存を、1件ずつ確定させる。
    /// 縮小はバックグラウンドで行い、1件ごとに主スレッドを譲るのでスクロールを止めない。
    /// 与えた時間を超えたら残りは次回起動に回す。残っているあいだ一覧は仮画像を出す。
    @discardableResult
    static func prepareMissingCovers(
        in modelContext: ModelContext,
        budget: Duration = .seconds(4)
    ) async -> Int {
        guard let items = try? modelContext.fetch(FetchDescriptor<SavedItem>()) else { return 0 }
        let pendingItems = items
            .filter { $0.coverState == .unknown }
            .sorted { $0.createdAt > $1.createdAt }
        guard !pendingItems.isEmpty else { return 0 }

        let clock = ContinuousClock()
        let startedAt = clock.now
        var preparedCount = 0

        for item in pendingItems {
            if clock.now - startedAt > budget { break }

            // 実データを読むのはここだけ。1件ずつに限る。
            let screenshotData = item.screenshotImageData
            if let screenshotData, !screenshotData.isEmpty {
                item.hasScreenshot = true
                let thumbnailData = await Task.detached(priority: .utility) {
                    CoverArtwork.downsampledJPEGData(from: screenshotData, maxPixelSize: CoverArtwork.listMaxPixelSize)
                }.value
                item.coverThumbnailData = thumbnailData
                item.coverState = thumbnailData == nil ? .none : .artwork
            } else {
                item.hasScreenshot = false
                item.coverState = CoverArtwork.hasContentThumbnailURL(item) ? .artwork : .none
            }

            preparedCount += 1
            // 書き込みをまとめて、保存のたびに主スレッドを止めないようにする。
            if preparedCount.isMultiple(of: 8) { try? modelContext.save() }
            await Task.yield()
        }

        try? modelContext.save()
        return preparedCount
    }
}
