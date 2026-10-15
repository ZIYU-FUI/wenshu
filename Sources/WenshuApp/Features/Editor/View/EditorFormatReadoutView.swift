// Sources/WenshuApp/Views/Inspector/EditorFormatReadoutView.swift
//
// Sub-tool 1 of 5 (= T-05) inside the `documentTools` page:
// selection-state readout. Reads the engine's `MarkdownEditorBus`
// selection events (= `selectionBoldDidChange` /
// `selectionItalicDidChange` / `selectionHighlightDidChange`) and
// renders a 3-icon row (= B / I / H) with the current selection's
// toggle state. The engine posts these events on every selection
// change with `userInfo["isBold"] as? Bool` etc.
//
// Design rationale (= Apple HIG inspector icon row):
// - 3 icons side-by-side at 28 PT (= matches the toolbar's button
//   frame). Active state = filled / accent-tinted. Inactive = hollow
//   / secondary. Apple HIG inspector-icon idiom = Pages / Numbers
//   inspector header (= the B/I/U line in the Format panel).
// - Listener ownership = `NotificationCenter.default` observer
//   registered on view appear and removed on view disappear
//   (= NotificationCenter holds weak refs to its observers; the
//   observer closure here captures self by `weak` to break any
//   retain cycle through the View).
// - Pure render surface (= no @State for the toggle states directly;
//   = the @State holds the latest values, updated by the observer
//   callback).
//
// T-05 sibling structure (= per-sub-tool page body): each sub-tool
// body is a small `View` (= 50-100 LOC) that reads bus events + the
// editor's draft state. The picker source contract (= which one is
// visible) lives in `EditorDocumentToolsView` (= the parent shell).
import SwiftUI
import MarkdownEngine

/// Selection-state readout (= B / I / H toggle row). Reads the
/// engine's `MarkdownEditorBus` selection events (= the engine posts
/// on every selection change with `userInfo["isBold"] as? Bool` etc.).
/// `bus` is the same instance the engine's coordinator observes
/// internally (= a fresh bus per `MarkdownEditorBus.buildWenshu()` =
/// the canonical factory exposed via `WenshuEditorServicesFactory`).
struct EditorFormatReadoutView: View {
    let bus: MarkdownEditorBus

