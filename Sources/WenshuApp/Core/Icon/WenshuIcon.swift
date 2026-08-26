//
//  WenshuIcon.swift · Wenshu
//
//  v0.25 — single source-of-truth icon abstraction layer.
//
//  Source of truth: .scratch/2026-08-26-lucide-icon-migration/spec.md §4
//
//  WenshuIcon enum maps our intent (= e.g. .book, .keyFill, .booksVerticalFill) to a
//  type-safe LucideIcon case from bring-shrubbery/lucide-swift 1.25.0
//  (= 1700+ icons compiled into native Path code).
//
//  Why this layer exists:
//  - one place to change when we want to swap an icon
//  - one place to enforce the visual contract (Lucide icon = hollow outline,
//    inherits `.foregroundStyle(...)` from caller = system color support)
//  - one place to substitute SF Symbols → Lucide cases that differ in spelling
//    (= e.g. Lucide has no `.fill` variants; we map them to round / outline
//    forms and document the substitution in code comments)
//
//  Follow AGENTS.md §11 rule: this is a thin View on top of `Lucide(_:)`
//  from the Lucide package; no parallel SVG strings, no raster assets.
//
//  三层防护 (= owner 2026-08-26 demanded, see issue 001 §"runtime safety nets"):
//  - Layer 1 (avoidance): exhaustive `switch` on every `WenshuIcon` case.
//    Adding a new case without a `lucideIcon` row is a compile error.
//  - Layer 2 (avoidance): when `foregroundStyle` is nil, we explicitly set
//    `.foregroundStyle(Color.primary)` so the icon never renders invisibly
//    against the system background. SwiftUI environment inheritance still
//    wins when the caller provides one in the call chain above us; the
//    explicit `Color.primary` is a hard guarantee at this layer.
//  - Layer 3 (兜底): when a string-typed icon name arrives (dynamic tab /
//    category / item icons that pre-date this abstraction), `image(name:)`
//    uses the failable `Lucide.init?(name:)` first; on nil it falls back to
//    `Lucide(.circleQuestionMark)` so a mistyped string renders a Lucide
//    "missing-icon" glyph instead of crashing or rendering blank.
//

import SwiftUI
import Lucide

/// Icon intent enum for the wenshu app surface.
///
/// Each case maps to exactly one SF Symbol that we use today (= 41 cases for
/// the 41 call sites inventoried in .scratch/2026-08-26-lucide-icon-migration).
/// Keep this enum minimal: only add a case when an actual UI needs it (= ticket
/// 002 burndown migrates the call sites). Adding speculative cases bloats the
/// substitution table with zero payoff and risks drift.
enum WenshuIcon: CaseIterable {

    // MARK: - toolbar / settings / tab strip (= App.swift)

    case key
    case keyFill                // SF has a fill variant; Lucide uses .keyRound for filled aesthetics.
    case checkmark
    case docBadgePlus           // SF `doc.badge.plus` → Lucide `filePlus`.
    case folder
    case squareAndArrowDown     // SF `square.and.arrow.down` → Lucide `squareArrowDown`.
    case squareAndArrowUp       // SF `square.and.arrow.up` (export) → Lucide `share` (= closest functional match).
    case sidebarLeft            // SF `sidebar.left` → Lucide `panelLeft`.
    case eyeFill                // SF `eye.fill` → Lucide `eye` (= Lucide has no `.fill` variant).
    case wrenchAndScrewdriver   // SF `wrench.and.screwdriver` → Lucide `wrench` (= closest).
    case bubbleLeft             // SF `bubble.left` → Lucide `messageCircle`.
    case chartBar
    case archivebox             // SF `archivebox` → Lucide `archive`.
    case cpu
    case chevronUpChevronDown   // SF `chevron.up.chevron.down` → Lucide `chevronsUpDown`.

    // MARK: - chat zone (= ChatView.swift)

    case paperplaneFill         // SF `paperplane.fill` → Lucide `send`.
    case personFill             // SF `person.fill` → Lucide `user`.
    case personCropCircleBadgeQuestionmark  // SF closest case → Lucide `userRoundCog` (= wizard-style assist glyph).
    case brain
    case textBookClosedFill     // SF `text.book.closed.fill` → Lucide `bookText` (= closest).
    case exclamationmarkTriangle  // SF `exclamationmark.triangle` → Lucide `triangleAlert`.

    // MARK: - dynamic zone (= DynamicZoneView.swift + ZoneContentView.swift)

