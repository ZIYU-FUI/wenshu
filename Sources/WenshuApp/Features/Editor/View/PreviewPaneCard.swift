//
//  PreviewPaneCard.swift
//
//  Card sub-view + CardSource enum extracted from PreviewPane.swift
//  (= §6.6 god-class split: 518 LOC of the `private struct Card: View`
//  (= 457 LOC) + the `internal enum CardSource` (= 61 LOC) moved out
//  of the main file). The Card view is the single canonical card view
//  for the material preview zone (= Renders both Reference and
//  BookDoc sources via the unified CardSource enum; = the only
//  data shape the card knows; = adding a new source type = one new
//  case + one computed-property branch).
//
//  Why extracted (= §6.6 god-class split): the main `struct PreviewPane`
//  view is 1595 LOC (= 2.7x the 600-LOC cap; = the file was 3.7x
//  the cap with Card + CardSource included). The Card sub-view
//  is self-contained (= takes `source: CardSource` + `onDoubleClick:
//  (CardSource) -> Void` as the only properties; = the file-scope
//  `private` qualifier was relaxed to `internal` so the cross-file
//  reference from PreviewPane's body works).
//

import SwiftUI
import os

/// strategy: since Reference entities are text-only (= .md bodies with no
/// associated image), we use the EntityType icon as a large prominent thumbnail
/// (= e.g. user-round for character, lightbulb for concept). The icon is
/// rendered at 64 PT with a tinted gradient background (= the type's
/// distinguishing color). This gives each card a strong visual identity at a
/// glance (= matches Wubi-ji / Notion "card cover" pattern).
/// Future: when entities get real images (= e.g. character portrait, location
/// map), NukeUI's LazyImage will replace the type icon. The image-pipeline
/// integration is deferred (= needs image storage infrastructure that doesn't
/// exist yet). Single canonical card view for the material preview zone. 'style
/// owned by parent, data composition unified too' —
    /// one component for both Reference (reference library) and BookDoc (bookshelf).
/// Data extraction lives INSIDE the view; no per-source adapter structs.
/// CardSource = the only "data shape" the card knows. Adding a new source type
/// = one new case + one computed-property branch. (see OOB.md #2026-09-08) —
/// 'clicking the Dufu card opens a tab with wrong name' (= clicking the card
/// opened a new tab named 'preview-sample'): the source value is now passed
/// from PreviewPane.Card's onDoubleClick closure to WorkspaceView's
/// openCardInEditor so the EXACT clicked card's .md opens (= not the topmost
/// card = the previous `filtered.first` bug).
/// internal (= module-scoped access for WorkspaceView to use in
/// openCardInEditor(source:)). Was `private` (= the Swift compiler error
/// 'property must be declared fileprivate because its type uses a private type'
/// = since PreviewPane exposes this type in its internal `onDoubleClick`
/// signature, it must be at least as accessible as the type).
/// Note: PreviewPane itself is `internal` (default for Swift struct), so
/// `onDoubleClick` is `internal` (= no explicit access modifier), and
/// CardSource must be `internal` (= same level of access). fileprivate would
/// also work if PreviewPane itself were fileprivate, but PreviewPane is
/// referenced by WorkspaceView (= module-internal access required).
internal enum CardSource {
    case reference(Reference)
    case bookDoc(BookDoc)

    /// SF Symbols 6 icon name (= the only visual differentiator between
    /// sources; everything else is uniform). Replaces the SF Symbols names (no
    /// LUCide-era names remain).
    var iconName: String {
        switch self {
        case .reference(let r): return r.entityType.icon
        case .bookDoc(let d): return BookFolder(rawValue: d.folderName)?.icon ?? "file-text"
        }
    }

    /// Card heading (= filename without extension / entity title).
    var title: String {
        switch self {
        case .reference(let r): return r.title
        case .bookDoc(let d): return d.title
        }
    }

    /// One-line summary ((see OOB.md #2026-08-26) — 'card style = document key-summary excerpt').
    var summary: String {
        switch self {
        case .reference(let r): return r.summary
        case .bookDoc(let d): return d.summary
        }
    }

