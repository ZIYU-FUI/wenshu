// Sources/WenshuApp/Views/Workspace/EditorPaperCanvas.swift
//
// Extracted from `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`
// (= the legacy monolith). Same module, no new import.
//
// Consumer: `Sources/WenshuApp/Views/Workspace/EditorView.swift`
// (= calls `EditorPaperCanvas { ... }` to wrap the markdown
// editor surface in a horizontal + vertical ScrollView so the
// engine's NSTextView can render at any width the parent column
// allocates).
//
// 2026-10-14 SMC default rendering (= boss OOB 2026-10-13
// "去白纸" = drop the visible A4 paper under the editor body):
// the previous wrapper rendered an A4 sheet (= `paperWidth = 595
// PT` + `paperMargin = 72 PT` + `minHeight: 842 PT` + white
// `Color.white` background + forced light `colorScheme` +
// `Color.black.opacity(0.35)` shadow + vertical `20 PT` padding
// + `defaultScrollAnchor(.center)`). All of that was the visible
// "A4 paper floating on the dark editor column" the user
// reported as superfluous (= boss visual diff: "白纸").
//
// The SMC (= Standard Markdown Component) default rendering is:
// the engine's `NativeTextViewWrapper` sits directly in the
// editor column (= the editor column's own dark background
// shows behind the NSTextView = no paper rectangle; = the
// NSTextView's textContainerInset provides the inner margin; =
// the engine manages its own scroll; = the visible surface is
// "text on a column", not "text on an A4 sheet inside a
// column").
//
// What this wrapper KEEPS (= the only thing it still does):
// 1. The `ScrollView([.horizontal, .vertical])` boundary around
//    the engine's NSTextView. This is the macOS 27 layout-loop
//    crash surface documented in `wenshu-app-build-pipeline`:
//    `EditorPaperCanvas` was the body's outermost `ScrollView`
//    that gave the engine's `NSScrollView` a bounded parent slot;
//    removing the wrapper (= dropping the only outer
//    `ScrollView` around the `NSViewRepresentable`) re-introduces
//    `_postWindowNeedsUpdateConstraints` SIGABRT at narrow window
//    widths (= `NavigationSplitView` 4-column
//    `SplitViewChildController` repeatedly re-queries the engine's
//    hosting view for size without a bounded parent slot = layout
//    pass infinite loop). The `ScrollView` keeps the engine's
//    NSTextView slot bounded = the layout coordinator has a
//    stable size reference at every parent resize (= the
//    narrow-window crash does not recur).
// 2. `.frame(maxWidth: .infinity, alignment: .center)` so the
//    NSTextView fills the available column width (= the engine's
//    NSTextView reads the parent width for `textContainer` layout
//    pass; = with a bounded parent width the text wraps to fit
//    the column instead of running off the edge or being
//    horizontally clipped by an over-narrow 595 PT sheet).
// 3. `.scrollContentBackground(.hidden)` so the SwiftUI
//    `ScrollView` does not paint its own background tint over
//    the engine's text = visually identical to "no wrapper".
//
// What this wrapper DROPS (= the A4-paper visual chrome):
// 1. `paperWidth = 595 PT` (A4 width) + the `.frame(width:
//    paperWidth)` constraint. Drop the 595 PT cap so the
//    NSTextView reads the column's actual width (= the column is
//    wider than 595 PT on a 1480 PT window = the editor body
//    gets a comfortable typing column; = the column is narrower
//    than 595 PT on a dragged window = the engine's own
//    `NSScrollView` provides horizontal scroll).
// 2. `paperMargin = 72 PT` (1 inch) + the outer `.padding(72)`.
//    Drop the 72 PT margin so the NSTextView's own
//    `textContainerInset` (= the engine's default = a few PT
//    per side) supplies the inner margin. Removing the wrapper's
//    margin does NOT remove the engine's inner margin = the
//    typing surface still has a small left/right padding
//    (= the canonical editor feel).
// 3. `.frame(minHeight: 842)` (= A4 height) + `.padding(.vertical,
//    20)` (paper float spacing). Drop the minimum height = the
//    body ZStack sizes to the engine's NSTextView intrinsic
//    content height (= short documents have a short body =
//    `EditorStatusBarView` floats flush to the bottom via the
//    `Spacer(minLength: 0)` in `EditorView`; = long documents
//    grow to fit the text and the body's NSScrollView scrolls
//    naturally = no more "842 PT A4 sheet with a big transparent
//    gap below it" visual bug).
// 4. `.background(Color.white)`. Drop the explicit white
//    background = the editor column's own background (= system
//    `textBackgroundColor` in light mode, `windowBackgroundColor`
//    in dark mode) shows through. The visible surface becomes
//    "the editor column with the document text rendered on it",
//    which is the Apple HIG canonical editor surface (= Pages /
//    Numbers / Xcode source editor = no paper rectangle around
//    the text; = the text sits on the column's own
//    background).
// 5. `.environment(\.colorScheme, .light)`. Drop the forced
//    light scheme = the engine's NSTextView now follows the
//    system appearance (= light mode = white text background;
//    dark mode = dark text background; = matches the rest of
//    the wenshu column chrome).
// 6. `.shadow(color: .black.opacity(0.35), radius: ..., y: ...)`.
//    Drop the paper-card drop shadow = the editor body no
//    longer "floats above the column" (= it IS the column;
//    = the column's own chrome provides any shadow if needed).
// 7. `.defaultScrollAnchor(.center)`. Drop the center scroll
//    anchor = the engine's NSScrollView already remembers the
//    user's scroll position per-document (= `EditorScrollMemory`
//    + `restoreScrollOffset`; = no need for an outer ScrollView
//    scroll-anchor policy; = the engine handles its own
//    scroll memory).
//
// Net visual: editor body = `Color.textBackgroundColor` (= matches
// the editor column's own background in light + dark mode) +
// the engine's `NativeTextViewWrapper` renders the markdown
// text directly on that surface + the engine's NSTextView
// owns the horizontal + vertical scroll. No A4 paper rectangle,
// no forced light mode, no paper card shadow, no 842 PT
// minimum height, no 595 PT A4 width, no 1 inch outer margin.
//
// Net functional: identical to the pre-fix state (= the user
// types into the same NSTextView, edits the same draft, sees the
// same text formatting, opens the same wiki links) with the
// only difference being the visible chrome around the
// NSTextView (= no A4 sheet).

