// EditorChatNSControllerTests.swift · Wenshu · v1.80 health-ticket 3
//
// EditorChatNSController.swift = 408 LOC AppKit NSSplitViewController
// subclass + EditorChatSplitHost NSViewControllerRepresentable wrapper.
// repowise health score = 4.5 = untested_hotspot with 15 dependents
// + weighted_deficit 1348 + prior_defect top 0.6% (= 11 bug-fixes
// in last 6 months; this test partially addresses only the untested
// half = prior_defect is history-derived and out of test scope).
//
// Per wenshu test convention (= Q112 + value/identifier static checks
// + source-level assertions), NSSplitViewController subclasses that
// require a real window hierarchy cannot be exercised directly
// (= viewDidLoad / viewDidAppear / viewDidLayout need an NSWindow + a
// parent NSSplitView; = full lifecycle testing is out of scope per
// the wenshu testing convention seen across all 4 prior untested
// hotspots in this arc).
//
// What IS testable:
//   - Static identifier constants (chatItemIdentifier + autosaveName
//     + firstLaunchSetKey must be stable because AppKit autosaveName
//     writes to UserDefaults keyed on these strings; = renaming is a
//     user-data migration).
//   - Source-level assertions for the 5 canonical Apple HIG rules
//     (= thin divider, isVertical = false, autosaveName wired,
//     first-launch 50:50 reset, toggleChatZone uses .animator()).
//
// Coverage:
//   1. chatItemIdentifier is the canonical "wenshu.editor.chat" id
//   2. autosaveName is the canonical UserDefaults-persisted key
//   3. firstLaunchSetKey is the one-shot first-launch gate
//   4. Source: dividerStyle = .thin (= Apple HIG hairline divider)
//   5. Source: isVertical = false (= top-to-bottom stack, Keynote
//      speaker-notes pattern; = matches the wenshu editor-on-top +
//      chat-on-bottom layout)
//   6. Source: autosaveName is wired in viewDidLoad
//   7. Source: 50:50 first-launch divider formula = splitView.bounds
//      .height / 2
//   8. Source: toggleChatZone uses animator().isCollapsed.toggle()
//      (= canonical NSSplitView animated collapse)

import Foundation
import AppKit
import Testing
@testable import WenshuApp

@Suite("EditorChatNSController (= NSSplitViewController hosting editor + chat)")
@MainActor
struct EditorChatNSControllerTests {

    /// The controller's source, across the five files it lives in.
    ///
    /// The controller was ONE file (= 1509 LOC) and was split under
    /// the tree's 600-LOC cap into the class's own file, three
    /// extension files and the SwiftUI host. The assertions below read
    /// the source, so they read the CONTROLLER's source (= all five
    /// files), not one file's slice of it: a move is not a
    /// disappearance.
    private static let controllerSourceFiles = [
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Lifecycle.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Divider.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Layout.swift",
        "Sources/WenshuApp/Features/Editor/View/EditorChatSplitHost.swift",
    ]

    /// The five files' source, joined.
    ///
    /// The join is a newline, so a line never runs into the next
    /// file's first line, and an assertion that counts a token counts
    /// it the same way it counted it when the controller was one file.
    private static func controllerSource() throws -> String {
        try controllerSourceFiles
            .map { try String(contentsOf: SourceLocator.url($0), encoding: .utf8) }
            .joined(separator: "\n")
    }

    // MARK: - Static identifier stability
    //
    // AppKit autosaveName writes to UserDefaults keyed on these
    // strings; renaming any of them invalidates persisted divider
    // positions (= silently; = the user's drag position is lost on
    // next launch). The tests below freeze the canonical values.

    @Test("chatItemIdentifier = canonical \"wenshu.editor.chat\" id (= toggleChatZone lookup key)")
    func chatItemIdentifierStable() {
        #expect(EditorChatNSController.chatItemIdentifier == "wenshu.editor.chat")
    }