    case rectangleSplit3x1      // SF `rectangle.split.3x1` (kanban tab) → Lucide `rectangleVertical` (= closest column-in-rows glyph).
    case checklist
    case kanban                 // dynamic zone tab visuals (= SF `rectangle.split.3x1` use site, semantic alias).
    case todo                   // SF `checklist` use site, semantic alias.

    // MARK: - library / bookshelf (= LibraryOutlineView.swift + BookOutlineView.swift + LibraryRootView.swift)

    case book
    case booksVertical          // SF `books.vertical` → Lucide `library`.
    case booksVerticalFill      // SF `books.vertical.fill` → Lucide `library` (= Lucide has no `.fill`).
    case magnifyingglass        // SF `magnifyingglass` → Lucide `search`.
    case textBookClosed         // SF `text.book.closed` → Lucide `bookText` (= book with text page glyph).

    // MARK: - sub-agent progress (= SubAgentProgressView.swift)

    case circleDashed           // SF `circle.dashed` → Lucide `circleDashed`.
    case checkmarkCircleFill    // SF `checkmark.circle.fill` → Lucide `circleCheckBig` (= filled check glyph).
    case xmarkCircleFill        // SF `xmark.circle.fill` → Lucide `circleX`.
    case circle                 // SF `circle` → Lucide `circle`.

    // MARK: - zone-icon placeholder (= App.swift:1483 ZoneIcon(struct))

    case sidebarToggle          // SF `sidebar.left` use site, semantic alias for ZoneIcon.
    case settings               // SF `wrench.and.screwdriver` use site, semantic alias.
    case chat                   // SF `bubble.left` use site, semantic alias.
    case analytics              // SF `chart.bar` use site, semantic alias.
    case export                 // SF `square.and.arrow.up` use site, semantic alias.

    // MARK: - layout / window chrome (= App.swift:1157/1163/1169 family)

    case docPlaceholder         // SF `doc.badge.plus` use site, semantic alias for "new document".
    case download               // SF `square.and.arrow.down` use site, semantic alias.
    case showPreview            // SF `eye.fill` use site, semantic alias for the preview toggle.

    // MARK: - 兜底 glyph (= Layer 3, used only when a string lookup fails)

    case missingIcon            // Type-safe handle for the "missing icon" fallback glyph.
}

extension WenshuIcon {

    /// Type-safe mapping to `bring-shrubbery/lucide-swift`'s `LucideIcon` enum.
    /// Set at compile time (= Xcode autocomplete).
    ///
    /// Substitutions documented in code comments (= spec §6). When SF Symbols
    /// and Lucide differ visually (= e.g. fill vs. no fill, split-3x1 vs.
    /// rectangleVertical), record the rationale so future icon-swap stays
    /// cheap. Lucide maintains an online 1:1 map at
    /// `https://lucide.dev/icons/` for visual review.
    ///
    /// **Layer 1 三层防护**: this switch is exhaustive. Adding a new
    /// `WenshuIcon` case without a corresponding `return .xxx` row fails the
    /// build (= compile-time guarantee that no case silently falls through
    /// to a default glyph).
    var lucideIcon: LucideIcon {
        switch self {
        case .key: return .key
        case .keyFill: return .keyRound           // no `.fill` in Lucide; round-key glyph is closest.
        case .checkmark: return .check
        case .docBadgePlus: return .filePlus
        case .folder: return .folder
        case .squareAndArrowDown: return .squareArrowDown
        case .squareAndArrowUp: return .share       // Lucide `share` is closest "export-style" arrow.
        case .sidebarLeft: return .panelLeft
        case .eyeFill: return .eye                  // Lucide `eye` is the only eye variant.
        case .wrenchAndScrewdriver: return .wrench
        case .bubbleLeft: return .messageCircle
        case .chartBar: return .chartBar
        case .archivebox: return .archive
        case .cpu: return .cpu
        case .chevronUpChevronDown: return .chevronsUpDown

        case .paperplaneFill: return .send
        case .personFill: return .user
        case .personCropCircleBadgeQuestionmark: return .userRoundCog   // wizard-style assist glyph.
        case .brain: return .brain
        case .textBookClosedFill: return .bookText
        case .exclamationmarkTriangle: return .triangleAlert

        case .rectangleSplit3x1: return .rectangleVertical   // kanban tab maps to Lucide's column glyph.
        case .checklist: return .listChecks                       // checklist (filled check list) = closest match.
        case .kanban: return .rectangleVertical                   // semantic alias for kanban tab (= same SF icon).
        case .todo: return .listChecks                            // semantic alias for todo tab.

        case .book: return .book
        case .booksVertical: return .library
        case .booksVerticalFill: return .library                 // Lucide has no `.fill`.
        case .magnifyingglass: return .search
        case .textBookClosed: return .bookText

        case .circleDashed: return .circleDashed
        case .checkmarkCircleFill: return .circleCheckBig       // filled check glyph.
        case .xmarkCircleFill: return .circleX
        case .circle: return .circle

        case .sidebarToggle: return .panelLeft                   // semantic alias.
        case .settings: return .wrench                            // semantic alias.
        case .chat: return .messageCircle                         // semantic alias.
        case .analytics: return .chartBar                         // semantic alias.
        case .export: return .share                               // semantic alias.

        case .docPlaceholder: return .filePlus                    // semantic alias.
        case .download: return .squareArrowDown                   // semantic alias.
        case .showPreview: return .eye                            // semantic alias.

        case .missingIcon: return .circleQuestionMark
        }
    }
}

