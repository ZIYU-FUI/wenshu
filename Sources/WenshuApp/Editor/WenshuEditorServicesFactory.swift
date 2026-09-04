// Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift
//
// v0.39 ticket 001 -- factory that builds MarkdownEditorConfiguration
// (= wraps MarkdownEditorServices) from current AppState + BookStore +
// WenshuLibrary. One configuration instance per edit session (= bound
// to active tab's chapter). HighlighterSwiftBridge is transitive via
// MarkdownEngineCodeBlocks product; SwiftMathBridge is NOT wired
// (= LaTeX is opt-in future).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   MarkdownEditorServices.init(
//     wikiLinks: any WikiLinkResolver = NoOpWikiLinkResolver(),
//     images: any EmbeddedImageProvider = NoOpEmbeddedImageProvider(),
//     syntaxHighlighter: any SyntaxHighlighter = PlainTextSyntaxHighlighter(),
//     latex: any LatexRenderer = NoOpLatexRenderer(),
//     bus: MarkdownEditorBus = .default
//   )
//   MarkdownEditorConfiguration.init(
//     theme: ...,
//     services: MarkdownEditorServices = .default,
//     ...
//   )

import Foundation
import MarkdownEngine
import MarkdownEngineCodeBlocks

enum WenshuEditorServicesFactory {
    /// Build a MarkdownEditorConfiguration for the chapter editor.
    /// Pass `bookStore: nil` to get a no-op configuration (= the
    /// editor still mounts with full markdown styling + code-fence
    /// syntax highlight + Apple HIG behaviors, but wiki-link
    /// resolution and image embeds are no-ops because we don't have
    /// a wenshu library path to look at). nil-bookStore is the
    /// v0.39 ticket 001-B defensive path (= on early zone activation
    /// when the environment chain hasn't reached EditorPlaceholder
    /// yet via the AnyView wrapper in ZoneContentView.Tab).
    static func make(bookStore: BookStore?) -> MarkdownEditorConfiguration {
        // Build services (= wikiLinks + images use the book paths when
        // available; HighlighterSwiftBridge always wired because it
        // has no path dependency).
        let wikiLinks: any WikiLinkResolver
        let images: any EmbeddedImageProvider
        if let stores = bookStore?.stores {
            // v0.39 ticket 001-B (= wenshu-side WikiLinkResolver + EmbeddedImageProvider
            // implementation = stubbed to no-op for now). The engine's default NoOp
            // providers render wiki-links as plain text + image embeds as the
            // engine's own broken-embed placeholder. The wenshu-specific resolver +
            // provider classes land in v0.39 ticket 001 sub-step B (= a follow-up
            // ticket to be scoped after Package.swift + WIP file restore lands).
            _ = stores  // silence unused-until-sub-step-B warning
            wikiLinks = NoOpWikiLinkResolver()
            images = NoOpEmbeddedImageProvider()
        } else {
            // No library available (= early activation or test env) =
            // engine uses no-op defaults for both protocols (= links
            // appear as plain text + missing images render the engine's
            // own broken-embed placeholder). The editor is still
            // functional for typing, syntax highlight, undo, etc.
            wikiLinks = NoOpWikiLinkResolver()
            images = NoOpEmbeddedImageProvider()
        }
        let services = MarkdownEditorServices(
            wikiLinks: wikiLinks,
            images: images,
            syntaxHighlighter: HighlighterSwiftBridge()
            // latex: omit (= NoOpLatexRenderer default)
            // bus: omit (= .default)
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        return config
    }

    /// Legacy call site (= explicit reference library + active book
    /// URLs). Kept for the unit test that doesn't have a BookStore
    /// fixture (= the test builds a temp dir and passes URLs directly).
    static func make(
        referenceLibraryRoot: URL,
        activeBookRoot: URL?
    ) -> MarkdownEditorConfiguration {
        let services = MarkdownEditorServices(
            wikiLinks: NoOpWikiLinkResolver(),
            images: NoOpEmbeddedImageProvider(),
            syntaxHighlighter: HighlighterSwiftBridge()
            // latex: omit (= NoOpLatexRenderer default)
            // bus: omit (= .default)
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        return config
    }
}