    /// boss 2026-10-09 (see OOB.md #2026-10-09) set (= the .ws library's
    /// cross-cutting facet; = the user previously had no way to see which 3
    /// tags a card carries without opening the .md body); = reference cards
    /// show `Reference.tags` (= ≤ 3 entries after the [archived-round] cap); = bookDoc
    /// cards show `BookDoc.tags` (= the 2026-10-12 follow-up = parse the file's
    /// first H1 markdown heading and surface it as the book's single tag, = the
    /// book card now visually matches the reference card = no more literal `#
    /// xxx` grey subtitle, = chip pill style, = same row).
    var tags: [String] {
        switch self {
        case .reference(let r):
            // Sort the tag list for stable rendering (= the underlying Set has no defined
            // order; = the card layout should not jitter when SwiftUI re-
            // evaluates the body).
            return r.tags.sorted()
        case .bookDoc(let d):
            // BookDoc.tags is the parsed first H1 (= single element array; = sorted is a
            // no-op for one element but keeps the rendering code shape
            // identical to the .reference case).
            return d.tags.sorted()
        }
    }
}

struct Card: View {
    let source: CardSource
    let onDoubleClick: (CardSource) -> Void
    /// (= boss 2026-10-10 "如 果有不 符合 模版 的内 容， 导入 后， 卡 片 加 橙 色 提 示 角 标"
    /// directive). When `true`, the card shows an orange border (= overriding
    /// the hover tint) + a top-right triangle badge (= Apple HIG
    /// needs-attention pattern; = the user immediately sees which cards
    /// need补齐). The parent PreviewPane computes this flag from the reference's
    /// completion status (= see commit B for the checker; = the default value
    /// `false` keeps the Card backwards- compatible with the existing call
    /// sites until commit C wires the flag in).
    var needsCompletion: Bool = false
    /// the "补齐" right-click menu callback (= only fires when `needsCompletion`
    /// is true; = see commit D for the full chat flow). Defaults to nil (= no
    /// menu item) for call sites that don't wire the chat integration.
    var onComplete: (() -> Void)? = nil
    /// (= boss 2026-10-10 "没有 实现，右键卡 片没有菜单" + "素材栏，不是 tree，是第二 栏，也就是 我们常说的中 左栏.
    /// 里面全 是 MD 卡片" directive). The right-click menu callbacks. The `Card` view
    /// doesn't have access to the `SidebarService` (= the sidebar- owned delete
    /// / rename flow); = the `PreviewPane` parent owns the `SidebarService`
    /// reference (= via `@Environment(BookStore.self)`); = the parent passes
    /// the callbacks down (= same shape as the sidebar's
    /// `SidebarRowCallbacks`).
    let onRename: () -> Void
    let onDelete: () -> Void

    /// The stored cover picture for this card, or nil when the card
    /// has no cover.
    ///
    /// The URL is resolved by the CALLER, not looked up here: the
    /// card view has no store, and the caller knows which card it is
    /// rendering and which kind it is (= a reference card and a book
    /// card are different cards with different covers).
    ///
    /// The key comes from `CardCoverService`, which namespaces the two
    /// card kinds apart, so one card's picture can never land on
    /// another card.
    var coverImageURL: URL? = nil

    /// The stored cover CLIP for this card, or nil when the card has
    /// no moving cover.
    ///
    /// A moving cover is never made automatically: the user looks at
    /// the still cover, decides they like it, and then asks for it to
    /// move.
    var coverVideoURL: URL? = nil

    /// The "generate a cover" callback. Nil when the call site does
    /// not wire it, and the menu item then does not appear.
    var onGenerateCover: (() -> Void)? = nil

    /// The "make it move" callback (= a moving cover). Nil when the
    /// call site does not wire it.
    var onMakeDynamicCover: (() -> Void)? = nil

    /// The "remove the cover" callback. Nil when the call site does
    /// not wire it.
    var onRemoveCover: (() -> Void)? = nil

    /// Whether this card already has a cover.
    ///
    /// The menu labels depend on it: a card with no cover gets
    /// "generate", and a card with one gets "regenerate" and
    /// "remove".
    var hasCover: Bool = false

    /// Whether this card is being generated right now.
    ///
    /// The item is disabled while the work is in flight, so a second
    /// click cannot start a second call.
    var isGeneratingCover: Bool = false

    /// The failure of the last cover attempt, or nil when the last
    /// attempt worked.
    ///
    /// The card shows the failure on its own, so a cover that could
    /// not be drawn does not look like a card that was never asked
    /// for.
    var coverErrorMessage: String? = nil

    /// Whether the failure was the moving cover rather than the
    /// picture.
    ///
    /// The two steps fail for different reasons (= the picture needs
    /// an image service, the clip needs a video service and a still),
    /// so the menu says which one gave up.
    var coverErrorIsVideo: Bool = false

