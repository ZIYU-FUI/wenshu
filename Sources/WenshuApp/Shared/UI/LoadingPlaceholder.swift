//
//  LoadingPlaceholder.swift
//  wenshu
//
//  The ONE loading placeholder (= the project's skeleton mechanism).
//
//  WHY THIS FILE EXISTS
//
//  Every zone in the workspace that waits for data draws its own
//  loading picture: four naked `ProgressView()` calls (= the inspector's
//  status page, = = the inspector's todo page, = = the material column's
//  whole-library scope and the sidebar tree) and one board with no loading
//  state at all. = = Five zones = = five shapes, = = five spinners, = =
//  and a column that reads differently from its neighbour.
//
//  ⇒ ⇒ ⇒ AND THE OTHER SPINNERS ARE INLINE ACTIVITIES: = = the tree
//  holds a badge, = = a diagnostics row, = = an import row, = =
//  a card, = = a batch's progress row and the migration panel, = =
//  = = and each of them carries a label or sits inside a control,
//  = = so the contract's last rule keeps them on Apple's own
//  indicator (= = the app's launch shell is the seventh, = = and
//  = = it is "the app is starting", = = not "content arriving").
//
//  ⇒ ⇒ ⇒ So the loading picture is ONE component, here, and every zone
//  asks it for the shape its own content will take (= = and for its own
//  row anatomy, = = because the inspector's card and the sidebar's tree
//  row are NOT the same shape).
//
//  ⇒ ⇒ ⇒ AND THE SHAPE IS WHAT THE PLACEHOLDER RESERVES (= = the
//  content arrives into the space the placeholder already holds, = = so
//  nothing around the zone moves).
//
//  ⇒ ⇒ ⇒ AND THE COMPONENT IS THE TWIN OF `EmptyStateView` (= the
//  project's one "there is nothing here" surface): a zone is either
//  empty, or loading, or showing content = = and the two empty-ish
//  states have one door each.
//
//  APPLE'S OWN ANSWER (read from Apple's source, not paraphrased)
//
//  - HIG "loading": "Show something as soon as possible." / "consider
//    showing placeholder text, graphics, or animations as content loads,
//    replacing these elements as content becomes available" / "Let
//    people do other things in your app or game while they wait for
//    content to load."
//  - HIG "progress-indicators": an indeterminate progress indicator
//    (= an activity indicator) is for work of UNKNOWN duration. A
//    skeleton that RESERVES the arriving content's shape is the
//    placeholder the loading article asks for (= and it replaces the
//    content in place = = the article's "replacing these elements as
//    content becomes available").
//  - The SDK ships `redacted(reason:)` (= SwiftUICore.swiftinterface:
//    7927) with `RedactionReasons.placeholder` (= :7909) and
//    `.placeholder` as a shape style (= SwiftUI.swiftinterface:5589).
//    ⇒ Those are Apple's primitives for REDACTING content that is
//    already on screen (= the "this is stale, it is still loading"
//    case). A zone whose content has NOT ARRIVED has nothing to
//    redact = = so the reserved shape is drawn from tokens here.
//
//  ⇒ ⇒ ⇒ WHAT IS OURS AND WHAT IS APPLE'S (AGENTS.md 1.17: when Apple
//  ships no answer, that IS the finding = = the number is the app's
//  own decision and is recorded as ours):
//
//  - Apple's: the placeholder idea, the shape-reserving contract, the
//    "replace in place" behaviour, and the primitives (= the phase
//    animator at SwiftUICore.swiftinterface:18478).
//  - Ours: the exact block geometry (= the token-driven sizes below)
//    and the phase timing. Apple ships NO skeleton API (= grepping
//    `skeleton` and `shimmer` across the SwiftUI, SwiftUICore and
//    AppKit swiftinterfaces returns zero hits) = = so there is no
//    Apple number to copy and no Apple shimmer to imitate.
//
//  DESIGN CONTRACT (= what each caller MUST honor)
//
//  - The shape MUST match the content that replaces it (= the card
//    grid draws `.cards` with the zone's OWN grid = = the row lists
//    draw `.rows` = = a pane whose content has no shape yet draws
//    `.block`). A mismatch = = the content arrives and the zone
//    reflows = = which is the jump the component exists to prevent.
//  - The placeholder is a PLACEHOLDER, not a message: it carries no
//    text and no glyph (= a zone that has nothing to say while it
//    waits says nothing = = and a skeleton with a label is a spinner
//    with extra steps).
//  - A zone whose content is STALE but on screen redacts it with
//    Apple's `.redacted(reason: .placeholder)` instead of drawing a
//    second picture beside it.
//  - A zone whose duration is UNKNOWN and whose shape is NOT yet
//    decided keeps Apple's indeterminate progress indicator (= the
//    progress-indicators article's own case = = the app's launch
//    shell, which is not "content arriving" but "the app is starting").
//
//  Usage:
//
//  ```swift
//  if !model.isLoaded {
//      LoadingPlaceholder(.rows(count: 3, unit: .inspectorCard))
//          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//  } else if model.tasks.isEmpty {
//      emptyState
//  } else {
//      taskList
//  }
//  ```
//

