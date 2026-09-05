// Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift
//
// v0.39 ticket 001 + SMC ticket 003 -- factory + bus builder.
import Foundation
import MarkdownEngine
import MarkdownEngineCodeBlocks

enum WenshuEditorServicesFactory {
    /// Build a MarkdownEditorConfiguration. The bus defaults to
    /// .default; callers pass MarkdownEditorBus.buildWenshu() to
    /// activate format / find / replace routing.
    static func make(
        bookStore: BookStore?,
        bus: MarkdownEditorBus = .default
    ) -> MarkdownEditorConfiguration {
        let wikiLinks: any WikiLinkResolver
        let images: any EmbeddedImageProvider
        if let stores = bookStore?.stores {
            wikiLinks = ReferenceLibraryWikiLinkResolver(
                referenceLibraryRoot: stores.referenceLibraryRoot
            )
            images = ReferenceLibraryImageProvider(
                activeBookRoot: stores.shelvesRoot,
                referenceLibraryRoot: stores.referenceLibraryRoot
            )
        } else {
            wikiLinks = NoOpWikiLinkResolver()
            images = NoOpEmbeddedImageProvider()
        }
        let services = MarkdownEditorServices(
            wikiLinks: wikiLinks,
            images: images,
            syntaxHighlighter: HighlighterSwiftBridge(),
            bus: bus
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        return config
    }

    /// Legacy call site for tests.
    static func make(
        referenceLibraryRoot: URL,
        activeBookRoot: URL?
    ) -> MarkdownEditorConfiguration {
        let services = MarkdownEditorServices(
            wikiLinks: ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: referenceLibraryRoot),
            images: activeBookRoot.map { ReferenceLibraryImageProvider(
                activeBookRoot: $0,
                referenceLibraryRoot: referenceLibraryRoot
            ) } ?? NoOpEmbeddedImageProvider(),
            syntaxHighlighter: HighlighterSwiftBridge()
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        return config
    }
}

// MARK: - MarkdownEditorBus construction (SMC ticket 003)
extension MarkdownEditorBus {
    static func buildWenshu() -> MarkdownEditorBus {
        MarkdownEditorBus(
            applyBoldRequest: Notification.Name("com.wenshu.editor.applyBoldRequest"),
            applyItalicRequest: Notification.Name("com.wenshu.editor.applyItalicRequest"),
            applyHeadingRequest: Notification.Name("com.wenshu.editor.applyHeadingRequest"),
            applyHighlightRequest: Notification.Name("com.wenshu.editor.applyHighlightRequest"),
            applyStrikethroughRequest: Notification.Name("com.wenshu.editor.applyStrikethroughRequest"),
            applyInlineCodeRequest: Notification.Name("com.wenshu.editor.applyInlineCodeRequest"),
            applyBlockquoteRequest: Notification.Name("com.wenshu.editor.applyBlockquoteRequest"),
            applyUnorderedListRequest: Notification.Name("com.wenshu.editor.applyUnorderedListRequest"),
            applyOrderedListRequest: Notification.Name("com.wenshu.editor.applyOrderedListRequest"),
            applyLinkRequest: Notification.Name("com.wenshu.editor.applyLinkRequest"),
            applyCodeBlockRequest: Notification.Name("com.wenshu.editor.applyCodeBlockRequest"),
            applyHorizontalRuleRequest: Notification.Name("com.wenshu.editor.applyHorizontalRuleRequest"),
            applyImageRequest: Notification.Name("com.wenshu.editor.applyImageRequest"),
            selectionBoldDidChange: Notification.Name("com.wenshu.editor.selectionBoldDidChange"),
            selectionItalicDidChange: Notification.Name("com.wenshu.editor.selectionItalicDidChange"),
            selectionHighlightDidChange: Notification.Name("com.wenshu.editor.selectionHighlightDidChange"),
            findScrollToRange: Notification.Name("com.wenshu.editor.findScrollToRange"),
            findClearHighlights: Notification.Name("com.wenshu.editor.findClearHighlights"),
            findQuery: Notification.Name("com.wenshu.editor.findQuery"),
            findResults: Notification.Name("com.wenshu.editor.findResults"),
            replaceCurrent: Notification.Name("com.wenshu.editor.replaceCurrent"),
            replaceAll: Notification.Name("com.wenshu.editor.replaceAll")
        )
    }
}
