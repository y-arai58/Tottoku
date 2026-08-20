import SwiftUI
import SwiftData
import UIKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedItem.createdAt, order: .reverse) private var items: [SavedItem]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var searchText = ""
    @State private var selectedCategory = "すべて"
    @State private var isPresentingAddItem = false
    @State private var isPresentingShortcutGuide = false
    @AppStorage("hasDismissedShortcutSetupTip") private var hasDismissedShortcutSetupTip = false

    private var visibleCategories: [Category] { categories.filter { !$0.isArchived } }

    private var filteredItems: [SavedItem] {
        items.filter { item in
            let isInCategory = selectedCategory == "すべて" || item.categoryName == selectedCategory
            guard isInCategory else { return false }
            guard !searchText.isEmpty else { return true }
            let query = searchText.localizedLowercase
            return [item.title, item.bodyText, item.summary, item.categoryName, item.author, item.source.displayName]
                .contains { $0.localizedLowercase.contains(query) }
                || item.tagNames.contains { $0.localizedLowercase.contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                categoryFilter

                if !hasDismissedShortcutSetupTip {
                    shortcutSetupTip
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }

                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "まだ保存はありません" : "見つかりませんでした",
                        systemImage: searchText.isEmpty ? "bookmark" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "右上の＋からURLを保存してみましょう。" : "別のキーワードやカテゴリで探してみてください。")
                    )
                    .padding(.top, 72)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                SavedItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Saves")
            .navigationDestination(for: SavedItem.self) { item in
                SavedItemDetailView(item: item, categories: visibleCategories)
            }
            .searchable(text: $searchText, prompt: "保存したものを検索")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("保存の設定", systemImage: "questionmark.circle") {
                        isPresentingShortcutGuide = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加", systemImage: "plus") { isPresentingAddItem = true }
                }
            }
            .sheet(isPresented: $isPresentingAddItem) {
                SavedItemEditor(categories: visibleCategories) { draft in
                    modelContext.insert(draft)
                }
            }
            .sheet(isPresented: $isPresentingShortcutGuide) {
                ShortcutSetupGuide {
                    hasDismissedShortcutSetupTip = true
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CategoryChip(name: "すべて", isSelected: selectedCategory == "すべて") { selectedCategory = "すべて" }
                ForEach(visibleCategories) { category in
                    CategoryChip(name: category.name, isSelected: selectedCategory == category.name) {
                        selectedCategory = category.name
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var shortcutSetupTip: some View {
        Button { isPresentingShortcutGuide = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("背面タップでスクショ保存")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("ショートカットの設定方法を見る")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    let didComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 78, height: 78)
                        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 7) {
                        Text("背面タップで保存")
                            .font(.title2.bold())
                        Text("画面のスクリーンショットと、コピーしたリンクをまとめてTottokuに保存できます。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        ShortcutGuideStep(number: "1", title: "投稿のリンクをコピー", detail: "Safari・X・Instagramなどで保存したい投稿のリンクをコピーします。")
                        ShortcutGuideStep(number: "2", title: "ショートカットを作る", detail: "「スクリーンショットを撮る」→「クリップボードを取得」→「Tottokuにスクリーンショットを保存」の順に追加します。")
                        ShortcutGuideStep(number: "3", title: "出力をつなぐ", detail: "スクリーンショットを「スクリーンショット」へ、クリップボードを「ページのリンク」へ指定します。")
                        ShortcutGuideStep(number: "4", title: "背面タップに割り当てる", detail: "設定 ＞ アクセシビリティ ＞ タッチ ＞ 背面タップ で、作成したショートカットを選びます。")
                    }

                    Text("他のアプリで開いているリンクは、プライバシー保護のためTottokuが直接読み取れません。保存前にリンクをコピーしてください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))

                    Button("設定できた") {
                        didComplete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("スクショ保存の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct ShortcutGuideStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 27, height: 27)
                .background(.indigo, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(isSelected ? Color.indigo : Color(uiColor: .secondarySystemFill), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

private struct SavedItemCard: View {
    let item: SavedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: sourceColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let screenshotData = item.screenshotImageData,
                              let screenshot = UIImage(data: screenshotData) {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else if let url = URL(string: item.thumbnailURLString ?? "") {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView().tint(.white)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    } else {
                        Image(systemName: item.source.symbolName)
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if item.thumbnailURLString != nil {
                        LinearGradient(colors: [.clear, .black.opacity(0.32)], startPoint: .center, endPoint: .bottom)
                    }
                    Text(item.source.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .aspectRatio(1, contentMode: .fit)

            Text(item.summary.isEmpty ? item.title : item.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.categoryName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceColors: [Color] {
        switch item.source {
        case .instagram: [.pink, .orange]
        case .x: [.cyan, .blue]
        case .threads: [.gray, .black]
        case .safari: [.blue, .mint]
        case .web, .unknown: [.indigo, .purple]
        }
    }
}

private struct SavedItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    let item: SavedItem
    let categories: [Category]
    @State private var isEditing = false
    @State private var isRefreshingMetadata = false
    @State private var isPresentingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                preview

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.summary.isEmpty ? item.title : item.summary)
                        .font(.title2.bold())
                    Text(item.categoryName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    if !item.tagNames.isEmpty {
                        FlowLayout(spacing: 7) {
                            ForEach(item.tagNames, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .secondarySystemFill), in: Capsule())
                            }
                        }
                    }
                }

                LabeledContent("source", value: item.source.displayName)
                if !item.author.isEmpty { LabeledContent("投稿者", value: item.author) }
                if !item.bodyText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("メモ・投稿本文").font(.headline)
                        Text(item.bodyText).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "投稿本文は保存されていません",
                        systemImage: "text.document",
                        description: Text("XやInstagramが共有時にURLだけを渡す場合があります。必要なら編集からメモを追加できます。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Button {
                    Task {
                        isRefreshingMetadata = true
                        _ = await SharedInboxImporter.refreshLinkMetadata(for: item, in: modelContext)
                        isRefreshingMetadata = false
                    }
                } label: {
                    Label(isRefreshingMetadata ? "リンク情報を取得中…" : "リンク情報を再取得", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshingMetadata || item.urlString.isEmpty)

                Button {
                    guard let url = URL(string: item.urlString) else { return }
                    openURL(url)
                } label: {
                    Label("元の投稿を見る", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("保存した投稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { isEditing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { isPresentingDeleteConfirmation = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            SavedItemEditor(item: item, categories: categories)
        }
        .confirmationDialog("この保存を削除しますか？", isPresented: $isPresentingDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(.indigo.gradient)
            if let screenshotData = item.screenshotImageData,
                      let screenshot = UIImage(data: screenshotData) {
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = URL(string: item.thumbnailURLString ?? "") {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                Image(systemName: item.source.symbolName)
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var position = CGPoint.zero
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x + size.width > maxWidth, position.x > 0 {
                position.x = 0
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: position.y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var position = bounds.origin
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x + size.width > bounds.maxX, position.x > bounds.minX {
                position.x = bounds.minX
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: position, proposal: ProposedViewSize(size))
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
