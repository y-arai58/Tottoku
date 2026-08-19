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
        var sharedTitles: [String] = []

        let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        for item in inputItems {
            if let title = item.attributedTitle?.string {
                sharedTitles.append(title)
            }
            if let content = item.attributedContentText?.string {
                sharedText.append(content)
            }
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
            title: firstNonEmptyValue(in: sharedTitles),
            text: uniqueNonEmptyValues(in: sharedText).joined(separator: "\n")
        )
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let textType = [UTType.plainText, .text]
            .first { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        guard let textType,
              let value = try? await provider.loadItem(forTypeIdentifier: textType.identifier, options: nil) else {
            return nil
        }
        if let string = value as? String { return string }
        if let string = value as? NSString { return string as String }
        if let attributedString = value as? NSAttributedString { return attributedString.string }
        return nil
    }

    private func firstNonEmptyValue(in values: [String]) -> String? {
        uniqueNonEmptyValues(in: values).first
    }

    private func uniqueNonEmptyValues(in values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }
}
