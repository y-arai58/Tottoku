import SwiftUI

struct SavedItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: SavedItem?
    let categories: [Category]
    let onCreate: ((SavedItem) -> Void)?

    @State private var urlString: String
    @State private var title: String
    @State private var bodyText: String
    @State private var author: String
    @State private var summary: String
    @State private var categoryName: String
    @State private var tagText: String

    init(item: SavedItem? = nil, categories: [Category], onCreate: ((SavedItem) -> Void)? = nil) {
        self.item = item
        self.categories = categories
        self.onCreate = onCreate
        _urlString = State(initialValue: item?.urlString ?? "")
        _title = State(initialValue: item?.title ?? "")
        _bodyText = State(initialValue: item?.bodyText ?? "")
        _author = State(initialValue: item?.author ?? "")
        _summary = State(initialValue: item?.summary ?? "")
        _categoryName = State(initialValue: item?.categoryName ?? categories.first?.name ?? "その他")
        _tagText = State(initialValue: item?.tagNames.joined(separator: ", ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("URL", text: $urlString, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("タイトル", text: $title)
                    TextField("投稿者（任意）", text: $author)
                } header: {
                    FudgeLabel("clipping", color: Fudge.camel, size: 8)
                }
                Section {
                    Picker("カテゴリ", selection: $categoryName) {
                        ForEach(categories) { category in Text(category.name).tag(category.name) }
                    }
                    TextField("タグ（カンマ区切り）", text: $tagText)
                    TextField("短い要約（任意）", text: $summary, axis: .vertical)
                    TextField("メモ・投稿本文（任意）", text: $bodyText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    FudgeLabel("index", color: Fudge.camel, size: 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Fudge.paper)
            .navigationTitle(item == nil ? "保存を追加" : "保存を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fudge.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(Fudge.camel)
    }

    private func save() {
        let tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let item {
            item.urlString = urlString
            item.sourceRawValue = SavedSource.infer(from: urlString).rawValue
            item.title = title
            item.bodyText = bodyText
            item.author = author
            item.summary = summary
            item.categoryName = categoryName
            item.tagNames = tags
            item.classificationStateRawValue = ClassificationState.edited.rawValue
        } else {
            onCreate?(SavedItem(urlString: urlString, source: .infer(from: urlString), title: title, bodyText: bodyText, author: author, summary: summary, categoryName: categoryName, tagNames: tags))
        }
        dismiss()
    }
}