    /// Live selection toggle states (= updated by the bus observer
    /// closure below). nil = no observation yet (= the user has not
    /// typed anything / no selection has moved; = the engine hasn't
    /// fired its first selection event).
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isHighlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingStandard) {
            // Section header (= Apple HIG inspector sub-section
            // pattern = Pages / Numbers / Xcode inspector panel =
            // secondary-tint title above the row).
            Text(String(localized: "inspector.documentTools.formatReadout.title"))
                .font(.callout)
                .foregroundStyle(.secondary)

            // 3-icon row (= B / I / H). Each is a static icon in
            // this sub-tool (= the readout only displays the engine's
            // last-known toggle state; = applying a new toggle is the
            // central format toolbar's job — T-02).
            HStack(spacing: DesignTokens.spacingStandard) {
                FormatReadoutIcon(
                    icon: "bold",
                    label: String(localized: "inspector.documentTools.formatReadout.bold.a11y"),
                    active: isBold
                )
                FormatReadoutIcon(
                    icon: "italic",
                    label: String(localized: "inspector.documentTools.formatReadout.italic.a11y"),
                    active: isItalic
                )
                FormatReadoutIcon(
                    icon: "highlighter",
                    label: String(localized: "inspector.documentTools.formatReadout.highlight.a11y"),
                    active: isHighlight
                )
            }

            // Selection hint (= mirror Pages / Numbers inspector =
            // one line of body text explaining what the row means =
            // a11y label for the section). Reads from the same
            // localization catalog as the picker source.
            Text(String(localized: "inspector.documentTools.formatReadout.help"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            // Register selection observers (= the engine posts on
            // every selection change). NotificationCenter holds weak
            // refs to observers (= the closure body captures self via
            // weak to avoid a retain cycle through the View's state
            // container).
            registerObservers()
        }
        .onDisappear {
            // Tear down (= NotificationCenter doesn't auto-remove
            // closures; = we hold an explicit token list to remove
            // each observer when this sub-tool is no longer visible
            // (= prevent a stale observer from firing into a
            // recycled sub-tool later).
            removeObservers()
        }
    }

    // MARK: - Observer lifecycle (= onAppear registers, onDisappear
    // removes; = the observer list is owner-scoped to the View's
    // lifecycle).

    /// NotificationCenter observer tokens (= held by the View as
    /// @State below; = stored in a small box so `onDisappear` can
    /// call `NotificationCenter.default.removeObserver(_:)` on each
    /// one). The use of a private @State keeps the storage attached
    /// to the View (= survives body re-renders, = the observer
    // list survives body invalidations until the View itself
    // goes away).
    @State private var observerTokens: [NSObjectProtocol] = []

    /// One-line observer registration (= 3 observers for the 3
    /// selection-state events). Each observer parses the userInfo
    /// Bool and writes the corresponding @State.
    private func registerObservers() {
        observerTokens = [
            NotificationCenter.default.addObserver(
                forName: bus.selectionBoldDidChange,
                object: nil,
                queue: .main
            ) { notification in
                // RATIONALE: the NotificationCenter handler signature is @Sendable
                // (the second closure param of addObserver(forName:object:queue:using:)).
                // Swift 6 isolation inference treats it as nonisolated, so writing
                // self.isBold (= @MainActor-isolated View @State) triggers
                // "main actor-isolated property mutated from Sendable closure".
                // queue: .main guarantees the callback runs on the main thread; the
                // canonical Swift 6 wrap is MainActor.assumeIsolated (macOS 14+)
                // which gives the compiler the @MainActor contract without an
                // extra dispatch hop (= no Task spawn cost per notification).
                if let isBold = notification.userInfo?["isBold"] as? Bool {
                    MainActor.assumeIsolated {
                        self.isBold = isBold
                    }
                }
            },
            NotificationCenter.default.addObserver(
                forName: bus.selectionItalicDidChange,
                object: nil,
                queue: .main
            ) { notification in
                if let isItalic = notification.userInfo?["isItalic"] as? Bool {
                    MainActor.assumeIsolated {
                        self.isItalic = isItalic
                    }
                }
            },
            NotificationCenter.default.addObserver(
                forName: bus.selectionHighlightDidChange,
                object: nil,
                queue: .main
            ) { notification in
                if let isHighlight = notification.userInfo?["isHighlight"] as? Bool {
                    MainActor.assumeIsolated {
                        self.isHighlight = isHighlight
                    }
                }
            }
        ]
    }

    /// Observer tear-down (= called on disappear).
    private func removeObservers() {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens = []
    }
}

/// One icon in the readout row (= B / I / H). Static (= no business
/// logic; = the parent passes `active: Bool` from the bus observer).
/// When active = filled / accent-tinted; = otherwise secondary-tint.
/// Apple HIG inspector icon idiom.
private struct FormatReadoutIcon: View {
    let icon: String
    let label: String
    let active: Bool

    var body: some View {
        // The `SFIcon` style + color drives the visible state.
        // `.paneTab` (= 18 PT) matches the inspector button-row
        // rhythm; = `.inlineSmall` would be too small for an
        // inspector icon row (= Pages / Numbers inspector uses
        // ~16-18 PT icons; = `.paneTab` lands inside that range
        // and matches `DesignTokens.tabCloseFrameSize` for the
        // tap target).
        SFIcon(icon, style: .paneTab, color: active ? .accent : .secondary)
            .frame(width: DesignTokens.tabCloseFrameSize, height: DesignTokens.tabCloseFrameSize)
            .accessibilityLabel(label)
            .accessibilityValue(active
                ? String(localized: "inspector.documentTools.formatReadout.active")
                : String(localized: "inspector.documentTools.formatReadout.inactive"))
    }
}