import SwiftUI

/// The project's one loading placeholder.
///
/// A zone asks for the shape its content will take, and the placeholder
/// holds that shape until the content arrives.
///
/// = = ⇒ ⇒ ⇒ AND WHAT IT PROMISES, = = EXACTLY: = = the content lands
/// = = ⇒ ⇒ ⇒ where the placeholder held it (= = so nothing around the
/// = = ⇒ ⇒ ⇒ zone moves, = = and the zone reads as WORKING rather than
/// = = ⇒ ⇒ ⇒ as empty). = = ⇒ ⇒ ⇒ It does NOT promise the content's
/// = = ⇒ ⇒ ⇒ exact height (= = the count is not knowable before the
/// = = ⇒ ⇒ ⇒ load, = = so the reserved extent is the unit REPEATED, = =
/// = = ⇒ ⇒ ⇒ not the content's exact size), = = and the scroll extent
/// = = ⇒ ⇒ ⇒ therefore grows when the content lands.
struct LoadingPlaceholder: View {
    /// The shape of the content that is arriving.
    enum Shape {
        /// A vertical list of row units (= the inspector's card rows,
        /// the sidebar's tree rows).
        ///
        /// - Parameters:
        ///   - count: how many rows the placeholder shows.
        ///   - unit: the zone's OWN row anatomy (= the leading column
        ///     and the text bars), = = so the reserved row is the height
        ///     the real row takes (= = the inspector's card and the
        ///     sidebar's tree row are NOT the same shape, = = and one
        ///     hard-wired row would match neither).
        case rows(count: Int, unit: Row)

        /// A grid of card units (= the material column's card grid).
        ///
        /// - Parameters:
        ///   - columns: the zone's OWN grid (= the cards arrive in it,
        ///     so the placeholder reserves it).
        ///   - count: how many cards the placeholder shows.
        case cards(columns: [GridItem], count: Int)

        /// A vertical list of GROUP units (= the board's status groups:
        /// = each group is a header and the cards under it).
        ///
        /// - Parameter count: how many groups the placeholder shows (= =
        ///   the board's own group count, = = so the reserved column is
        ///   the column the groups will fill).
        case groups(count: Int)

        /// One filled area (= a pane whose content has no shape yet).
        case block

        /// Every shape the placeholder can be asked for.
        ///
        /// = = The census of the shapes lives HERE (= next to the
        /// = = shapes themselves) = = and the suite reads the enum
        /// = = beside it, = = so a shape cannot be added without the
        /// = = census changing with it.
        @MainActor static let shapeCases: [Shape] = [
            .rows(count: 1, unit: .inspectorCard),
            .cards(columns: [GridItem(.flexible())], count: 1),
            .groups(count: 1),
            .block,
        ]
    }

    /// One reserved row (= the zone's OWN row anatomy).
    ///
    /// = = The zone names its anatomy here (= the leading column's size
    /// = = and the text bars), = = and the two anatomies the app's rows
    /// = = have live here as named constants (= = so the numbers stay in
    /// = = one place, = = and a call site reads which row it reserves).
    struct Row {
        /// The leading column's width (= the icon's or the marker's).
        var leadingWidth: CGFloat

        /// The leading column's height.
        var leadingHeight: CGFloat

        /// The row's text bars (= its words and their detail).
        var bars: [Bar]

        /// One text bar (= one line of words).
        struct Bar {
            /// The bar's share of the row's width.
            var widthRatio: CGFloat

            /// The bar's height.
            var height: CGFloat
        }

        /// The inspector card's row (= a marker column of the card's own
        /// width + the card's text rows).
        @MainActor static let inspectorCard = Row(
            leadingWidth: DesignTokens.inspectionMarkerColumnWidth,
            leadingHeight: DesignTokens.inspectionMarkerColumnWidth,
            bars: [
                Bar(widthRatio: 0.6, height: DesignTokens.skeletonTextBarHeightLarge),
                Bar(widthRatio: 0.4, height: DesignTokens.skeletonTextBarHeight),
            ]
        )

        /// The sidebar tree's row (= an icon of the row's own width + the
        /// row's title).
        @MainActor static let sidebarRow = Row(
            leadingWidth: DesignTokens.listRowLeadingIconColumnWidth,
            leadingHeight: DesignTokens.listRowLeadingIconColumnWidth,
            bars: [
                Bar(widthRatio: 0.5, height: DesignTokens.skeletonTextBarHeightLarge),
            ]
        )
    }

    /// The shape being reserved.
    let shape: Shape

    /// The placeholder for a shape.
    ///
    /// = = The init takes the shape alone (= the memberwise init would
    /// = = ask for the label) = = so a call site reads
    /// = = `LoadingPlaceholder(.rows(count: 3, unit: .inspectorCard))`.
    init(_ shape: Shape) {
        self.shape = shape
    }

