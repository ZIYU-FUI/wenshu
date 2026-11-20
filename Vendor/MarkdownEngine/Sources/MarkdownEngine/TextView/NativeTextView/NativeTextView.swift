//
//  NativeTextView.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 18.02.26.
//
//  AppKit `NSTextView` subclass used by the markdown editor. Stored state
//  lives here; behavior is split across `NativeTextView+<Feature>.swift`
//  files in this folder (frame & overscroll, caret workarounds, click remap,
//  paste handling, drag-select boost, task checkbox, spelling policy).
//
//  Bottom-overscroll math lives in `BottomOverscrollPolicy.swift`.
//  Pasteboard image inspection lives in `PasteboardImageReader.swift`.
//

import AppKit
import UniformTypeIdentifiers

final class NativeTextView: NSTextView {
    // MARK: Frame & overscroll state
    var baseContentHeight: CGFloat = 0
    var activeBottomOverscroll: CGFloat = 0
    var isApplyingManagedFrameSize = false
    /// Set on switch/resize to force full-layout height measurement until the cascade settles.
    var pendingFullLayoutMeasure = false
    /// Coalesces wide-table overlay updates to once per runloop (resize fires many per frame).
    var pendingWideTableOverlayUpdate = false
    /// Coalesces table restyles to the latest width once per run-loop turn.
    var pendingTableWidthChangeUpdate = false
    var suppressAutoRevealOnce: Bool = false
    // Set by clickedOnLink during a mouseDown: did the delegate fire (so
    // mouseDown can re-dispatch a click AppKit dropped), and did it navigate
    // (so the pre-click caret is restored — a link click isn't caret placement).
    var linkClickDidFire = false
    var linkClickDidNavigate = false

    // MARK: Configuration
    var configuration: MarkdownEditorConfiguration = .default {
        didSet {
            overscrollPercent = configuration.overscroll.percent
            maxOverscrollPoints = configuration.overscroll.maxPoints
            minOverscrollPoints = configuration.overscroll.minPoints
        }
    }
    var overscrollPercent: CGFloat = MarkdownEditorConfiguration.default.overscroll.percent
    var maxOverscrollPoints: CGFloat = MarkdownEditorConfiguration.default.overscroll.maxPoints
    var minOverscrollPoints: CGFloat = MarkdownEditorConfiguration.default.overscroll.minPoints

    // MARK: Editor wiring
    var onPasteImage: ((NSPasteboard) -> String?)?
    weak var layoutBridge: LayoutBridge?
    var baseFont: NSFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    // MARK: Caret-workaround state
    var caretIndicatorObservation: NSKeyValueObservation?
    weak var observedCaretIndicator: NSView?
    var isApplyingCaretShift: Bool = false

    // MARK: Drag-select state
    var dragStartMouseScreenLoc: NSPoint?

    // MARK: Placeholder state
    /// Click-through ghost-text label shown while the document is empty;
    /// managed by `NativeTextView+Placeholder.swift`.
    weak var placeholderView: PlaceholderLabelView?

    // MARK: Cursor exclusion
    /// Embedder-supplied predicate that suppresses the I-beam cursor in edit mode.
    /// Called on every mouse-move with the event location in window coordinates.
    /// Return `true` to show the arrow cursor instead of the edit-mode I-beam.
    var isCursorExcluded: ((CGPoint) -> Bool)?

    // MARK: Visible-layout settlement state
    /// One proof that layout is settled: the Y (text-view coordinates) the
    /// document is known settled TO, and the storage generation that proof was
    /// made at. Every fragment above `settledToY` has its final height, so
    /// nothing at or below it can shift when the prefix is later re-laid out —
    /// but only over the storage that was walked. A mutation makes the heights
    /// above the viewport unknown again. `nil` = unknown, and the next settle
    /// has to walk from the document head (see
    /// `ensureVisibleLayout(settlingFromDocumentHead:)`).
    struct SettledLayoutFrontier: Equatable {
        var settledToY: CGFloat
        /// The coordinator's `parseGeneration` this band was proven against.
        var provenAtGeneration: UInt64
    }

    /// The stored proof. Ask `settledLayoutFrontierY` whether it still holds
    /// rather than reading the band out of this directly.
    var settledLayoutFrontier: SettledLayoutFrontier?

