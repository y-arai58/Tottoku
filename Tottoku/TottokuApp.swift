import SwiftUI
import SwiftData

@main
struct TottokuApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([SavedItem.self, Category.self])
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("データベースを準備できませんでした: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var isImportingSharedPosts = false

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("ライブラリ", systemImage: "square.grid.2x2") }

            CategorySettingsView()
                .tabItem { Label("カテゴリ", systemImage: "slider.horizontal.3") }
        }
        .tint(.indigo)
        .task {
            CategorySeed.insertIfNeeded(into: modelContext, categories: categories)
            await importSharedPosts()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await importSharedPosts() }
        }
    }

    private func importSharedPosts() async {
        guard !isImportingSharedPosts else { return }
        isImportingSharedPosts = true
        defer { isImportingSharedPosts = false }
        _ = await SharedInboxImporter.importPendingShares(into: modelContext)
        let categoryNames = categories.filter { !$0.isArchived }.map(\.name)
        _ = await SavedItemClassifier.classifyPendingItems(in: modelContext, categoryNames: categoryNames)
    }
}