    /// The reserved blocks, breathing between two opacities.
    ///
    /// = = AND THE BLOCKS BREATHE: the phase animator (= Apple's own
    /// = = primitive = = SwiftUICore.swiftinterface:18478) walks the
    /// = = opacity between two values on a repeating cycle = = so the
    /// = = zone reads as WORKING rather than as stuck. = = The motion
    /// = = is a phase change and not a sweep (= Apple ships no
    /// = = shimmer = = there is no Apple gradient to copy) = = and the
    /// = = cycle is the app's own (= the loading article's "showing
    /// = = placeholder text, graphics, or animations as content
    /// = = loads").
    var body: some View {
        blocks
            .phaseAnimator([PlaceholderPhase.dim, .lit]) { content, phase in
                content.opacity(phase.opacity)
            }
    }

    /// The phase (= the two opacities the blocks breathe between).
    private enum PlaceholderPhase {
        case dim
        case lit

        /// The phase's opacity.
        var opacity: Double {
            switch self {
            case .dim: return 0.45
            case .lit: return 1.0
            }
        }
    }

    /// The reserved blocks, laid out the way the zone lays out its
    /// content.
    @ViewBuilder
    private var blocks: some View {
        switch shape {
        case let .rows(count, unit):
            VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
                ForEach(0 ..< count, id: \.self) { _ in
                    rowBlock(unit)
                }
            }
        case let .cards(columns, count):
            LazyVGrid(columns: columns, spacing: DesignTokens.spacingLoose) {
                ForEach(0 ..< count, id: \.self) { _ in
                    cardBlock
                }
            }
        case let .groups(count):
            VStack(alignment: .leading, spacing: DesignTokens.spacingModerate) {
                ForEach(0 ..< count, id: \.self) { _ in
                    groupBlock
                }
            }
        case .block:
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusCard,
                style: .continuous
            )
            .fill(DesignTokens.textPlaceholder)
        }
    }

    /// One row: the zone's leading column and its text bars.
    ///
    /// = = The unit carries the zone's OWN anatomy (= the leading
    /// = = column's size and the text bars' ratios and heights), = = so
    /// = = the reserved row is the height the real row takes (= = the
    /// = = inspector's card and the sidebar's tree row are different
    /// = = shapes, = = and one hard-wired row would match neither).
    private func rowBlock(_ unit: Row) -> some View {
        HStack(spacing: DesignTokens.spacingStandard) {
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip,
                style: .continuous
            )
            .fill(DesignTokens.textPlaceholder)
            .frame(width: unit.leadingWidth, height: unit.leadingHeight)
            VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
                ForEach(Array(unit.bars.enumerated()), id: \.offset) { _, textBar in
                    bar(widthRatio: textBar.widthRatio, height: textBar.height)
                }
            }
        }
    }

    /// One group: the group's header and one card under it.
    ///
    /// = = The board draws a header per status and the cards under it,
    /// = = so the reserved group is the header + the card (= = and the
    /// = = card is the board's own card shape = = so the group the
    /// = = placeholder reserves is the group the real one takes).
    private var groupBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            bar(widthRatio: 0.25, height: DesignTokens.skeletonTextBarHeight)
            cardBlock
        }
    }

    /// One card: the cover tile (= the card's picture area) and two
    /// text bars (= the card's title and its summary).
    ///
    /// = = The tile keeps the card's own ratio (= the material card
    /// = = paints its cover at that ratio) = = so the grid the
    /// = = placeholder reserves has the grid the cards will fill.
    private var cardBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusWindow,
                style: .continuous
            )
            .fill(DesignTokens.textPlaceholder)
            .aspectRatio(DesignTokens.coverTileRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            bar(widthRatio: 0.8, height: DesignTokens.skeletonTextBarHeightLarge)
            bar(widthRatio: 0.5, height: DesignTokens.skeletonTextBarHeight)
        }
    }

    /// One text bar (= one line of words), sized as a share of the
    /// width its column gives it.
    ///
    /// = = The ratio is a SHARE (= the bar is a fraction of the width
    /// = = it is given) = = because the width is the caller's (= the
    /// = = zone's own column width) = = and a bar of a fixed width
    /// = = would not match a column of a different width.
    ///
    /// = = AND THE WIDTH IS MEASURED AGAINST THE COLUMN = = so the bar
    /// = = is the bar that matches the content it stands in for = = and
    /// = = the reader (= the geometry proxy) does not draw anything = =
    /// = = and the bar's own height is pinned = = so the reader cannot
    /// = = claim the column's height.
    private func bar(widthRatio: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusSmallChip,
                style: .continuous
            )
            .fill(DesignTokens.textPlaceholder)
            .frame(width: proxy.size.width * widthRatio, height: height)
        }
        .frame(height: height)
    }
}
