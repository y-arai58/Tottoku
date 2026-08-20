import AppIntents
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

struct SaveScreenshotToTottokuIntent: AppIntent {
    static let title: LocalizedStringResource = "Tottokuにスクリーンショットを保存"
    static let description = IntentDescription("スクリーンショットと、必要に応じてページのリンクをTottokuに保存します。")

    @Parameter(title: "スクリーンショット", supportedContentTypes: [.image])
    var screenshot: IntentFile?

    @Parameter(title: "ページのリンク")
    var pageURL: URL?

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let screenshot else { throw ScreenshotSaveError.missingScreenshot }
        let title = pageURL?.host ?? "スクリーンショット"
        try SharedInbox.enqueueScreenshot(
            screenshot.data,
            urlString: pageURL?.absoluteString,
            title: title
        )
        return .result(dialog: "Tottokuに保存しました")
    }
}

private enum ScreenshotSaveError: LocalizedError {
    case missingScreenshot

    var errorDescription: String? {
        "保存するスクリーンショットを選んでください。"
    }
}

struct TottokuShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveScreenshotToTottokuIntent(),
            phrases: ["\(.applicationName)にスクリーンショットを保存"],
            shortTitle: "スクリーンショットを保存",
            systemImageName: "camera.viewfinder"
        )
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Category.order) private var categories: [Category]
    @State private var isImportingSharedPosts = false
    @State private var isProcessingLibraryData = false

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
        scheduleLibraryPostProcessing()
    }

    private func scheduleLibraryPostProcessing() {
        guard !isProcessingLibraryData else { return }
        isProcessingLibraryData = true
        let categoryNames = categories.filter { !$0.isArchived }.map(\.name)
        Task(priority: .utility) {
            // Let the library render and accept taps before potentially slow network and AI work starts.
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(400))
            _ = await SharedInboxImporter.refreshPlaceholderLinkTitles(in: modelContext, limit: 3)
            _ = await SavedItemClassifier.classifyPendingItems(
                in: modelContext,
                categoryNames: categoryNames,
                limit: 3
            )
            isProcessingLibraryData = false
        }
    }
}