    /// Whether this card's clip is being made right now.
    var isMakingVideo: Bool = false

    /// Whether cover work is running on this card, so the card can say
    /// so where the cover is.
    ///
    /// The picture and the clip are both work the user waited for: a
    /// clip takes a minute and a picture takes seconds, and in both
    /// cases a card that sits there looking finished is lying.
    var isCoverWorkInFlight: Bool { isGeneratingCover || isMakingVideo }

    @State private var isHovered: Bool = false

    /// (see OOB.md #2026-09-03) — 'directory double-click': Apple's
    /// `.onTapGesture(count: 2)` was eaten by LazyVGrid's ScrollView gesture
    /// recognizer. The previous attempt (= a timestamp latch within 300 ms) was
    /// too tight (= macOS default NSDoubleClickInterval is 500 ms, not 300) and
    /// lost subsequent double-clicks after the first one (= the Card view was
    /// re-evaluated by SwiftUI when openCardInEditor mutated appState.openTabs;
    /// = the @State held across re-evaluations, = the *next* single tap was
    /// treated as "first of a new pair" but the user's actual second tap landed
    /// more than 300 ms after the first (= because macOS users tap at ~500 ms
    /// intervals; = the latch was too tight and dropped the second click)).
    /// Switched to a click-count latch (= more robust to user timing variance).
    /// Pair a single tap → count=1. The next tap within `NSDoubleClickInterval`
    /// (= 500 ms via NSApp) → count=2 → fire onDoubleClick. Reset to 0 on the
    /// *third* tap (= a triple-click is not a double-click). This matches macOS
    /// Finder / TextEdit behavior.
    /// NOTE: SwiftUI's `@State` is reset when the view identity changes (= the
    /// ForEach rebuilds the Card when the user switches sidebar scope; = that
    /// is actually the desired behavior here — switching scope = "fresh start"
    /// for the double-click detector; = (see OOB.md) — 'directory,').
    /// (= the boss 2026-10-14 (see OOB.md #2026-10-14) cause): the previous
    /// `@State` was reset on every SwiftUI body re-evaluation (= the `ForEach`
    /// rebuilt the `Card` when `BookDoc.id` changed or the `LazyVGrid` re-laid
    /// out; = the `@State` storage disappeared with the old view identity; =
    /// the next single tap was always treated as "first of a new pair"; =
    /// `clickCount` never reached 2; = the double-click never fired). Fix:
    /// store the click-count state in a `static` keyed by `BookDoc.id` (= the
    /// state survives view re-evaluation because it's at type scope, not at
    /// view-instance scope). The dictionary is bounded by N (= the number of
    /// cards currently visible); = no memory growth.
    @State private var clickCount: Int = 0
    @State private var lastClickTimestamp: TimeInterval = 0
    /// click-count storage (= survives SwiftUI body re-evaluations; = keyed by
    /// `BookDoc.id` so different cards track independently). The previous
    /// `@State` was reset on every body re-evaluation, which broke the
    /// double-click detection.
    nonisolated(unsafe) static var clickCountByID: [UUID: Int] = [:]
    nonisolated(unsafe) static var lastClickByID: [UUID: TimeInterval] = [:]

    /// debug: log every tap on the Card (= helps localize the boss 2026-10-14
    /// (see OOB.md #2026-10-14) effect?).
    private func cardTapped() {
        let cardID: UUID? = {
            switch source {
            case .reference(let r): return r.id
            case .bookDoc(let d): return d.id
            }
        }()
        os_log("[wenshu.preview.card] v7.4 cardTapped cardID=%{public}@ title=%{public}@",
               cardID?.uuidString ?? "nil",
               String(describing: source.title))
    }

