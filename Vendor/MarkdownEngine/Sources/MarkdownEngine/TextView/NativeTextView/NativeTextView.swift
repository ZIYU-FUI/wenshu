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
    /// Y (text-view coordinates) up to which TextKit's layout is KNOWN settled —
    /// every fragment above it has its final height, so nothing at or below it can
    /// shift when the prefix is later re-laid out. `nil` = unknown, and the next
    /// settle has to walk from the document head (see
    /// `ensureVisibleLayout(settlingFromDocumentHead:)`).
    ///
    /// The scroll tick is the only caller allowed to trust this: a tick with no
    /// edit between it and the previous settle cannot have moved anything above the
    /// viewport, so re-walking the settled prefix buys nothing. Every mutation
    /// path in the engine ends in a restyle, and the restyle settles from the head
    /// (it re-claims the unknown state first), which is what keeps this honest.
    var settledLayoutFrontierY: CGFloat?

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