extension WenshuIcon {

    /// Render the icon through `Lucide(_:)` (= SwiftUI native View).
    ///
    /// **Layer 2 三层防护**: when `foregroundStyle` is nil we explicitly set
    /// `.foregroundStyle(Color.primary)` so the icon never renders invisibly
    /// against a missing foreground. Callers who DO want a specific color pass
    /// it through; their chain wins over ours because SwiftUI evaluates
    /// `.foregroundStyle` nearest-to-leaf first.
    ///
    /// Default rendering = hollow outline geometry baked at generation time.
    /// For toggle on/off states (= spec §6 deferred), a future ticket can
    /// layer a `.fill()` modifier here; today we don't.
    ///
    /// `@MainActor` annotation is required because `Lucide.init(_:)` is
    /// main-actor-isolated. SwiftUI view bodies are main-actor, so this
    /// doesn't add friction.
    @MainActor
    @ViewBuilder
    func image(
        size: CGFloat = 16,
        foregroundStyle: Color? = nil
    ) -> some View {
        let icon = Lucide(lucideIcon)
            .frame(width: size, height: size)
        if let foregroundStyle {
            icon.foregroundStyle(foregroundStyle)
        } else {
            // Layer 2: explicit `Color.primary` floor so the icon is never
            // invisible against a foreground-less SwiftUI environment.
            icon.foregroundStyle(Color.primary)
        }
    }

    /// **Layer 3 三层防护** (兜底): string-typed icon names (= the 12 dynamic
    /// call sites: `tab.icon`, `category.icon`, `item.icon`, `iconNames[i]`,
    /// `sourceIcon`) cannot go through the type-safe enum path. They arrive as
    /// `String`; we try the failable `Lucide.init?(name:)` first, and on nil
    /// fall back to the `missingIcon` glyph (= Lucide `circleQuestionMark`).
    ///
    /// Migration order: ticket 002 will replace these 12 call sites with
    /// `WenshuIcon` enum cases; this static helper is the safety net until
    /// that migration lands. Once ticket 002 is done, ticket 003's baseline
    /// unlock can drop the helper if owner approves (= not required, but
    /// reduces surface area).
    ///
    /// `@MainActor` annotation required: Lucide initializers are
    /// main-actor-isolated. SwiftUI view bodies are already main-actor.
    @MainActor
    @ViewBuilder
    static func image(
        name: String,
        size: CGFloat = 16,
        foregroundStyle: Color? = nil
    ) -> some View {
        // Layer 3 fallback: when `Lucide(name)` returns nil, render the Lucide
        // "missing icon" glyph instead of crashing or rendering blank.
        // `circleQuestionMark` ships in every Lucide release.
        let primary = Lucide(name) ?? Lucide(.circleQuestionMark)
        let framed = primary.frame(width: size, height: size)
        if let foregroundStyle {
            framed.foregroundStyle(foregroundStyle)
        } else {
            // Layer 2: same Color.primary floor as the type-safe path.
            framed.foregroundStyle(Color.primary)
        }
    }
}

// Convenience initializers for common sizes. Mirror the most-used call
// sites so ticket 002 can replace `Image(systemName: "x")` with
// `WenshuIcon.image(.x)` (= or `.image(.x, size: 18)`) without thinking.
extension WenshuIcon {
    @MainActor
    @ViewBuilder
    func toolbarIcon(size: CGFloat = 18) -> some View {
        image(size: size)
    }

    @MainActor
    @ViewBuilder
    func smallIcon(size: CGFloat = 13) -> some View {
        image(size: size)
    }
}
