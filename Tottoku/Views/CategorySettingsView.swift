import SwiftUI
import SwiftData

struct CategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var isPresentingAddCategory = false
    @State private var categoryToRename: Category?
    @State private var renamedCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories.filter { !$0.isArchived }) { category in
                        Button(category.name) {
                            categoryToRename = category
                            renamedCategoryName = category.name
                        }
                    }
                    .onDelete(perform: archive)
                    .onMove(perform: move)
                } header: {
                    FudgeLabel("in this issue", color: Fudge.camel, size: 8)
                }
                let archived = categories.filter(\.isArchived)
                if !archived.isEmpty {
                    Section {
                        ForEach(archived) { category in
                            Button(category.name) { category.isArchived = false }
                        }
                    } header: {
                        FudgeLabel("archived", color: Fudge.mutedInk, size: 8)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Fudge.paper)
            .navigationTitle("カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fudge.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            .alert("カテゴリ名を変更", isPresented: Binding(
                get: { categoryToRename != nil },
                set: { if !$0 { categoryToRename = nil } }
            )) {
                TextField("カテゴリ名", text: $renamedCategoryName)
                Button("変更") { renameCategory() }
                Button("キャンセル", role: .cancel) { categoryToRename = nil }
            }
        }
        .tint(Fudge.camel)
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

    private func move(from source: IndexSet, to destination: Int) {
        var visible = categories.filter { !$0.isArchived }
        visible.move(fromOffsets: source, toOffset: destination)
        for (index, category) in visible.enumerated() { category.order = index }
    }

    private func renameCategory() {
        guard let category = categoryToRename else { return }
        let name = renamedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !categories.contains(where: { $0.id != category.id && $0.name == name }) else { return }
        let oldName = category.name
        category.name = name
        if let items = try? modelContext.fetch(FetchDescriptor<SavedItem>()) {
            for item in items where item.categoryName == oldName { item.categoryName = name }
        }
        categoryToRename = nil
    }
}