    /// The settled band, readable only while it was proven against the CURRENT
    /// storage generation; writing it stamps the generation of the write. So a
    /// mutation invalidates the claim structurally, instead of relying on every
    /// mutation path remembering to drop it.
    ///
    /// That stamp, not the shape of the restyle paths, is what keeps this
    /// honest. The claim this file used to rest on — "every mutation path in
    /// the engine ends in a restyle" — is FALSE for a reachable mode: raw
    /// source mode is a Settings toggle (`SettingView` feeds
    /// `WenshuEditorServicesFactory`), and there a keystroke returns from
    /// `textDidChange` at its "skip the restyle" exit, `restyleTextView` returns
    /// at its own raw-mode guard, the wrapper's rebuild early-returns at the
    /// same-document exit of `updateNSView`, and a Writing-Tools proofread
    /// returns from `textDidChange` even earlier — so none of those paths
    /// re-proves the prefix it just moved, and a tick would have trusted a claim
    /// that no longer described the document. `shouldChangeTextIn` bumps
    /// `parseGeneration` for EVERY proposed edit before those early exits, and
    /// `setMarkedText` bumps it for the composition that never posts
    /// `textDidChange` (its own override above), so the stamp moves on all of
    /// them.
    /// Events that move text without touching storage — a re-wrap, a changed
    /// inset, an image that just arrived — cannot be caught that way and still
    /// drop it explicitly; `textDidChange` also drops it before its early
    /// returns, for the mutations that reach storage without a generation bump.
    var settledLayoutFrontierY: CGFloat? {
        get {
            guard let frontier = settledLayoutFrontier,
                  frontier.provenAtGeneration == currentLayoutGenerationStamp else { return nil }
            return frontier.settledToY
        }
        set {
            settledLayoutFrontier = newValue.map {
                SettledLayoutFrontier(settledToY: $0, provenAtGeneration: currentLayoutGenerationStamp)
            }
        }
    }

    /// The engine's storage-mutation counter: `parseGeneration`, which every
    /// path that mutates the document is required to bump (its own declaration
    /// states that contract). A view with no coordinator has no engine mutation
    /// path to compare against either, so the stamp reads 0 and stays
    /// comparable instead of distrusting a claim nothing can invalidate.
    var currentLayoutGenerationStamp: UInt64 {
        (delegate as? NativeTextViewCoordinator)?.parseGeneration ?? 0
    }

    /// What the LAST visible-layout settle did: where its walk started, and how
    /// many layout fragments it visited. This is the seam the settlement suite
    /// reads to prove the scroll tick's scope — a tick that re-walks the document
    /// fails on a COUNT, which is the only way to hold that claim without a
    /// wall-clock budget. Not Debug-only on purpose: the suite must compile in any
    /// configuration, and recording two fields costs nothing beside the walk.
    var lastVisibleLayoutSettle: (fromDocumentHead: Bool, visitedFragments: Int)?

    // MARK: Wide-table overlay state
    /// Live NSScrollView per wide table; keyed by source-ID hash.
    var wideTableOverlays: [Int: WideTableOverlay] = [:]
    /// Persisted horizontal scroll offset per wide table; survives restyles.
    var tableHorizontalScrollOffsets: [Int: CGFloat] = [:]

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Forward appearance changes to the embedder's highlighter via its registered notification.
        if let name = configuration.services.syntaxHighlighter.appearanceDidChangeNotification {
            NotificationCenter.default.post(name: name, object: self)
        }
    }

    // setMarkedText skips textDidChange, so restyle the marked paragraph to apply markdown attrs.
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        guard hasMarkedText(),
              let coord = delegate as? NativeTextViewCoordinator else { return }
        let marked = markedRange()
        guard marked.location != NSNotFound, marked.length > 0 else { return }
        // The composition mutated the storage without textDidChange, and
        // shouldChangeTextIn's own parse re-cached the PRE-edit string at the
        // current generation — bump so the restyle below reparses instead of
        // serving that stale document (same-length composition updates).
        coord.parseGeneration &+= 1
        // Census bookkeeping never saw this mutation → next census full-scans.
        coord.backtickCensusNeedsRescan = true
        let nsText = self.string as NSString
        let paragraph = nsText.paragraphRange(for: marked)
        coord.restyleParagraphs([paragraph], in: self)
    }

    deinit { caretIndicatorObservation?.invalidate() }
}
