import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool { true }

    override func configurationItems() -> [Any]! { [] }

    override func didSelectPost() {
        Task { @MainActor in
            do {
                try SharedInbox.enqueue(await extractIncomingShare())
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                extensionContext?.cancelRequest(withError: error)
            }
        }
    }

    private func extractIncomingShare() async -> IncomingShare {
        var sharedURL: URL?
        var sharedText: [String] = [contentText]

        let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        for item in inputItems {
            for provider in item.attachments ?? [] {
                if sharedURL == nil, let url = await loadURL(from: provider) {
                    sharedURL = url
                }
                if let text = await loadText(from: provider), !text.isEmpty {
                    sharedText.append(text)
                }
            }
        }

        return IncomingShare(
            urlString: sharedURL?.absoluteString,
            text: sharedText.filter { !$0.isEmpty }.joined(separator: "\n")
        )
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String
    }
}