import SwiftUI

/// Wraps the editor's `NativeTextViewWrapper` (= the
/// `swift-markdown-engine` NSTextView) in a horizontal +
/// vertical `ScrollView` so the engine's hosting view has a
/// bounded parent slot at every parent resize (= the
/// macOS 27 NSV 4-column narrow-window crash surface; = the
/// SwiftUI `SplitViewChildController` does not re-query the
/// engine's `NSScrollView` for size on every parent resize
/// when the outer `ScrollView` is present).
///
/// The wrapper no longer renders an A4 paper rectangle (= the
/// previous "white sheet" visual was removed 2026-10-14; = see
/// the file-header comment for the full drop list). The
/// `ScrollView` is a layout-only safety net (= `scrollContentBackground
/// (.hidden)` so it paints no chrome = visually invisible).
///
/// Width policy: the engine's `NativeTextViewWrapper` requires
/// a bounded width to render (= `NSTextContainer` calls
/// `textContainer.size` on every layout pass; = with an
/// unbounded parent width the `NSTextView`'s intrinsic width
/// goes to `.infinity` and the text layout pass fails = blank
/// surface). The wrapper therefore applies `.frame(maxWidth:
/// .infinity, alignment: .center)` (= the engine reads the
/// SwiftUI `ScrollView`'s bounded column width and grows to fill
/// it; = the engine's `NSTextContainer` is bounded by the
/// column's actual width). The `minHeight: 240` ensures the
/// engine's `NSScrollView` has enough vertical space to draw at
/// least one line on a freshly-opened tab (= without the floor,
/// a single-character document collapses the NSTextView to
/// ~16 PT and the user sees a 1-line body with the format
/// toolbar + status bar + tab strip + format-toolbar padding
/// dominating the visible zone).
struct EditorPaperCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        // Layout-only ScrollView wrapper. No paper rectangle
        // (= no `Color.white` background), no paper shadow
        // (= no `.shadow(...)`), no fixed A4 width (= no
        // `.frame(width: 595)`), no paper margin (= no
        // `.padding(72)`), no minimum paper height (= no
        // `.frame(minHeight: 842)`), no forced light mode
        // (= no `.environment(\.colorScheme, .light)`), no
        // default-center scroll anchor (= the engine's
        // `NSScrollView` owns scroll memory via
        // `EditorScrollMemory.restoreScrollOffset`).
        //
        // The wrapper supplies:
        // (1) a `ScrollView([.horizontal, .vertical])` boundary
        //     so the engine's hosting view has a bounded parent
        //     slot at every NSV 4-column narrow-window resize;
        // (2) `.frame(maxWidth: .infinity, alignment: .center)`
        //     so the engine reads the column's actual width
        //     (= the engine's `NSTextView` fills the available
        //     width; = the engine's `textContainer` layout pass
        //     resolves cleanly because the parent slot is bounded
        //     by this frame; = the engine's own `NSScrollView`
        //     handles horizontal + vertical scroll internally);
        // (3) `.frame(minHeight: 240)` so the NSTextView never
        //     collapses to a 0-height body on a freshly-opened
        //     tab (= the engine's `heightTracksTextView = false`
        //     policy means the NSTextView reads its frame height
        //     from the parent; = a `minHeight` floor ensures the
        //     layout pass has a non-zero height to work with);
        // (4) `.scrollContentBackground(.hidden)` so the
        //     `ScrollView` does not paint its own background
        //     (= no visible chrome).
        // Layout wrapper. No paper rectangle (= no Color.white
        // background), no paper shadow (= no .shadow(...)),
        // no fixed A4 width (= no .frame(width: 595)), no paper
        // margin (= no .padding(72)), no minimum paper height
        // (= no .frame(minHeight: 842)), no forced light mode
        // (= no .environment(\.colorScheme, .light)), no
        // default-center scroll anchor.
        //
        // The wrapper supplies:
        // (1) a `ScrollView([.horizontal, .vertical])` boundary
        //     so the engine's hosting view has a bounded parent
        //     slot at every NSV 4-column narrow-window resize
        //     (= the macOS 27 layout-loop crash surface
        //     documented in `wenshu-app-build-pipeline`).
        // (2) `.frame(maxWidth: .infinity, alignment: .center)`
        //     so the engine reads the column's actual width
        //     (= the engine's `NSTextView` fills the available
        //     width; = the engine's `textContainer` layout pass
        //     resolves cleanly because the parent slot is bounded
        //     by this frame; = the engine's own `NSScrollView`
        //     handles horizontal + vertical scroll internally);
        // (3) `.frame(minHeight: 240)` so the NSTextView never
        //     collapses to a 0-height body on a freshly-opened
        //     tab (= the engine's `heightTracksTextView = false`
        //     policy means the NSTextView reads its frame height
        //     from the parent; = a `minHeight` floor ensures the
        //     layout pass has a non-zero height to work with);
        // (4) `.padding(.horizontal, 10)` so the rendered text
        //     has a 10 PT left/right breathing space (= matches
        //     the engine's textContainerInset via
        //     WenshuEditorServicesFactory; = boss 2026-10-14 (see OOB.md #2026-10-14)
        //     边距").
        // (5) `.scrollContentBackground(.hidden)` so the
        //     `ScrollView` does not paint its own background
        //     (= no visible chrome).
        // Minimal layout wrapper around the engine's
        // `NativeTextViewWrapper` (= the
        // `swift-markdown-engine` NSTextView). The wrapper
        // does ONE thing: force the engine's hosting view
        // to claim the full width and height of the parent
        // column (= the `NativeTextViewWrapper` is a
        // SwiftUI `NSViewRepresentable`; = without the
        // `maxWidth: .infinity` + `maxHeight: .infinity`
        // frame here, the engine's hosting view receives
        // a zero-width layout proposal from its parent
        // and collapses to a 30 PT sliver (= the
        // 2026-10-14 diagnostic confirmed the sliver
        // before this fix).
        //
        // No outer SwiftUI `ScrollView` (= dropped
        // 2026-10-14 = the boss standing preference is
        // "层级太多" = the editor body has too many
        // wrapping layers; = drop every layer that does
        // not directly serve the user-visible editor
        // body). The engine's own `NSScrollView` (=
        // internal to `NativeTextViewWrapper` = line 219
        // of `NativeTextViewWrapper.swift`) handles the
        // actual horizontal + vertical scroll of the
        // rendered markdown text. The macOS 27 NSV
        // 4-column narrow-window crash surface is a
        // separate ticket (= the crash happens in
        // `SplitViewChildController.hostingView(_:did
        // UpdateMinSize:maxSize:)` regardless of the
        // editor body's wrapping; = the 30 PT-shrink
        // bug fix and the narrow-window crash are
        // orthogonal issues).
        //
        // The `.frame(maxWidth: .infinity, maxHeight:
        // .infinity)` here works because `content` is
        // a SwiftUI `View` (= the `Group` from
        // `EditorView` is also a SwiftUI View = it
        // accepts a `maxWidth: .infinity` proposal
        // and lays its children out at that width; =
        // the Group's children = the conditional
        // `WenshuMarkdownEditor` / `EditorEditContent`
        // = both inherit the parent's `.infinity`
        // width via SwiftUI's ViewBuilder rules; = the
        // earlier 30 PT-shrink bug was actually
        // caused by the previous `.frame(width:
        // .infinity, alignment: .center)` (= the
        // `.center` alignment collapsed the Group's
        // intrinsic width to its content's intrinsic
        // width = 30 PT); = switching to
        // `.frame(maxWidth: .infinity, maxHeight:
        // .infinity)` (= no alignment center) lets
        // the Group expand to the parent column's
        // full width and propagate that width to its
        // `WenshuMarkdownEditor` child).
        // 2026-10-14 v4: drop the SwiftUI
        // `ScrollView` wrapper again. The v3
        // re-introduction (= wrap the
        // `NativeTextViewWrapper` in a SwiftUI
        // `ScrollView` to insulate the engine
        // from the parent NSV / NSSplitView
        // resize cascade) re-introduced the
        // "text not rendered" regression. The
        // root cause: when a SwiftUI
        // `NSViewRepresentable` is hosted inside a
        // SwiftUI `ScrollView` wrapper (= a
        // SwiftUI `ScrollView` whose content is
        // a single NSViewRepresentable), the
        // engine's internal
        // `scrollView.contentView.bounds.width` is
        // 0 PT at the engine's first
        // `makeNSView(context:)` call (= the
        // SwiftUI `ScrollView` has not yet
        // committed its content size to its
        // embedded NSScrollView; = the engine's
        // `centerReadingColumn(forClipWidth: 0)`
        // sets the engine's container frame to
        // 0 PT wide; = the engine's NSTextContainer
        // is 0 PT wide; = the engine renders no
        // text; = even when the SwiftUI
        // `ScrollView` later commits a non-zero
        // content size, the engine's container
        // is still 0 PT because the engine's
        // `scrollView.contentView` bounds
        // notification fires once (= with
        // bounds.width = 0) and the engine does
        // not re-receive a non-zero bounds change
        // from the SwiftUI `ScrollView` host).
        //
        // The v3 scroll-jank diagnosis was
        // correct (= on every NSV / NSSplitView
        // parent resize, the engine re-asserts
        // `centerReadingColumn` with the new clip
        // width, = the engine re-centers the
        // `NSTextContainer`, = the engine re-lays
        // out the document on every parent
        // resize; = the user perceives this as
        // scroll jank). The v3 fix attempted to
        // insulate the engine from parent resize
        // by wrapping it in a SwiftUI
        // `ScrollView` (= the SwiftUI
        // `ScrollView` is a stable outer slot).
        // The trade-off (= no resize-triggered
        // relayout) was correct in principle, but
        // the v3 implementation broke the
        // `centerReadingColumn(forClipWidth: 0)`
        // initial call.
        //
        // The correct v4 design (= this file):
        // the `EditorPaperCanvas` body is back
        // to a minimal `content.frame(maxWidth:
        // .infinity, maxHeight: .infinity)`
        // wrapper (= no SwiftUI `ScrollView`).
        // The scroll-jank is now addressed
        // upstream in the
        // `WenshuEditorServicesFactory` (= see
        // `WenshuEditorServicesFactory.swift`'s
        // `readingWidth` and `textInsets`
        // comments) by setting
        // `readingWidth = nil` (= the engine
        // takes the `vpSize.width` path) and
        // `textInsets = TextInsets(horizontal: 10,
        // vertical: 0)` (= the engine's
        // `NSTextContainer.size` follows the
        // NSTextView frame = the engine does NOT
        // invoke `centerReadingColumn` because
        // `readingWidth` is `nil`). The
        // `centerReadingColumn` re-layout
        // cascade is therefore not triggered
        // on parent resize (= the engine
        // follows the parent NSTextView frame,
        // = the textContainer.width follows the
        // NSTextView frame's intrinsic width).
        //
        // Trade-off vs the v1 design (= the
        // original `EditorPaperCanvas` with the
        // A4 paper): v4 keeps the engine's
        // `NSTextContainer` glued to the
        // NSTextView's frame (= the text fills
        // the column; = the visible 10 PT
        // left/right padding is supplied by the
        // engine's `textInsets`; = the engine
        // does NOT center a 600-PT reading column
        // inside a 1100+ PT column, = the
        // previous "上左右都有内边距" symptom is
        // gone because the 1100+ PT column has
        // 10 PT text padding on each side of the
        // text glyphs, = the text fills the
        // column with only the 10 PT padding
        // visible).
        //
        // Scroll-jank trade-off accepted: with
        // `readingWidth = nil` and no
        // `centerReadingColumn`, the engine's
        // `widthTracksTextView = true` policy
        // re-lays out the document on every
        // NSTextView frame change. The user's
        // reported scroll jank is the lesser of
        // two evils (= the alternative is a
        // completely blank editor surface; =
        // the user can re-test the scroll-jank
        // after this v4 fix; = if the v4
        // scroll-jank is unacceptable, a
        // future ticket can introduce an
        // `EditorChatNSController` host-side
        // debounce that delays the engine's
        // `frameDidChangeNotification` observer
        // to coalesce multiple NSV resize events
        // into a single engine relayout pass).
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