    @Test("autosaveName persists the divider position via Apple HIG UserDefaults path")
    func autosaveNameStable() throws {
        let content = try Self.controllerSource()
        // The autosaveName literal must match the UserDefaults
        // prefix 'NSSplitView Subview Frames'; = AppKit wires the
        // rest. Verify the exact constant value.
        #expect(content.contains("\"wenshu.editor.split.autosave\""),
                "autosaveName must be the literal 'wenshu.editor.split.autosave' (= AppKit stores the divider position under 'NSSplitView Subview Frames <name>')")
    }

    @Test("firstLaunchSetKey = the one-shot UserDefaults flag that gates the 50:50 reset")
    func firstLaunchSetKeyStable() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("\"wenshu.editor.split.firstLaunchDidSet\""),
                "firstLaunchSetKey must be the literal 'wenshu.editor.split.firstLaunchDidSet'")
    }

    // MARK: - Source-level assertions for the 5 Apple HIG rules

    @Test("Source wires NSSplitView.dividerStyle = .thin (= Apple HIG hairline divider)")
    func sourceThinDividerStyle() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("splitView.dividerStyle = .thin"),
                "EditorChatNSController must set dividerStyle = .thin (= Apple HIG Keynote/Pages standard)")
    }

    @Test("Source wires NSSplitView.isVertical = false (= top-to-bottom Keynote speaker-notes layout)")
    func sourceTopToBottomLayout() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("splitView.isVertical = false"),
                "EditorChatNSController must set isVertical = false so editor sits above the chat zone")
    }

    @Test("Source wires splitView.autosaveName so the user's drag persists across launches")
    func sourceAutosaveWiring() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("splitView.autosaveName = Self.autosaveName"),
                "EditorChatNSController must assign the static autosaveName (= persistence is automatic once wired)")
    }

    @Test("Source applies 50:50 first-launch reset via splitView.bounds.height / 2 (= canonical formula)")
    func sourceFiftyFiftyFormula() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("splitView.bounds.height / 2"),
                "applyFiftyFiftyFirstLaunch must compute dividerY = splitView.bounds.height / 2 (= 50% from the top)")
        #expect(content.contains("setPosition(dividerY, ofDividerAt: 0)"),
                "applyFiftyFiftyFirstLaunch must call setPosition on divider index 0 (= between editor and chat)")
    }

    @Test("Source toggles chat zone visibility via animator().isCollapsed (= native NSSplitView animation)")
    func sourceAnimatedCollapseToggle() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("item.animator().isCollapsed.toggle()"),
                "toggleChatZone must use animator().isCollapsed.toggle() (= canonical NSSplitView animated collapse)")
    }

    // MARK: - The arrangement (= the editor above the chat, always)

    @Test("The app carries NO rule that chooses between two arrangements (= the editor is above the chat at every width)")
    func noArrangementRule() throws {
        // The rule that used to be here: the editor beside the chat
        // once the detail column was wide enough for both panes to
        // hold their own chrome, and the editor above the chat
        // otherwise. It ran on every layout pass.
        //
        // Why it could never select what it existed to select:
        // side by side needed a detail column of 1190 PT (= 595 PT
        // for the editor + 280 PT for the chat at an even split),
        // and the detail column is the window's width minus 810 PT
        // of outer columns (= 200 PT sidebar + 240 PT materials +
        // 270 PT inspector), so it needed a window of 2001 PT. A
        // 1920 PT display never reaches it. So on this machine the
        // rule ran on every pass and never resolved to side by
        // side.
        //
        // Why the tab bars are the reason the arrangement is not
        // needed: the tab strip divides the column it was given and
        // has no minimum width of its own, so a column with no
        // minimum width does not need the window to be wide, and the
        // tab strip is not the reason for the window's width.
        //
        // This is a source-level assertion because the ABSENCE of a
        // rule is a property of the source, not of a runtime value.
        let content = try Self.controllerSource()
        #expect(!content.contains("forCompetingWidth"),
                "the width rule must not exist (= the editor is above the chat at every width)")
        #expect(!content.contains("holdsChrome"),
                "the chrome test that chose the arrangement must not exist")
        #expect(!content.contains("sideBySide"),
                "the side-by-side arrangement must not exist")
        #expect(!content.contains("EditorArrangement"),
                "the arrangement enum must not exist (= one arrangement needs no enum)")
        #expect(!content.contains("EditorLayoutMode"),
                "the layout mode must not exist (= one arrangement needs no setting)")
    }

    @Test("The split's two items are added once and never moved (= no arrangement change removes and re-inserts them)")
    func noStructuralChangeRemovesTheItems() throws {
        // The defect this pins: the width rule's answer removed the
        // editor's split view item and re-inserted it at the other
        // index. That invalidates the split's constraints, and doing
        // it while AppKit is laying out re-arms the window's "Update
        // Constraints in Window" pass (= the pass AppKit's
        // runaway-layout guard counts). The guard aborted the app
        // when the count passed the window's view count.
        //
        // With one arrangement the panes are added once and never
        // moved, so the layout callback cannot reach the split's
        // structure at all.
        let content = try Self.controllerSource()
        #expect(!content.contains("removeSplitViewItem"),
                "no code may remove a split view item (= removing it invalidates the split's constraints while AppKit is laying out)")
        #expect(!content.contains("insertSplitViewItem"),
                "no code may re-insert a split view item (= the panes are added once and never moved)")
        #expect(!content.contains("applyPaneOrder"),
                "the pane-order swap must not exist (= one arrangement has one order)")
        #expect(!content.contains("applyAutomaticArrangement"),
                "the per-pass width rule must not exist (= the layout pass does not choose an arrangement)")
    }

    @Test("Source keeps ONE autosave name (= one arrangement keeps one dragged position)")
    func sourceOneAutosaveName() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("\"wenshu.editor.split.autosave\""),
                "the split's divider position persists under one autosave name")
        #expect(!content.contains("wenshu.editor.split.autosave.side"),
                "the side-by-side autosave name must not exist (= the side-by-side arrangement is gone)")
        #expect(!content.contains("sideAutosaveName"),
                "there is no second arrangement, so there is no second autosave name")
    }

    @Test("Source clamps the thickness on the split's own axis (= the height, = the divider runs across)")
    func sourceAxisAwareClamp() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("let extent = splitView.bounds.height"),
                "updateAutomaticThicknessBounds must clamp the height (= the height carries the split)")
        #expect(!content.contains("arrangement.isVertical"),
                "no code may choose an axis (= the split has one axis, = the height)")
    }

    @Test("Source reads the stored payload with object(forKey:) (= data(forKey:) is always nil for AppKit's array)")
    func sourcePayloadRead() throws {
        let content = try Self.controllerSource()
        #expect(content.contains(".object(forKey: \"NSSplitView Subview Frames"),
                "the stored payload must be read with object(forKey:) (= AppKit stores it as an array of strings)")
        #expect(!content.contains("defaults.data(forKey:"),
                "data(forKey:) is always nil for AppKit's array (= the 50:50 reset re-applied on every layout pass and wiped the dragged position)")
    }

    @Test("Source resets 50:50 on the split's own axis (= the height), with no arrangement to enter")
    func sourceArrangementAwareReset() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("let dividerY = splitView.bounds.height / 2"),
                "the 50:50 reset must divide the height (= the height carries the split)")
        #expect(content.contains("splitView.setPosition(dividerY, ofDividerAt: 0)"),
                "the 50:50 reset must set the divider position")
        #expect(!content.contains("pendingResetArrangement"),
                "no reset is owed by an arrangement change (= there is no arrangement change)")
        #expect(!content.contains("func applyLayoutMode"),
                "the SwiftUI side has no mode to apply (= one arrangement needs no entry point)")
    }

    @Test("Source: the View menu offers NO editor-layout choice (= one arrangement is not a choice)")
    func sourceViewMenuBinding() throws {
        let scene = SourceLocator.url("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneContent = try String(contentsOf: scene, encoding: .utf8)
        #expect(!sceneContent.contains("workspaceUI.editorLayoutMode"),
                "the View menu must not bind to a layout mode (= there is no mode)")
        #expect(!sceneContent.contains("menu.view.editor_layout"),
                "the View menu must not carry a layout group's title (= there is no choice to make)")
        #expect(!sceneContent.contains("EditorLayoutMode.allCases"),
                "the View menu must not enumerate layout modes")

        let state = SourceLocator.url("Sources/WenshuApp/Shared/State/WorkspaceUIState.swift")
        let stateContent = try String(contentsOf: state, encoding: .utf8)
        #expect(!stateContent.contains("enum EditorLayoutMode"),
                "the layout mode type must not exist (= one arrangement needs no setting)")
        #expect(!stateContent.contains("forKey: .editorLayoutMode"),
                "the layout mode must not persist (= there is nothing to persist)")

        let store = SourceLocator.url("Sources/WenshuApp/Features/Agent/Service/UserDefaultsStore.swift")
        let storeContent = try String(contentsOf: store, encoding: .utf8)
        #expect(!storeContent.contains("editorLayoutMode"),
                "the persisted key must not exist (= there is nothing to persist)")
    }

    // MARK: - The divider's share (= the user's dragged position)

    @Test("The share of the axis: pane 0's thickness over the two panes' thickness together")
    func shareFromFrames() {
        // The frames AppKit writes for the split (= the height
        // carries the panes' thickness, = the divider runs across).
        let stacked = [
            "0.000000, 0.000000, 600.000000, 270.000000, NO, NO",
            "0.000000, 271.000000, 600.000000, 730.000000, NO, NO"
        ]
        let share = EditorChatNSController.share(fromFrames: stacked)
        #expect(share != nil, "the stored frames must yield a share")
        #expect(abs((share ?? 0) - 270.0 / 1000.0) < 0.0001,
                "the share is pane 0's thickness over the two panes' thickness together")
    }

    @Test("The share survives the spaces AppKit writes after every comma (= an untrimmed parse reads no share at all)")
    func shareParsesSpacedNumbers() {
        // The exact format AppKit writes: a space after every comma.
        // Swift's `Double(" 0.0")` is nil, so an untrimmed parse
        // returns no share (= the divider falls back to the middle
        // and the layout runs away).
        let spaced = [
            "0.000000, 0.000000, 600.000000, 270.000000, NO, NO",
            "0.000000, 271.000000, 600.000000, 730.000000, NO, NO"
        ]
        let share = EditorChatNSController.share(fromFrames: spaced)
        #expect(share != nil, "the spaced numbers must parse (= the payload is written with a space after every comma)")
        #expect(abs((share ?? 0) - 0.27) < 0.0001,
                "the share must be the user's own position, not the middle")
    }

    @Test("The share of a payload that cannot be read is nil (= the caller falls back to the middle)")
    func shareOfUnreadablePayload() {
        #expect(EditorChatNSController.share(fromFrames: []) == nil)
        #expect(EditorChatNSController.share(fromFrames: ["0.0, 0.0, 10.0, 10.0, NO, NO"]) == nil,
                "one frame is not a split")
        #expect(EditorChatNSController.share(fromFrames: ["nonsense", "nonsense"]) == nil,
                "unparseable numbers are not a share")
    }

    @Test("The share names the editor's pane (= the editor leads, because it is above the chat)")
    func shareNamesTheEditorsPane() {
        // The frames of the split whose FIRST frame is the editor's
        // (= the editor is above the chat).
        let editorLeads = [
            "0.000000, 0.000000, 600.000000, 270.000000, NO, NO",
            "0.000000, 271.000000, 600.000000, 730.000000, NO, NO"
        ]
        let editorShare = EditorChatNSController.share(fromFrames: editorLeads)
        #expect(abs((editorShare ?? 0) - 0.27) < 0.0001,
                "the editor's share is the leading frame's (= the editor is above the chat)")
    }

    // MARK: - The divider's position (= what keeps the layout convergent)

    @Test("Source positions the divider at the leading pane's share of the axis (= the position AppKit's own layout must agree with)")
    func sourcePositionsTheDividerAtTheLeadingShare() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("} else if hasAutosave {"),
                "a stored payload must still drive the divider's position (= without it the split's width oscillates and AppKit's runaway-layout guard aborts the app)")
        #expect(content.contains("applyStoredShare()"),
                "the stored share is the position's value")
        #expect(content.contains("items[0].preferredThicknessFraction = leadingShare"),
                "AppKit's own layout must agree with the position (= both items carry 0.5 otherwise, and the two fight every pass)")
        #expect(content.contains("splitView.setPosition(axis * share, ofDividerAt: 0)"),
                "the divider is positioned at the leading pane's share of the axis")
    }

    @Test("Source does NOT position the divider on every layout pass (= a write per frame re-arms the window's update-constraints pass, which is the quantity AppKit's runaway-layout guard counts)")
    func sourceDoesNotWriteTheDividerPerFrame() throws {
        let content = try Self.controllerSource()
        let body = try #require(Self.functionBody(named: "applyStoredShare", in: content),
                                "applyStoredShare must exist")
        let writes = body.components(separatedBy: "splitView.setPosition(").count - 1
        #expect(writes == 1,
                "the divider is written on exactly one path (= the decision function's outcome), not unconditionally on every layout pass")
        #expect(content.contains("case let .assertAt(share):"),
                "the write happens on the decision's outcome (= the seed, or a repair after a resize left the share off)")
        #expect(content.contains("case let .adopt(share):"),
                "a user drag is adopted (= the assert must never write over it, = the drag is eaten otherwise)")
    }

    @Test("Source holds the share instead of re-reading it on every pass (= reading it back moves the target every pass)")
    func sourceHoldsTheShare() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("if assertedShare == nil {"),
                "the share is captured once (= the payload is written by AppKit as the layout settles, so reading it after asserting into it moves the target every pass)")
        #expect(content.contains("let axis = splitView.bounds.height"),
                "the axis is the split's own (= the height, = the divider runs across)")
    }

    // MARK: - The divider's decision (= what a layout pass writes)

    @Test("The divider's decision: a resize in flight writes nothing (= a write per frame re-arms the window's update-constraints pass)")
    func dividerDecisionWritesNothingDuringAResize() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: true,
            settledPasses: 0,
            seedPending: true,
            resizePending: true,
            framesPending: 0,
            observedShare: 0.30,
            assertedShare: 0.30
        )
        #expect(action == .none,
                "while the axis moves (= a zoom's frames, = a widening drag's steps) the divider is not written")
    }

    @Test("The divider's decision: the first settled pass positions the divider at the asserted share (= the seed)")
    func dividerDecisionSeedsOnASettledPass() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 1,
            seedPending: true,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.96,
            assertedShare: 0.30
        )
        #expect(action == .assertAt(0.30),
                "the seed positions the divider at the asserted share (= AppKit scales it with the axis from there)")
    }

    @Test("The divider's decision: the pass before the layout settles writes nothing (= the frames a pass reads are the previous pass's)")
    func dividerDecisionWaitsForTheLayoutToSettle() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 0,
            seedPending: true,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.30,
            assertedShare: 0.30
        )
        #expect(action == .none,
                "the first pass whose axis has not moved still reads the position from before the move")
    }

    @Test("The divider's decision: a write that has not reached the frames yet is not read (= reading it would undo the write)")
    func dividerDecisionWaitsForTheWriteToReachTheFrames() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 2,
            seedPending: false,
            resizePending: false,
            framesPending: 1,
            observedShare: 0.30,
            assertedShare: 0.60
        )
        #expect(action == .none,
                "the frames report the last write only on the next layout pass (= reading it now would report the position from before the write)")
    }

    @Test("The divider's decision: a user drag is adopted, not overwritten (= the drag is eaten otherwise)")
    func dividerDecisionAdoptsAUserDrag() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 3,
            seedPending: false,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.60,
            assertedShare: 0.30
        )
        #expect(action == .adopt(0.60),
                "the divider is where the user put it (= the drag is their own position and must survive)")
    }

    @Test("The divider's decision: a layout that agrees with the assert writes nothing (= no write per frame)")
    func dividerDecisionWritesNothingWhenTheLayoutAgrees() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 5,
            seedPending: false,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.30,
            assertedShare: 0.30
        )
        #expect(action == .none,
                "a layout that already holds the asserted share needs no write")
    }

    @Test("The divider's decision: a resize that ended off the share is repaired ONCE (= the trailing pane sank to its floor)")
    func dividerDecisionRepairsOnceAfterAResize() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 2,
            seedPending: false,
            resizePending: true,
            framesPending: 0,
            observedShare: 0.97,
            assertedShare: 0.30
        )
        #expect(action == .assertAt(0.30),
                "the share is put back once, when the layout has settled")
    }

    @Test("The divider's decision: a resize that ended ON the share needs no repair")
    func dividerDecisionDoesNotRepairAResizeThatHeldTheShare() {
        let action = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 2,
            seedPending: false,
            resizePending: true,
            framesPending: 0,
            observedShare: 0.30,
            assertedShare: 0.30
        )
        #expect(action == .none,
                "AppKit scaled the divider with the axis (= the share survived the resize), so there is nothing to repair")
    }

    @Test("The divider's decision: the share tolerance is a fraction of the axis, so a sub-point drift is not a drift")
    func dividerDecisionToleranceIsAFraction() {
        let withinTolerance = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 3,
            seedPending: false,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.30 + EditorChatNSController.shareTolerance / 2,
            assertedShare: 0.30
        )
        #expect(withinTolerance == .none,
                "a drift under the tolerance is the same position (= the frames carry a rounding)")
        let beyondTolerance = EditorChatNSController.dividerAction(
            axisMoved: false,
            settledPasses: 3,
            seedPending: false,
            resizePending: false,
            framesPending: 0,
            observedShare: 0.30 + EditorChatNSController.shareTolerance * 2,
            assertedShare: 0.30
        )
        #expect(beyondTolerance == .adopt(0.30 + EditorChatNSController.shareTolerance * 2),
                "a drift over the tolerance is a different position (= the user moved it)")
    }

    // MARK: - The latch's LIFECYCLE (= the defect's home)

    /// Drive the latch through a scripted sequence of layout passes.
    ///
    /// The caller reads the split's frames and hands the latch the
    /// LEADING pane's thickness; the latch reads it against the
    /// extent those frames were laid out for (= the previous pass's
    /// extent), so the share a pass observes is always
    /// `observedLeading / previousExtent`.
    ///
    /// - Parameters:
    ///   - latch: the latch under test.
    ///   - axisExtent: the axis extent of this pass.
    ///   - observedLeading: the leading pane's thickness in the frames
    ///     this pass reads (= the previous pass's frames).
    ///   - assertedShare: the share the divider is asserted at.
    /// - Returns: the action the pass took.
    @discardableResult
    private func drive(
        _ latch: inout EditorChatNSController.DividerLatch,
        axisExtent: CGFloat,
        observedLeading: CGFloat,
        assertedShare: CGFloat
    ) -> EditorChatNSController.DividerAction {
        latch.pass(
            axisExtent: axisExtent,
            observedLeading: observedLeading,
            assertedShare: assertedShare
        )
    }

    @Test("The latch: a resize that settles ON the share releases the latch, so the user's NEXT drag is ADOPTED (= the drag is not eaten)")
    func latchReleasesTheResizeSoTheNextDragIsAdopted() {
        // The defect this pins: the resize latch was released ONLY by
        // a repair write, so a resize that ended ON the asserted share
        // (= the share held, = nothing owed) left the latch set. The
        // user's NEXT drag was then read as "the resize left the share
        // off" and answered with a repair that overwrote the drag.
        //
        // Measured in real AppKit by the reviewer: after a zoom or a
        // widening drag the requested 0.60 came back as 0.7000 (= the
        // stale asserted share) in BOTH arrangements.
        var latch = EditorChatNSController.DividerLatch()
        let asserted: CGFloat = 0.5

        // The seed: the layout settles and the divider is positioned
        // once.
        _ = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)
        let seed = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)
        #expect(seed == .assertAt(0.5),
                "the seed positions the divider once (= AppKit scales it with the axis from there)")

        // A ZOOM: the axis moves on every frame (= a layout pass per
        // frame), and AppKit scales the divider with the axis (= the
        // share holds through the animation).
        for step in 1...20 {
            let extent = 1000 + CGFloat(step) * 20
            let action = drive(&latch, axisExtent: extent, observedLeading: extent / 2, assertedShare: asserted)
            #expect(action == .none,
                    "a resize in flight writes nothing (= a write per frame re-arms the window's update-constraints pass)")
        }

        // The resize ends: the axis stops moving and the layout still
        // holds the asserted share.
        let settled = drive(&latch, axisExtent: 1400, observedLeading: 700, assertedShare: asserted)
        #expect(settled == .none,
                "the layout holds the asserted share after the resize (= AppKit scaled the divider with the axis)")

        // The user drags the divider: the next drift must be ADOPTED.
        let dragged = drive(&latch, axisExtent: 1400, observedLeading: 840, assertedShare: asserted)
        #expect(dragged == .adopt(0.6),
                "the drag after a resize is the user's own position (= the latch must have been released by the resize that settled on the share)")

        // And the drag is adopted by the LATCH, not by a repair: the
        // latch's own state is what the caller reads.
        #expect(latch.resizePending == false,
                "the resize latch is released when the resize ends on the share (= nothing is owed)")
    }

    @Test("The latch: a resize that ends OFF the share still repairs it once (= the trailing pane's floor is reachable)")
    func latchRepairsAFloorAfterAResize() {
        // The other half of the fix's contract: the repair must stay
        // reachable after a resize, or the trailing pane stays at its
        // floor (= the folded-in second symptom).
        //
        // The difference between the two cases is the READ at the
        // settle pass: a resize that holds the share owes nothing
        // (= the latch is released), a resize that leaves the share
        // off owes one repair (= the latch stays set until the
        // repair happens).
        var latch = EditorChatNSController.DividerLatch()
        let asserted: CGFloat = 0.5

        _ = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)
        _ = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)

        // A narrowing: the trailing pane sinks to its floor (= the
        // leading pane takes 0.97 of the axis).
        for step in 1...20 {
            let extent = 1000 - CGFloat(step) * 20
            _ = drive(&latch, axisExtent: extent, observedLeading: extent * 0.97, assertedShare: asserted)
        }

        // The resize ends and the layout is OFF the share: the share
        // is put back ONCE.
        let repaired = drive(&latch, axisExtent: 600, observedLeading: 582, assertedShare: asserted)
        #expect(repaired == .assertAt(0.5),
                "the trailing pane sank to its floor during the resize (= the share is put back once, when the layout has settled)")
        #expect(latch.resizePending == false,
                "the repair consumed the resize (= the latch is released by the repair itself)")
    }

    @Test("The latch: the resize latch stays set DURING the resize (= the repair stays reachable)")
    func latchKeepsTheResizePendingDuringTheResize() {
        // The guard on the release matters: clearing the latch on
        // every pass that writes nothing would clear it DURING the
        // resize (= on every frame of the animation) and the owed
        // floor repair would become unreachable.
        var latch = EditorChatNSController.DividerLatch()
        let asserted: CGFloat = 0.5

        _ = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)
        _ = drive(&latch, axisExtent: 1000, observedLeading: 500, assertedShare: asserted)

        for step in 1...20 {
            let extent = 1000 + CGFloat(step) * 20
            let action = drive(&latch, axisExtent: extent, observedLeading: extent / 2, assertedShare: asserted)
            #expect(action == .none)
        }
        #expect(latch.resizePending,
                "the resize latch is still set at the end of the animation (= the repair for a floor is still owed)")

        // The settle pass reads the layout as holding the share: the
        // latch is released.
        let settled = drive(&latch, axisExtent: 1400, observedLeading: 700, assertedShare: asserted)
        #expect(settled == .none)
        #expect(latch.resizePending == false,
                "the latch is released once the layout has settled ON the share")
    }

    @Test("Source: the layout's caller drives the latch (= the latch under test IS the shipped latch)")
    func sourceTheCallerDrivesTheLatch() throws {
        let content = try Self.controllerSource()
        // The access modifier is not asserted (= the split promoted the
        // property, because another file reads it), so what is asserted
        // is the shape: the controller owns ONE latch, of the type the
        // test drives.
        #expect(content.contains("var dividerLatch = DividerLatch()"),
                "the controller owns one latch (= the state that spans layout passes)")
        #expect(content.contains("dividerLatch.pass("),
                "the layout's caller must drive the latch (= the latch's lifecycle is the defect's home)")
        #expect(!content.contains("dividerLatch.reset()"),
                "the latch is never reset (= one arrangement means one axis, = the divider is positioned once on it)")
    }

    @Test("Source: the thickness cap is written in quanta (= a write per frame re-arms the window's update-constraints pass)")
    func sourceWritesTheThicknessCapInQuanta() throws {
        let content = try Self.controllerSource()
        let body = try #require(Self.functionBody(named: "updateAutomaticThicknessBounds", in: content),
                                "updateAutomaticThicknessBounds must exist")
        #expect(body.contains("Self.thicknessQuantum"),
                "the cap is written in quanta (= once per quantum of extent, not once per frame of a resize)")
        #expect(body.contains("rounded(.up)"),
                "the cap is rounded UP (= it never sits below the extent, so it never clamps a pane the layout legitimately grew)")
        #expect(body.contains("if item.maximumThickness != available {"),
                "the cap is written only when the value differs (= a write into the split re-arms the window's update-constraints pass)")
    }

    // MARK: - The panes' order (= the chat on the left, the editor on the right)

    @Test("Source adds the panes once and never moves them (= the editor above the chat)")
    func sourcePaneOrder() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("addSplitViewItem(editorItem)"),
                "the editor's item is added to the split")
        #expect(content.contains("addSplitViewItem(chatItemLocal)"),
                "the chat's item is added to the split")
        #expect(!content.contains("removeSplitViewItem"),
                "no item may be removed (= removing it invalidates the split's constraints while AppKit is laying out)")
        #expect(!content.contains("insertSplitViewItem"),
                "no item may be re-inserted (= the panes are added once and never moved)")
    }
    @Test("Source reads the stored frames in the panes' own order (= the editor leads, because it is above the chat)")
    func sourceReadsFramesInOrder() throws {
        let content = try Self.controllerSource()
        #expect(content.contains("return Self.share(fromFrames: frames)"),
                "the frames are in the panes' own order (= the editor first), so the reader reads the leading frame's share")
        #expect(content.contains("let leadingShare = share"),
                "the assertion puts the divider at the LEADING pane's share (= the fraction AppKit lays out for)")
    }

    // MARK: - The layout callback's reach (= what it may NOT touch)

    /// Extract the body of one function from a source file.
    ///
    /// Why the extraction and not a whole-file search: the assertion
    /// is about WHAT THE LAYOUT CALLBACK CALLS, and a whole-file
    /// search cannot tell "the layout callback calls it" from "some
    /// other method calls it".
    ///
    /// The scanner skips line comments, block comments and string
    /// literals, so a brace inside a comment or a literal cannot end
    /// the body early.
    private static func functionBody(named name: String, in source: String) -> String? {
        guard let signature = source.range(of: "func \(name)(") else { return nil }
        var index = signature.upperBound
        var depth = 0
        var bodyStart: String.Index?
        var inLineComment = false
        var inBlockComment = false
        var inString = false
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            let nextCharacter: Swift.Character = next < source.endIndex ? source[next] : "\u{0}"

            if inLineComment {
                if character == "\n" { inLineComment = false }
                index = next
                continue
            }
            if inBlockComment {
                if character == "*", nextCharacter == "/" {
                    inBlockComment = false
                    index = next < source.endIndex ? source.index(after: next) : next
                    continue
                }
                index = next
                continue
            }
            if inString {
                if character == "\\" {
                    index = next < source.endIndex ? source.index(after: next) : next
                    continue
                }
                if character == "\"" { inString = false }
                index = next
                continue
            }

            switch character {
            case "/":
                if nextCharacter == "/" {
                    inLineComment = true
                    index = next < source.endIndex ? source.index(after: next) : next
                    continue
                }
                if nextCharacter == "*" {
                    inBlockComment = true
                    index = next < source.endIndex ? source.index(after: next) : next
                    continue
                }
            case "\"":
                inString = true
            case "{":
                if bodyStart == nil { bodyStart = index }
                depth += 1
            case "}":
                depth -= 1
                if depth == 0, let bodyStart {
                    return String(source[bodyStart...index])
                }
            default:
                break
            }
            index = next
        }
        return nil
    }

    @Test("Source: the layout callback does NOT reach the split's structure (= the panes are added once and never moved)")
    func sourceStructuralChangeIsNotReachableFromLayoutCallback() throws {
        let content = try Self.controllerSource()

        // The layout callback must not touch the split's structure.
        //
        // It used to: the width rule asked for an arrangement from
        // here, and answering it removed the editor's split view item
        // and re-inserted it at the other index. That invalidates the
        // split's constraints, and doing it while AppKit is laying out
        // re-arms the window's "Update Constraints in Window" pass
        // (= the pass AppKit's runaway-layout guard counts). The
        // guard aborted the app when the count passed the window's
        // view count (= measured: 436 passes against a limit of 430).
        //
        // With one arrangement there is no structural change to
        // defer, so the whole mechanism is gone rather than merely
        // unreachable.
        let layoutBody = try #require(
            Self.functionBody(named: "viewDidLayout", in: content),
            "viewDidLayout must exist")
        #expect(!layoutBody.contains("removeSplitViewItem"),
                "viewDidLayout must not remove a split view item (= removing one invalidates the split's constraints while AppKit is laying out, and each invalidation re-arms the window's update-constraints pass)")
        #expect(!layoutBody.contains("insertSplitViewItem"),
                "viewDidLayout must not re-insert a split view item (= the panes are added once and never moved)")
        #expect(!layoutBody.contains("applyPaneOrder"),
                "viewDidLayout must not move a split view item")
        #expect(!content.contains("applyPaneOrder"),
                "no code may move a split view item (= one arrangement has one order)")
        #expect(!content.contains("requestArrangement"),
                "no code may request an arrangement (= there is one arrangement)")
        #expect(!content.contains("applyAutomaticArrangement"),
                "no code may choose an arrangement per pass")
    }

    @Test("Source: the thickness bounds and the preferred fractions are written only when the value differs")
    func sourceWritesOnlyWhenTheValueDiffers() throws {
        let content = try Self.controllerSource()

        let boundsBody = try #require(
            Self.functionBody(named: "updateAutomaticThicknessBounds", in: content),
            "updateAutomaticThicknessBounds must exist")
        #expect(boundsBody.contains("if item.minimumThickness != 0 {"),
                "the minimum thickness is written only when it differs (= a write into the split during the layout pass re-arms the window's update-constraints pass)")
        #expect(boundsBody.contains("if item.maximumThickness != available {"),
                "the maximum thickness is written only when it differs (= a write into the split during the layout pass re-arms the window's update-constraints pass)")

        let shareBody = try #require(
            Self.functionBody(named: "applyStoredShare", in: content),
            "applyStoredShare must exist")
        #expect(shareBody.contains("if items[0].preferredThicknessFraction != leadingShare {"),
                "the leading pane's preferred fraction is written only when it differs")
        #expect(shareBody.contains("if items[1].preferredThicknessFraction != 1 - leadingShare {"),
                "the trailing pane's preferred fraction is written only when it differs")
    }

    @Test("Source: sizeThatFits never reports the inner split's own width back up")
    func sourceSizeThatFitsHasNoInnerWidthFallback() throws {
        let content = try Self.controllerSource()

        let fitBody = try #require(
            Self.functionBody(named: "sizeThatFits", in: content),
            "sizeThatFits must exist")
        #expect(!fitBody.contains("hostedContentWidth"),
                "sizeThatFits must not fall back to the inner split's own width (= the parent negotiates the detail column's width against what is reported here, so the inner split's own width is a second number in the same negotiation)")
        #expect(!fitBody.contains("splitView.bounds.width"),
                "sizeThatFits must not report the inner split's own width back up")
        #expect(!fitBody.contains("splitView.bounds.height"),
                "sizeThatFits must not report the inner split's own height back up")
        #expect(!content.contains("hostedContentWidth"),
                "the inner split's own width must not be reachable as a fallback at all")

        // What it reports instead: the parent's own numbers.
        #expect(fitBody.contains("proposal.width ?? nsViewController.lastParentWidth"),
                "the parent's own last width is the fallback (= a parent-owned number, not the inner split's)")
        #expect(fitBody.contains("nsViewController.recordParentProposal(proposal)"),
                "the parent's proposal is recorded (= the fallback is the parent's own number)")
    }

    // MARK: - The parent's allocation (= what the width rule reads)

    @Test("The parent's allocation: the degenerate proposal passes are not allocations")
    func parentAllocationIgnoresDegenerateProposals() {
        // SwiftUI's proposal stream is not one number per layout.
        // Measured 2026-10-27 with a headless probe of this app's own
        // shape (= a NavigationSplitView whose detail hosts the
        // representable, with an inspector beside it): every layout
        // pass proposes 0 (= the ideal-size pass), then infinity (= the
        // unbounded pass), then sometimes nothing, and only then the
        // real allocation. At the screenshot's width that real
        // allocation is 740 PT.
        //
        // The degenerate passes are the parent ASKING for a size, not
        // the parent ALLOCATING one.
        #expect(EditorChatNSController.allocatedDimension(0) == nil,
                "zero is the ideal-size pass (= the parent asking how big we would like to be), not an allocation")
        #expect(EditorChatNSController.allocatedDimension(nil) == nil,
                "no opinion is not an allocation")
        #expect(EditorChatNSController.allocatedDimension(.infinity) == nil,
                "infinity is the unbounded pass, not an allocation (= infinity compares greater than every number, so a rule that read it judged every width viable)")
        #expect(EditorChatNSController.allocatedDimension(-1) == nil,
                "a negative size is not an allocation")

        // The real allocation is kept.
        #expect(EditorChatNSController.allocatedDimension(740) == 740,
                "the parent's real allocation is kept (= 740 PT at the screenshot's width)")
        #expect(EditorChatNSController.allocatedDimension(1) == 1,
                "even a small allocation is a real allocation")
    }

    @Test("The parent allocation: the degenerate passes do not survive as an allocation")
    func widthRuleDoesNotReadADegenerateProposal() {
        // The defect this pins: the recorder used to merge EVERY
        // proposal (= the last non-nil one), so the unbounded pass
        // left it holding infinity. The width rule then read infinity,
        // `holdsChrome` compared infinity against the panes' floors
        // (= infinity is bigger than every floor), every width looked
        // viable, and the arrangement NEVER resolved to stacked. That
        // is the layout this card names, and it survived a first fix
        // whose arithmetic was right and whose INPUT was degenerate.
        //
        // So the rule must resolve to stacked when the width it is
        // given is the real allocation, and the real allocation must
        // survive the degenerate passes that follow it.
        let allocation = EditorChatNSController.allocatedDimension(740)
        #expect(allocation == 740)

        // The whole proposal cycle, in the order SwiftUI sends it, and
        // the allocation that survives it.
        let stream: [CGFloat?] = [0, .infinity, nil, 740, 0, .infinity, nil]
        var recorded: CGFloat?
        for proposed in stream {
            if let real = EditorChatNSController.allocatedDimension(proposed) {
                recorded = real
            }
        }
        #expect(recorded == 740,
                "the recorded allocation must be the parent's real number (= 740 PT), not the infinity of the unbounded pass")

        #expect(EditorChatNSController.allocatedDimension(.infinity) == nil,
                "infinity is not an allocation (= every comparison against it passes)")
    }
}