    var body: some View {
        // THE CARD IS THE PICTURE.
        //
        // It used to be a banner with the text under it on the panel.
        // The App Store's own card is the other way round: the artwork
        // IS the card, and the words sit on the artwork over a wash,
        // so the picture is what the eye reads first. That is also
        // what macOS does with a media tile (= Photos' grid: the
        // picture, the title on it, and the badges in the corner).
        //
        // So the picture fills the card, the title and the tags sit on
        // it at the bottom left over a scrim, and the play badge sits
        // in the middle (= the App Store's shape, and macOS's own
        // paused-player glyph).
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.accentColor.opacity(DesignTokens.accentTintOpacityHero), Color(nsColor: .quaternaryLabelColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                // Per wenshu-icon-policy v1.5: 64 PT (= empty-state threshold >=38 PT)
                // MUST pin .symbolRenderingMode(.monochrome). SF
                // Symbols 6 on macOS 27 silently falls back to the
                // .fill variant (= the bold-blue book icon. Pinning
                // .monochrome forces the outline glyph at 64 PT.
                // Trade-off: .tint(.opacity 0.85) blue is replaced by
                // default .secondary blue tint via .foregroundStyle.
                Image(systemName: source.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.tint.opacity(0.85))
                // A card with a generated cover shows the picture in
                // the SAME slot, over the gradient and the symbol. The
                // gradient and the symbol stay underneath, so a card
                // whose picture is still loading, or whose file has
                // gone missing, degrades to what it showed before.
                //
                // The slot's size does not change: the cover is a wide
                // banner (100pt tall, 216-316pt wide depending on the
                // pane), and the stored picture is 768x320 (= 2.40:1),
                // which fills it and trims only the sides.
                // A card with a moving cover shows the STILL picture
                // until the pointer arrives, and the clip while it is
                // there. The grid of stills is what the user sees
                // normally; a grid of moving clips would be noise.
                if coverVideoURL != nil {
                    LoopingCoverView(
                        videoURL: coverVideoURL,
                        isHovered: isHovered,
                        stillImageURL: coverImageURL
                    )
                } else {
                    CardCoverView(imageURL: coverImageURL)
                }
                // A cover is being drawn, or a clip is being made: the
                // card says so, in place. The work takes seconds and
                // the user asked for it, so the card must not sit
                // there looking finished.
                if isCoverWorkInFlight {
                    ZStack {
                        Color.black.opacity(0.15)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                // A card that MOVES says so in the corner.
                //
                // The mark is the one the Photos app puts on a picture
                // that moves (= the Live Photo mark), and it is a HINT
                // and not a control: the clip plays when the pointer
                // arrives, and the mark says the card can do that. It
                // is small, because a card whose picture is the card
                // must not have a button on top of it.
                if coverVideoURL != nil {
                    SFIcon(
                        CoverClipControl.symbol,
                        style: .inlineSmall,
                        color: .white,
                        rendering: .monochrome,
                        pointSizeOverride: CoverClipControl.badgeSize
                    )
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    .padding(DesignTokens.spacingStandard)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
                // The last attempt failed: the card carries the mark
                // (= the Apple HIG "needs attention" pattern, in the
                // corner the completion badge does not use).
                if coverErrorMessage != nil {
                    SFIcon(
                        "exclamationmark.triangle.fill",
                        style: .inlineSmall,
                        color: Color.orange
                    )
                    .padding(DesignTokens.spacingCaption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
                }
            // The wash the words sit in.
            //
            // The App Store washes the bottom of its artwork so the
            // white copy can be read over it, and macOS does the same
            // in Photos. It is a gradient and NOT a solid panel: a
            // panel behind the words would be a box pretending to be
            // hierarchy, and the picture is the card.
            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // The words, on the picture.
            //
            // They sit low, in white, with a shadow: a generated cover
            // is a pale painting (= pale paper with a subject on it),
            // and a shadow is what keeps white words readable on a
            // pale ground. The hierarchy is the type itself (= the
            // title, then the tags), not a plate behind it.
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                Text(source.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !source.tags.isEmpty {
                    HStack(spacing: DesignTokens.spacingCaption) {
                        ForEach(source.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .padding(.horizontal, DesignTokens.spacingStandard)
                                .padding(.vertical, DesignTokens.spacingCaption)
                                .background(
                                    Capsule()
                                        .fill(.white.opacity(0.16))
                                )
                        }
                    }
                    .lineLimit(1)
                }
            }
            .padding(DesignTokens.spacingModerate)
            .allowsHitTesting(false)
        }
        // The picture keeps the card's shape: 4:3, which is the shape
        // the picture is generated in, so it fills the tile and
        // nothing is trimmed.
        .aspectRatio(DesignTokens.coverTileRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusWindow,
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // parent component owns style, child component only does function. Hover tint (=
        // matches the pane tab hover pattern).
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusWindow, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            // the border is now conditional on 3 states. `needsCompletion` overrides
            // hover (= the card keeps the orange border whether the user
            // is hovering or not; = the visual signal persists across
            // mouse-off events; = the user can leave the card and the
            // orange tint stays; = matches the boss's "需 要用户补 齐" wording =
            // the card needs attention, not just a hover hint). The orange
            // tint = Apple HIG "needs- attention" color (= the system
            // orange; = not the wenshu accent color; = the user
            // immediately recognizes "this needs action").
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusWindow, style: .continuous)
                .stroke(
                    needsCompletion
                        ? AnyShapeStyle(Color.orange)
                        : (isHovered ? AnyShapeStyle(.tint.opacity(0.4)) : AnyShapeStyle(.tertiary)),
                    lineWidth: needsCompletion ? 1.5 : 0.5
                )
        )
        // the top-right corner badge (= a small orange triangle icon in a white circle; =
        // the Apple HIG "needs attention" pattern; = the badge persists across
        // hover events; = the user can scroll the card into view and
        // immediately see "this one needs 补齐" without hovering). Only shown
        // when `needsCompletion == true`.
        .overlay(alignment: .topTrailing) {
            if needsCompletion {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(Color.orange, lineWidth: 1.2)
                        .frame(width: 18, height: 18)
                    SFIcon(
                        "exclamationmark.triangle.fill",
                        style: .inlineSmall,
                        color: Color.orange
                    )
                }
                .padding(DesignTokens.spacingCaption)
                // The user can right-click the badge to see the "补齐" menu item (= the
                // full menu is on the card body; = the badge itself
                // has no gesture = clicking the badge passes through
                // to the card's .contextMenu).
                .allowsHitTesting(false)
            }
        }
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        // 2026-10-14 v7.5 (= the boss 2026-10-14 (see OOB.md #2026-10-14) root-cause):
        // the previous `.onTapGesture` (= single-tap detected via macOS click-
        // count latch) was NOT firing in the `LazyVGrid` / `ScrollView` nest
        // (= the `LazyVGrid` scroll gesture recognizer was eating the single
        // tap). Fix: use `.simultaneousGesture` with `TapGesture(count: 2)` (=
        // the SwiftUI canonical "fire double-click without conflicting with
        // the enclosing scroll gesture" pattern; = the `simultaneousGesture`
        // modifier tells the gesture system to also recognize this gesture in
        // parallel with the parent `ScrollView`'s pan gesture; = the count=2
        // TapGesture is the macOS HIG double-click surface for SwiftUI; = the
        // previous attempts of `.onTapGesture(count: 2)` were blocked by
        // LazyVGrid's ScrollView gesture recognizer, but `simultaneousGesture`
        // bypasses the conflict by asserting "fire this gesture in parallel
        // with any other gesture on the same view"). The `TapGesture(count:
        // 2)` requires two taps within `NSEvent.doubleClickInterval` (= 500 ms
        // on macOS; = the system default double-click threshold; = the AppKit
        // NSDoubleClick semantic = matches macOS Finder / TextEdit / Safari
        // tab bar double-click). No more click-count latch (= the SwiftUI
        // `count: 2` gesture handles the double-click detection natively; = no
        // manual state needed; = the `static var clickCountByID` hack is no
        // longer needed).
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { _ in
                // "多次双击"清明"，没有打开" (see OOB.md #2026-07-23) (= the double-click does not
                // reach the Card; = the user can see the card
                // highlight, the tap lands, but neither the onTap path
                // nor the onDoubleClick path fires; = the gesture is
                // eaten somewhere upstream). Log every double tap (=
                // even if it ends up no-op) so the boss can grep
                // `Console.app` to see whether the tap reached the
                // Card at all.
                let cardID: String
                switch source {
                case .reference(let r): cardID = r.id.uuidString
                case .bookDoc(let d): cardID = d.id.uuidString
                }
                os_log("[wenshu.preview.card] v0.74 doubleTap firing cardID=%{public}@ title=%{public}@",
                       cardID, source.title)
                onDoubleClick(source)
                os_log("[wenshu.preview.card] v0.74 doubleTap fired cardID=%{public}@",
                       cardID)
            }
        )
        // Apple HIG tooltip (= .help = NSWindow tooltip = separate window per Apple HIG =
        // the user can hover any tab label and get its full name; = matches
        // macOS Finder / TextEdit tab bar tooltip behavior).
        .help(source.title)
        // the right-click context menu on the card (= the boss's "素材区，卡片 ，右键菜单，做 删除、重命名"
        // directive; = the per-card context menu uses the per-card callback
        // pattern; = the macOS 14+ List first-click bug doesn't apply here
        // because the Card is a standalone view inside a LazyVGrid, NOT a List
        // row; = the menu fires on first right-click reliably). Only
        // `.reference` cards get the delete / rename menu (= the `.bookDoc`
        // cards are managed by the chapter flow = a separate ticket; = for now
        // we add the menu only to the reference case = the [archived-round] / 64
        // focused on reference-library cards per the boss's "素材 区" wording).
        // the right-click context menu on the card. The menu shows for BOTH
        // `.reference` AND `.bookDoc` sources (= the boss 2026-10-10 "资料 库 的 卡
        // 片 已 经 实 现 了 右 键 菜 单 ， 但 十 二 地 仙 书 的 卡 片 没 有 生 效 ， 应 该 不 是 同 一 个 卡 片
        // 控 件 ， 你 把 书 的 加 上 就 行 了 " directive; = the [archived-round] conditional was
        // `if case .reference = source` which made the contextMenu empty for
        // bookDoc cards (= the macOS 14+ List first- click bug doesn't apply
        // because the Card is in a LazyVGrid, NOT a List row; = the menu just
        // didn't show because the items array was empty). The contextMenu is
        // always attached (= unconditional); the items list varies by source
        // case.
        .contextMenu {
            switch source {
            case .reference:
                // the "补齐" item shows when `needsCompletion == true` AND `onComplete` is
                // wired. The item is the FIRST entry (= top of menu; =
                // the user's primary intent when seeing an orange card
                // is to补齐 it; = putting it first reduces mouse
                // travel).
                if needsCompletion, let onComplete {
                    Button(String(localized: "card_completion_context_menu_complete")) {
                        onComplete()
                    }
                    Divider()
                }
                // The cover items (= the same in both card kinds).
                if onGenerateCover != nil || onRemoveCover != nil {
                    if hasCover {
                        Button(String(localized: "cover_context_menu_regenerate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    } else {
                        Button(String(localized: "cover_context_menu_generate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    }
                    if let onRemoveCover {
                        Button(String(localized: "cover_context_menu_remove")) {
                            onRemoveCover()
                        }
                    }
                    // "Make it move" shows only when the card HAS a
                    // still cover (= a clip is made FROM the still) and
                    // does not already have a clip.
                    if hasCover, onMakeDynamicCover != nil {
                        Button(String(localized: "cover_context_menu_make_dynamic")) {
                            onMakeDynamicCover?()
                        }
                        .disabled(isMakingVideo)
                    }
                    // The last attempt failed: the menu reports it, so
                    // the user can read why the card has no cover.
                    if let coverErrorMessage {
                        Divider()
                        Button(String(localized: coverErrorIsVideo
                            ? "cover_context_menu_video_failed"
                            : "cover_context_menu_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverErrorMessage)
                    }
                    Divider()
                }
                Button(String(localized: "sidebar_context_menu_rename")) {
                    onRename()
                }
                Divider()
                Button(
                    String(localized: "sidebar_context_menu_delete"),
                    role: .destructive
                ) {
                    onDelete()
                }
            case .bookDoc:
                // same "补齐" item for bookDoc cards (= the boss's "双 向" directive; = both
                // card types support the chat 补齐 flow; = the wiring is
                // identical to reference).
                if needsCompletion, let onComplete {
                    Button(String(localized: "card_completion_context_menu_complete")) {
                        onComplete()
                    }
                    Divider()
                }
                // The cover items (= the same in both card kinds).
                if onGenerateCover != nil || onRemoveCover != nil {
                    if hasCover {
                        Button(String(localized: "cover_context_menu_regenerate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    } else {
                        Button(String(localized: "cover_context_menu_generate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    }
                    if let onRemoveCover {
                        Button(String(localized: "cover_context_menu_remove")) {
                            onRemoveCover()
                        }
                    }
                    // "Make it move" shows only when the card HAS a
                    // still cover (= a clip is made FROM the still) and
                    // does not already have a clip.
                    if hasCover, onMakeDynamicCover != nil {
                        Button(String(localized: "cover_context_menu_make_dynamic")) {
                            onMakeDynamicCover?()
                        }
                        .disabled(isMakingVideo)
                    }
                    // The last attempt failed: the menu reports it, so
                    // the user can read why the card has no cover.
                    if let coverErrorMessage {
                        Divider()
                        Button(String(localized: coverErrorIsVideo
                            ? "cover_context_menu_video_failed"
                            : "cover_context_menu_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverErrorMessage)
                    }
                    Divider()
                }
                Button(String(localized: "sidebar_context_menu_rename")) {
                    onRename()
                }
                Divider()
                Button(
                    String(localized: "sidebar_context_menu_delete"),
                    role: .destructive
                ) {
                    onDelete()
                }
            }
        }
    }
}

