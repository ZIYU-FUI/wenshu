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

    /// The failure of the last COVER attempt, or nil when the last
    /// attempt worked.
    ///
    /// The card shows the failure on its own, so a cover that could
    /// not be drawn does not look like a card that was never asked
    /// for.
    ///
    /// This is the PICTURE's failure. A clip that failed does not
    /// come here: the picture is fine, and a good picture must not
    /// carry a failure mark (measured 2026-10-23: the orange mark sat
    /// on a card with a good still cover, because the clip's failure
    /// had overwritten the one error field).
    var coverErrorMessage: String? = nil

    /// The failure of the last CLIP attempt, or nil when the clip is
    /// fine.
    ///
    /// It is reported in the MENU, next to the action that makes a
    /// clip, because that is where the user asks for one. The picture
    /// carries no mark for it.
    var coverClipErrorMessage: String? = nil

    /// Whether the PICTURE carries the failure mark.
    ///
    /// A clip that failed does NOT mark the picture: the picture is
    /// there and it is fine, and the menu says that the clip is the
    /// part that gave up. Measured 2026-10-23: the orange mark sat on
    /// a card with a good still cover, because the clip's failure had
    /// overwritten the one error field.
    ///
    /// It is a rule and not an `if` in the view, so it can be tested
    /// without a render.
    var showsFailureMark: Bool { coverErrorMessage != nil }

    /// Whether this card's clip is being made right now.
    var isMakingVideo: Bool = false

    /// Whether cover work is running on this card, so the card can say
    /// so where the cover is.
    ///
    /// The picture and the clip are both work the user waited for: a
    /// clip takes a minute and a picture takes seconds, and in both
    /// cases a card that sits there looking finished is lying.
    var isCoverWorkInFlight: Bool { isGeneratingCover || isMakingVideo }

    @State var isHovered: Bool = false

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

}

/// One tag on a material card, drawn as a quiet metadata pill.
///
/// THE RULE: the label and the fill it sits on must be DIFFERENT tiers,
/// and the fill must be PINNED (= the same tone whatever is behind it),
/// so the chip reads the same on every artwork.
///
/// The old recipe was a translucent WHITE pill (0.16) under a WHITE
/// label (0.92): two washes of the same colour. Over a PALE cover (= every
/// generated cover in the library is a pale Chinese landscape painting)
/// the pill LIGHTENED the ground and resolved to nearly the label's own
/// tone, so the tag read as one flat smudge. Measured on the palest
/// cover in the library (the 清明 card, a cream-and-gold painting), in
/// the light appearance:
///
///     label rgb(246,245,244)   pill rgb(147,135,118)   ground rgb(126,112,92)
///     contrast(label vs pill) = 3.23:1   <- the label cannot separate
///     contrast(pill vs ground) = 1.37:1  <- the pill is barely a surface
///
/// So on a cover the pill is a DARK scrim (= the words sit on a darker
/// ground, = what the App Store card does) and the label is white at
/// full strength, which holds over ANY artwork, pale or dark.
///
/// A card with no picture is paper, and there the words are INK
/// (`DesignTokens.coverInk`), so the pill is a light wash and the label
/// is ink at full strength: a dark label on a light pill, which is the
/// canonical Apple metadata chip.
///
/// The horizontal padding is the caption token (= 2 PT), so the pill hugs
/// its label instead of being twice as wide as the word in it.
struct CardTagChip: View {
    /// The tag text, drawn as it comes.
    let tag: String

    /// Whether the card wears a picture (= the words sit on the artwork)
    /// or is bare paper (= the words sit on the card's own ground).
    let hasCover: Bool

    var body: some View {
        Text(tag)
            .font(.caption2)
            .foregroundStyle(hasCover ? .white : DesignTokens.coverInk)
            .shadow(
                color: hasCover ? .black.opacity(0.55) : .white.opacity(0.6),
                radius: 2,
                x: 0,
                y: 1
            )
            .padding(.horizontal, DesignTokens.spacingCaption)
            .padding(.vertical, DesignTokens.spacingCaption)
            .background(
                Capsule()
                    .fill(
                        hasCover
                            ? Color.black.opacity(0.34)
                            : Color.white.opacity(0.85)
                    )
            )
    }
}

