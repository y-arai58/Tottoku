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
    @State private var isSelectingItems = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var isPresentingBulkDeleteConfirmation = false
    @AppStorage("hasDismissedShortcutSetupTip") private var hasDismissedShortcutSetupTip = false

    private var visibleCategories: [Category] { categories.filter { !$0.isArchived } }

    private var filteredItems: [SavedItem] {
        items.filter { item in
            let isInCategory = selectedCategory == "すべて" || item.categoryName == selectedCategory
            guard isInCategory else { return false }
            guard !searchText.isEmpty else { return true }
            let query = searchText.localizedLowercase
            return [item.title, item.bodyText, item.recognizedText ?? "", item.summary, item.categoryName, item.author, item.source.displayName]
                .contains { $0.localizedLowercase.contains(query) }
                || item.tagNames.contains { $0.localizedLowercase.contains(query) }
        }
    }

    /// 最新の1件が写真を持つときだけ表紙にする。選択中は誌面を崩さないよう表紙を出さない。
    private var coverItem: SavedItem? {
        guard !isSelectingItems, let newest = filteredItems.first, newest.showsCoverArea else { return nil }
        return newest
    }

    private var gridItems: [SavedItem] {
        guard let coverItem else { return filteredItems }
        return filteredItems.filter { $0.id != coverItem.id }
    }

    /// 保存が何か月分あるかを号数として使う。
    private var issueNumber: Int {
        let calendar = Calendar.current
        let months = items.map { calendar.dateComponents([.year, .month], from: $0.createdAt) }
        return max(1, Set(months.map { "\($0.year ?? 0)-\($0.month ?? 0)" }).count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    masthead
                    categoryFilter

                    if !hasDismissedShortcutSetupTip {
                        shortcutSetupTip
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                    }

                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        if let coverItem {
                            cover(for: coverItem)
                                .padding(.bottom, 20)
                        }
                        FudgeSectionRule(title: sectionTitle, trailing: "\(filteredItems.count) clips")
                            .padding(.horizontal, 20)
                            .padding(.bottom, 13)
                        grid
                        folio
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Fudge.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fudge.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: SavedItem.self) { item in
                SavedItemDetailView(item: item, categories: visibleCategories)
            }
            .searchable(text: $searchText, prompt: "保存したものを検索")
            .toolbar {
                if isSelectingItems {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル") { endSelection() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            isPresentingBulkDeleteConfirmation = true
                        } label: {
                            Label("削除 (\(selectedItemIDs.count))", systemImage: "trash")
                        }
                        .disabled(selectedItemIDs.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("保存の設定", systemImage: "questionmark.circle") {
                            isPresentingShortcutGuide = true
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("選択") { isSelectingItems = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("追加", systemImage: "plus") { isPresentingAddItem = true }
                    }
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
            .confirmationDialog(
                "選択した\(selectedItemIDs.count)件を削除しますか？",
                isPresented: $isPresentingBulkDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) { deleteSelectedItems() }
            } message: {
                Text("削除した保存は元に戻せません。")
            }
        }
        .tint(Fudge.camel)
    }

    private var sectionTitle: String {
        selectedCategory == "すべて" ? "all clippings" : selectedCategory
    }

    private var masthead: some View {
        VStack(spacing: 0) {
            HStack {
                FudgeLabel("vol. \(issueNumber)", size: 8)
                Spacer()
                FudgeLabel(Fudge.issueText(), size: 8)
            }
            Text("TOTTOKU")
                .font(Fudge.serif(27, weight: .bold))
                .tracking(2.6)
                .foregroundStyle(Fudge.ink)
                .padding(.top, 4)
            Text("my clipping book")
                .font(Fudge.serif(11))
                .italic()
                .foregroundStyle(Fudge.camel)
                .padding(.top, 3)
            FudgeDoubleRule()
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                CategoryChip(name: "すべて", isSelected: selectedCategory == "すべて") { selectedCategory = "すべて" }
                ForEach(visibleCategories) { category in
                    CategoryChip(name: category.name, isSelected: selectedCategory == category.name) {
                        selectedCategory = category.name
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
        }
        .scrollIndicators(.hidden)
    }

    private func cover(for item: SavedItem) -> some View {
        NavigationLink(value: item) {
            FudgeCoverPlate(item: item)
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)],
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(gridItems) { item in
                if isSelectingItems {
                    Button {
                        toggleSelection(for: item)
                    } label: {
                        SavedItemCard(item: item, isSelected: selectedItemIDs.contains(item.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title)を\(selectedItemIDs.contains(item.id) ? "選択解除" : "選択")")
                } else {
                    NavigationLink(value: item) {
                        SavedItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var folio: some View {
        VStack(spacing: 0) {
            FudgeRule(color: Fudge.ink)
            HStack {
                Text("とっとく")
                    .font(Fudge.serif(9))
                    .tracking(2.2)
                    .foregroundStyle(Fudge.mutedInk)
                Spacer()
                FudgeLabel("\(items.count) saved", size: 8)
            }
            .padding(.top, 9)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text(searchText.isEmpty ? "no clippings yet" : "not found")
                .font(Fudge.serif(12))
                .italic()
                .foregroundStyle(Fudge.camel)
            Text(searchText.isEmpty ? "まだ保存はありません" : "見つかりませんでした")
                .font(Fudge.serif(19))
                .foregroundStyle(Fudge.ink)
                .padding(.top, 9)
            Text(searchText.isEmpty ? "右上の＋からURLを保存すると、この号の1ページ目になります。" : "別のキーワードやカテゴリで探してみてください。")
                .font(.system(size: 12))
                .foregroundStyle(Fudge.mutedInk)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            FudgeRule()
                .frame(width: 46)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 44)
        .padding(.top, 64)
    }

    private var shortcutSetupTip: some View {
        Button { isPresentingShortcutGuide = true } label: {
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    FudgeLabel("back tap", color: Fudge.camel, size: 8)
                    Text("背面タップでスクショを保存する")
                        .font(Fudge.serif(13))
                        .foregroundStyle(Fudge.ink)
                    Text("ショートカットの設定方法を見る")
                        .font(.system(size: 10))
                        .foregroundStyle(Fudge.mutedInk)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Fudge.camel)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .overlay(Rectangle().stroke(Fudge.ink.opacity(0.28), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(for item: SavedItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func endSelection() {
        selectedItemIDs.removeAll()
        isSelectingItems = false
    }

    private func deleteSelectedItems() {
        let idsToDelete = selectedItemIDs
        for item in items where idsToDelete.contains(item.id) {
            modelContext.delete(item)
        }
        try? modelContext.save()
        endSelection()
    }
}

private struct ShortcutSetupGuide: View {
    @Environment(\.dismiss) private var dismiss
    let didComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        FudgeLabel("how to", color: Fudge.camel, size: 8)
                        Text("背面タップで保存")
                            .font(Fudge.serif(23))
                            .foregroundStyle(Fudge.ink)
                        Text("画面のスクリーンショットと、コピーしたリンクをまとめてTottokuに保存できます。")
                            .font(.system(size: 13))
                            .foregroundStyle(Fudge.mutedInk)
                    }
                    FudgeDoubleRule()

                    VStack(spacing: 0) {
                        ShortcutGuideStep(number: "01", title: "投稿のリンクをコピー", detail: "Safari・X・Instagramなどで保存したい投稿のリンクをコピーします。")
                        ShortcutGuideStep(number: "02", title: "ショートカットを作る", detail: "「スクリーンショットを撮る」→「クリップボードを取得」→「Tottokuにスクリーンショットを保存」の順に追加します。")
                        ShortcutGuideStep(number: "03", title: "出力をつなぐ", detail: "スクリーンショットを「スクリーンショット」へ、クリップボードを「ページのリンク」へ指定します。")
                        ShortcutGuideStep(number: "04", title: "背面タップに割り当てる", detail: "設定 ＞ アクセシビリティ ＞ タッチ ＞ 背面タップ で、作成したショートカットを選びます。")
                    }

                    Text("他のアプリで開いているリンクは、プライバシー保護のためTottokuが直接読み取れません。保存前にリンクをコピーしてください。")
                        .font(.system(size: 11))
                        .foregroundStyle(Fudge.mutedInk)
                        .padding(14)
                        .overlay(Rectangle().stroke(Fudge.ink.opacity(0.28), lineWidth: 0.5))

                    Button {
                        didComplete()
                        dismiss()
                    } label: {
                        Text("設定できた")
                            .font(Fudge.serif(14))
                            .foregroundStyle(Fudge.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Fudge.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Fudge.paper)
            .navigationTitle("スクショ保存の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fudge.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(Fudge.camel)
    }
}

private struct ShortcutGuideStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 13) {
                Text(number)
                    .font(Fudge.serif(12))
                    .foregroundStyle(Fudge.brick)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Fudge.serif(14))
                        .foregroundStyle(Fudge.ink)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Fudge.mutedInk)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
            FudgeRule()
        }
    }
}

private struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(Fudge.serif(12))
                    .tracking(1.4)
                    .foregroundStyle(isSelected ? Fudge.ink : Fudge.mutedInk)
                Rectangle()
                    .fill(isSelected ? Fudge.camel : .clear)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 表紙。写真の上に紙色のキャプションプレートを重ねる、誌面の版面の作り方。
private struct FudgeCoverPlate: View {
    let item: SavedItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Fudge.rule.opacity(0.4))
                .aspectRatio(4 / 2.5, contentMode: .fit)
                .overlay { FudgeCoverImage(item: item).fudgeFilmTone() }
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text("cover story")
                    .font(Fudge.serif(9))
                    .italic()
                    .foregroundStyle(Fudge.brick)
                Text(item.summary.isEmpty ? item.title : item.summary)
                    .font(Fudge.serif(15))
                    .foregroundStyle(Fudge.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                FudgeLabel("\(item.categoryName) — \(item.source.displayName) / \(Fudge.clipDateText(for: item.createdAt))", size: 7.5)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(Fudge.paper.opacity(0.95))
            .overlay(Rectangle().stroke(Fudge.ink.opacity(0.3), lineWidth: 0.5))
            .padding(10)
            .padding(.trailing, 44)
        }
        .padding(.horizontal, 20)
    }
}

/// 一覧のカード。写真を持つ保存は表紙写真、持たない保存はタイトルだけの版面で見せる。
private struct SavedItemCard: View {
    let item: SavedItem
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if item.showsCoverArea {
                Rectangle()
                    .fill(Fudge.rule.opacity(0.4))
                    .aspectRatio(1 / 1.02, contentMode: .fit)
                    .overlay { FudgeCoverImage(item: item).fudgeFilmTone() }
                    .clipped()

                Text(item.summary.isEmpty ? item.title : item.summary)
                    .font(Fudge.serif(12.5))
                    .foregroundStyle(Fudge.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FudgeLabel(metaText, size: 7.5)
            } else {
                titlePlate
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Fudge.paper)
                    .frame(width: 22, height: 22)
                    .background(Fudge.ink)
                    .padding(7)
                    .accessibilityHidden(true)
            }
        }
    }

    /// 写真がない保存は、タイトルそのものを版面の主役にする。
    private var titlePlate: some View {
        VStack(alignment: .leading, spacing: 8) {
            FudgeLabel(item.categoryName, color: Fudge.camel, size: 8)
            FudgeRule()
            Text(item.summary.isEmpty ? item.title : item.summary)
                .font(Fudge.serif(14.5))
                .foregroundStyle(Fudge.ink)
                .lineLimit(6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            FudgeRule()
            FudgeLabel("\(item.source.displayName) / \(Fudge.clipDateText(for: item.createdAt))", size: 7.5)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 168, maxHeight: .infinity, alignment: .topLeading)
        .overlay(Rectangle().stroke(Fudge.ink.opacity(0.28), lineWidth: 0.5))
    }

    private var metaText: String {
        "\(item.categoryName) — \(item.source.displayName) / \(Fudge.clipDateText(for: item.createdAt))"
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

    private var sourceURL: URL? {
        guard let url = URL(string: item.urlString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if !item.tagNames.isEmpty {
                    FlowLayout(spacing: 7) {
                        ForEach(item.tagNames, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11))
                                .foregroundStyle(Fudge.ink)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .overlay(Rectangle().stroke(Fudge.rule, lineWidth: 1))
                        }
                    }
                }

                detailRow(label: "source", value: item.source.displayName)
                if !item.author.isEmpty {
                    detailRow(label: "author", value: item.author)
                }
                detailRow(label: "saved", value: Fudge.clipDateText(for: item.createdAt))

                if !item.bodyText.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        FudgeSectionRule(title: "text")
                        Text(item.bodyText)
                            .font(.system(size: 13))
                            .foregroundStyle(Fudge.ink)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        FudgeSectionRule(title: "text")
                        Text("投稿本文は保存されていません。XやInstagramが共有時にURLだけを渡す場合があります。必要なら編集からメモを追加できます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Fudge.mutedInk)
                    }
                }

                if let recognizedText = item.recognizedText, !recognizedText.isEmpty {
                    DisclosureGroup {
                        Text(recognizedText)
                            .font(.system(size: 12))
                            .foregroundStyle(Fudge.mutedInk)
                            .textSelection(.enabled)
                            .padding(.top, 8)
                    } label: {
                        FudgeLabel("text in image", color: Fudge.ink, size: 9)
                    }
                    .tint(Fudge.camel)
                }

                VStack(spacing: 11) {
                    Button {
                        Task {
                            isRefreshingMetadata = true
                            _ = await SharedInboxImporter.refreshLinkMetadata(for: item, in: modelContext)
                            isRefreshingMetadata = false
                        }
                    } label: {
                        Text(isRefreshingMetadata ? "リンク情報を取得中…" : "リンク情報を再取得")
                            .font(Fudge.serif(13))
                            .foregroundStyle(Fudge.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(Rectangle().stroke(Fudge.ink.opacity(0.35), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingMetadata || sourceURL == nil)
                    .opacity(isRefreshingMetadata || sourceURL == nil ? 0.4 : 1)

                    if let sourceURL {
                        Button {
                            openURL(sourceURL)
                        } label: {
                            Text("元の投稿を見る")
                                .font(Fudge.serif(14))
                                .foregroundStyle(Fudge.paper)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Fudge.ink)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Fudge.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Fudge.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    /// 写真を持つ保存だけ大きな図版を出す。持たない保存はタイトルの版面だけで始める。
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if item.showsCoverArea {
                Rectangle()
                    .fill(Fudge.rule.opacity(0.4))
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay { FudgeDetailImage(item: item) }
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                FudgeLabel(item.categoryName, color: Fudge.camel, size: 9)
                Text(item.summary.isEmpty ? item.title : item.summary)
                    .font(Fudge.serif(23))
                    .foregroundStyle(Fudge.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.summary.isEmpty, item.summary != item.title {
                    Text(item.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Fudge.mutedInk)
                }
            }
            FudgeDoubleRule()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(spacing: 7) {
            HStack {
                FudgeLabel(label, size: 8)
                Spacer()
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Fudge.ink)
            }
            FudgeRule()
        }
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
