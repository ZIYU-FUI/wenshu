// Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift
//
// Factory + bus builder for the markdown editor.
import Foundation
import MarkdownEngine
import MarkdownEngineCodeBlocks
import MarkdownEngineLatex

enum WenshuEditorServicesFactory {
    /// Build a MarkdownEditorConfiguration. The bus defaults to
    /// .default; callers pass MarkdownEditorBus.buildWenshu() to
    /// activate format / find / replace routing. Preferences
    /// default to `.live` (= the AppStorage-backed snapshot; =
    /// the factory always sees the user's current settings).
    static func make(
        bookStore: BookStore?,
        bus: MarkdownEditorBus = .default,
        preferences: EditorPreferences = .live
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
            latex: SwiftMathBridge(),
            bus: bus
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        // T-11: explicitly bind the engine's default theme so the
        // host (= wenshu) records its intent in source (= future
        // tickets that want to retint the editor surface a single
        // place to land = the `MarkdownEditorTheme` declaration
        // below). The engine's `MarkdownEditorTheme.default` ships
        // with light + dark color pairs that match Pages / Numbers
        // inspector colors (= bodyText = NSColor.labelColor mirror,
        // mutedText = NSColor.tertiaryLabelColor mirror, code =
        // NSColor.textBackgroundColor mirror).
        config.theme = MarkdownEditorTheme.default
        // T-12: forward the host's `EditorPreferences` snapshot to
        // the configuration. Each field binds the matching engine
        // field (= readingWidth / heightBehavior / rawSourceMode /
        // spellChecking triple / listEditing toggles).
        // 2026-10-14: pin `readingWidth` to a definite
        // value (= 600 PT) so the engine's
        // `NativeTextViewWrapper` initializes its
        // `NSTextContainer.size` to a known width.
        // The previous `nil` (= no readingWidth) was
        // the root cause of the "text rendered as
        // one-character-per-line" (= 30 PT vertical
        // text) bug: per
        // `.build/checkouts/swift-markdown-engine/Sources/MarkdownEngine/TextView/NativeTextViewWrapper.swift:317`,
        // when `readingWidth == nil` the engine
        // resolves `initialWidth = vpSize.width`
        // (= `scrollView.contentView.bounds.size`).
        // The SwiftUI `NSViewRepresentable` in a
        // `NSHostingController` (= the editor pane's
        // hosting view inside `EditorChatNSController`)
        // does NOT guarantee a non-zero width at
        // `makeNSView(context:)` time (= the parent
        // AppKit `NSSplitViewItem` may not have
        // allocated a non-zero width yet when the
        // SwiftUI view is first mounted; = the
        // engine's `vpSize` is therefore 0 PT; = the
        // `NSTextContainer.size = 0 PT`; = the
        // `NSTextView` renders each character on
        // its own line because the text layout pass
        // wraps at every character). Pin
        // `readingWidth` to 600 PT (= the Apple HIG
        // canonical reading-column width; = Pages
        // defaults to 600 PT; = matches the wenshu
        // inspector column-width token of 600 PT) =
        // the engine's `NSTextContainer.size` is
        // always 600 PT, = the markdown text wraps
        // cleanly across the editor column.
        //
        // The previous comment in
        // `WenshuMarkdownEditor.swift` line 506 (=
        // `var config = configuration` + `config.
        // readingWidth = preferences.readingWidth`)
        // was the source of the bug. Set
        // `config.readingWidth = 600` here (= below
        // the host's `preferences.readingWidth` set)
        // to override the host's value if it is
        // `nil`. The `WenshuEditorServicesFactory`
        // is the single source of truth for the
        // engine configuration; = the
        // `preferences.readingWidth` field stays
        // for any future wenshu reading-column
        // preference, but the factory always pins
        // it to 600 PT for now (= no UI surface
        // for the user to change it; = the field
        // is reserved for future tickets).
        //
        // 2026-10-14 v2: the previous 600-PT
        // reading-width combined with the engine's
        // `centerReadingColumn(forClipWidth:)` (=
        // lines 342 + 356 of
        // `NativeTextViewWrapper.swift`) centers
        // the 600-PT `NSTextContainer` inside the
        // NSScrollView viewport (= the user's
        // column = 1100+ PT), = the visible text
        // has ~250 PT of left padding + ~250 PT of
        // right padding (= the user-reported "上左
        // 右都留了内边距" symptom). The boss 2026-10-14 (see OOB.md #2026-10-14)
        // `readingWidth = nil` (= the engine
        // resolves `initialWidth = vpSize.width`
        // from the parent NSScrollView's
        // contentView bounds) AND wrap the engine
        // in a SwiftUI `ScrollView` (= the
        // `EditorPaperCanvas` body, = below) so the
        // SwiftUI layout pass gives the engine's
        // NSScrollView a known viewport width at
        // `makeNSView(context:)` time. The 30 PT
        // sliver bug from the earlier attempts
        // came from wrapping the engine in a
        // SwiftUI `ScrollView` WITHOUT a parent
        // `.frame(maxWidth: .infinity)` (= the
        // SwiftUI ScrollView's content view had
        // zero bounds at first layout); the new
        // `EditorPaperCanvas` body (= lines
        // 220-248 of `EditorPaperCanvas.swift`)
        // does apply `.frame(maxWidth: .infinity,
        // maxHeight: .infinity)` to the content
        // = the engine's hosting view receives a
        // known width at init.
        // 2026-10-14 v3: revert the
        // `config.readingWidth = 600` change. The
        // previous 600-PT reading-width + the
        // engine's `centerReadingColumn` behavior
        // (= centers the 600-PT NSTextContainer
        // inside the parent NSScrollView viewport)
        // is the cause of the user-reported
        // "上左右都留了内边距" (= 250 PT of left +
        // right padding around the 600-PT text
        // column when the parent column is
        // ~1100 PT).
        //
        // Restore `readingWidth = nil` so the
        // engine does NOT invoke
        // `centerReadingColumn` (= the engine's
        // `textContainer.width = vpSize.width` =
        // the parent NSScrollView viewport width;
        // = the text fills the entire column
        // without any horizontal centering). The
        // previous zero-width sliver bug (=
        // character-per-line vertical text) was
        // caused by SwiftUI giving the
        // `NSViewRepresentable` a zero-width
        // initial frame in `makeNSView(context:)`
        // (= the parent `NSSplitViewItem` in
        // `EditorChatNSController` had not yet
        // allocated a non-zero width). The fix
        // (= `EditorPaperCanvas.swift` body
        // applies `.frame(maxWidth: .infinity,
        // maxHeight: .infinity)` to the content)
        // gives the engine a known non-zero
        // width at init, so `vpSize.width` is
        // no longer 0.
        //
        // The visible 10 PT left + right text
        // padding is supplied by
        // `TextInsets.horizontal = 10` below
        // (= the engine's `NSTextView.textContainerInset
        // = 10 PT on each side; = the rendered
        // glyphs start 10 PT from the NSTextView's
        // left edge; = the right edge of the last
        // glyph ends 10 PT before the NSTextView's
        // right edge).
        //
        // TODO future ticket: when wenshu
        // ships a user-toggleable reading-column
        // preference (= 480 / 600 / 720 PT
        // options), expose `readingWidth` to
        // the user. The engine will then invoke
        // `centerReadingColumn` (= the canonical
        // Pages behavior with a reading-column
        // preference).
        config.readingWidth = nil
        config.heightBehavior = preferences.heightBehavior
        config.rawSourceMode = preferences.rawSourceMode
        config.spellChecking = SpellCheckingPolicy(
            continuousSpellChecking: preferences.continuousSpellChecking,
            grammarChecking: preferences.grammarChecking,
            automaticSpellingCorrection: preferences.automaticSpellingCorrection
        )
        config.lists = ListStyle(
            helpersEnabled: preferences.listHelpersEnabled,
            autoClosePairsEnabled: preferences.autoClosePairsEnabled
        )
        // 2026-10-14: `textInsets` controls the engine's
        // `NSTextView.textContainerInset` (= the inner left/right
        // + top/bottom padding between the NSTextView's frame
        // edge and the rendered text glyphs). The engine's
        // `TextInsets.default` is `TextInsets(horizontal: 0,
        // vertical: 0)` (= the text bleeds to the NSTextView frame
        // edge with zero inner padding = visually wrong on a
        // wenshu editor column). Set 10 PT horizontal so the
        // rendered text has a narrow but visible left/right
        // breathing space (= matches the canonical wenshu
        // editor chrome rhythm = sidebar buttons / format
        // toolbar / tab strip all use 8-12 PT insets per
        // `DesignTokens.spacingStandard / spacingModerate`; = 10 PT
        // is the round-number middle of that range; = the text
        // body is visibly inside the editor column without an
        // A4-paper margin). Set 0 PT vertical so the document
        // body flows continuously from the format toolbar
        // (= the toolbar is the top margin; = the status bar is
        // the bottom margin; = no internal vertical text inset
        // would add a redundant line of padding between the
        // toolbar and the first line of text).
        //
        // 2026-10-14 v4: with `readingWidth = nil` (= the v4
        // design restored in this file), the engine's
        // `NSTextContainer` follows the parent NSScrollView
        // viewport (= `widthTracksTextView = true`; = the
        // container grows to the full column width; = no
        // `centerReadingColumn` is invoked because
        // `readingWidth` is `nil`). The 10 PT horizontal
        // `textInsets` now correctly acts as the visible left
        // + right padding of the rendered text (= 10 PT on
        // each side; = the boss 2026-10-14 (see OOB.md #2026-10-14)
        // visible on each side; = no 600-PT reading column
        // centering).
        config.textInsets = TextInsets(horizontal: 10, vertical: 0)
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
            syntaxHighlighter: HighlighterSwiftBridge(),
            latex: SwiftMathBridge()
        )
        var config = MarkdownEditorConfiguration.default
        config.services = services
        // T-11: same explicit-theme binding (= see above).
        config.theme = MarkdownEditorTheme.default
        return config
    }
}

// MARK: - MarkdownEditorBus construction
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
