import SwiftUI
import UIKit

/// FUDGEのような大人カジュアル誌の誌面をイメージした共通スタイル。
/// 生成りの紙・墨・キャメルの3色と、英文セリフ＋小さな明朝で全画面を揃える。
enum Fudge {
    static let paper = Color(red: 0.969, green: 0.953, blue: 0.918)
    static let ink = Color(red: 0.184, green: 0.165, blue: 0.141)
    static let camel = Color(red: 0.725, green: 0.541, blue: 0.310)
    static let brick = Color(red: 0.647, green: 0.263, blue: 0.173)
    static let rule = Color(red: 0.835, green: 0.796, blue: 0.718)
    static let mutedInk = Color(red: 0.557, green: 0.510, blue: 0.443)

    /// 誌名や見出し。iOSではserifデザインに New York と ヒラギノ明朝 が割り当たる。
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    private static let issueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private static let clipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M.d"
        return formatter
    }()

    /// 刊記に使う「AUG 2026」表記。
    static func issueText(for date: Date = .now) -> String {
        issueFormatter.string(from: date).uppercased()
    }

    /// キャプションに使う「8.18」表記。
    static func clipDateText(for date: Date) -> String {
        clipFormatter.string(from: date)
    }
}

/// 英字の小ラベル。字間を広げて小キャプス風に見せる。
struct FudgeLabel: View {
    let text: String
    var color: Color = Fudge.mutedInk
    var size: CGFloat = 9

    init(_ text: String, color: Color = Fudge.mutedInk, size: CGFloat = 9) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .regular))
            .tracking(size * 0.22)
            .foregroundStyle(color)
    }
}

/// 誌面の細い罫線。
struct FudgeRule: View {
    var color: Color = Fudge.rule

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

/// 誌名の下に敷く二重罫。
struct FudgeDoubleRule: View {
    var body: some View {
        VStack(spacing: 2) {
            FudgeRule(color: Fudge.ink)
            FudgeRule(color: Fudge.ink)
        }
    }
}

/// 「ALL CLIPPINGS ——— 142 CLIPS」のような見出し罫。
struct FudgeSectionRule: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 9) {
            Text(title.uppercased())
                .font(Fudge.serif(10))
                .tracking(3.2)
                .foregroundStyle(Fudge.ink)
            FudgeRule()
            if let trailing {
                FudgeLabel(trailing, color: Fudge.camel, size: 8)
            }
        }
    }
}

extension View {
    /// 誌面のトーンに寄せる軽いフィルム調。
    /// 元の色を確認したい詳細画面には適用せず、一覧のサムネイルだけに使う。
    func fudgeFilmTone() -> some View {
        saturation(0.8)
            .contrast(1.03)
            .colorMultiply(Color(red: 1.0, green: 0.973, blue: 0.925))
    }
}

/// 表紙の読み込みが終わるまで置く仮画像。
/// 版面の大きさを先に確定させるので、写真が届いても一覧が飛び跳ねない。
struct FudgeCoverPlaceholder: View {
    var label = "developing"

    var body: some View {
        ZStack {
            Fudge.rule.opacity(0.32)
            Rectangle()
                .stroke(Fudge.ink.opacity(0.12), lineWidth: 0.5)
                .padding(7)
            Text(label)
                .font(Fudge.serif(9))
                .italic()
                .tracking(0.8)
                .foregroundStyle(Fudge.mutedInk)
        }
    }
}

/// 一覧の表紙。縮小画像があればそれを、無ければ仮画像を出す。
/// 巨大な`screenshotImageData`はここでは読まない。
struct FudgeCoverImage: View {
    let item: SavedItem

    var body: some View {
        if let coverThumbnailData = item.coverThumbnailData,
           let thumbnail = UIImage(data: coverThumbnailData) {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else if item.hasCoverArtwork,
                  let thumbnailURLString = item.thumbnailURLString,
                  let url = URL(string: thumbnailURLString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    FudgeCoverPlaceholder(label: "no image")
                default:
                    FudgeCoverPlaceholder()
                }
            }
        } else {
            FudgeCoverPlaceholder()
        }
    }
}

/// 詳細画面の図版。まず一覧用の縮小画像を出し、原寸の縮小が終わったら差し替える。
/// 元の色を確認する画面なので、誌面のフィルム調はかけない。
struct FudgeDetailImage: View {
    let item: SavedItem
    @State private var fullImageData: Data?

    var body: some View {
        ZStack {
            if let fullImageData, let image = UIImage(data: fullImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                FudgeCoverImage(item: item)
            }
        }
        .task(id: item.id) { await loadFullImage() }
    }

    private func loadFullImage() async {
        guard item.hasScreenshot, fullImageData == nil else { return }
        guard let screenshotData = item.screenshotImageData, !screenshotData.isEmpty else { return }
        fullImageData = await Task.detached(priority: .userInitiated) {
            CoverArtwork.downsampledJPEGData(from: screenshotData, maxPixelSize: CoverArtwork.detailMaxPixelSize)
        }.value
    }
}

/// ナビゲーションバーとタブバーを紙色に揃える。誌面の地色が途切れないようにする。
@MainActor
enum FudgeAppearance {
    static func apply() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(Fudge.paper)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .font: serifFont(size: 15, weight: .semibold),
            .foregroundColor: UIColor(Fudge.ink)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar

        let tabBarItem = UITabBarItemAppearance()
        let tabFont = serifFont(size: 10)
        tabBarItem.normal.titleTextAttributes = [
            .font: tabFont,
            .kern: 1.8,
            .foregroundColor: UIColor(Fudge.mutedInk)
        ]
        tabBarItem.selected.titleTextAttributes = [
            .font: tabFont,
            .kern: 1.8,
            .foregroundColor: UIColor(Fudge.ink)
        ]

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(Fudge.paper)
        tabBar.shadowColor = UIColor(Fudge.ink.opacity(0.3))
        tabBar.stackedLayoutAppearance = tabBarItem
        tabBar.inlineLayoutAppearance = tabBarItem
        tabBar.compactInlineLayoutAppearance = tabBarItem
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }

    private static func serifFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
