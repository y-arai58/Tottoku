import SwiftData

enum CategorySeed {
    static let defaults = ["勉強", "食べ物", "コスメ", "服", "旅行", "インテリア", "健康", "買い物", "技術", "その他"]

    static func insertIfNeeded(into context: ModelContext, categories: [Category]) {
        guard categories.isEmpty else { return }
        for (index, name) in defaults.enumerated() {
            context.insert(Category(name: name, order: index))
        }
    }
}
