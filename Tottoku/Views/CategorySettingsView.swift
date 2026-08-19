import SwiftUI
import SwiftData

struct CategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var isPresentingAddCategory = false

    var body: some View {
        NavigationStack {
            List {
                Section("表示中") {
                    ForEach(categories.filter { !$0.isArchived }) { category in
                        Text(category.name)
                    }
                    .onDelete(perform: archive)
                }
                let archived = categories.filter(\.isArchived)
                if !archived.isEmpty {
                    Section("非表示") {
                        ForEach(archived) { category in
                            Button(category.name) { category.isArchived = false }
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加", systemImage: "plus") { isPresentingAddCategory = true }
                }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
            }
            .alert("カテゴリを追加", isPresented: $isPresentingAddCategory) {
                TextField("カテゴリ名", text: $newCategoryName)
                Button("追加") { addCategory() }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    @State private var newCategoryName = ""

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !categories.contains(where: { $0.name == name }) else { return }
        modelContext.insert(Category(name: name, order: categories.count))
        newCategoryName = ""
    }

    private func archive(at offsets: IndexSet) {
        let visible = categories.filter { !$0.isArchived }
        for index in offsets { visible[index].isArchived = true }
    }
}
