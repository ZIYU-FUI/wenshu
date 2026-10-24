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
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The autosaveName literal must match the UserDefaults
        // prefix 'NSSplitView Subview Frames'; = AppKit wires the
        // rest. Verify the exact constant value.
        #expect(content.contains("\"wenshu.editor.split.autosave\""),
                "autosaveName must be the literal 'wenshu.editor.split.autosave' (= AppKit stores the divider position under 'NSSplitView Subview Frames <name>')")
    }

    @Test("firstLaunchSetKey = the one-shot UserDefaults flag that gates the 50:50 reset")
    func firstLaunchSetKeyStable() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("\"wenshu.editor.split.firstLaunchDidSet\""),
                "firstLaunchSetKey must be the literal 'wenshu.editor.split.firstLaunchDidSet'")
    }

    // MARK: - Source-level assertions for the 5 Apple HIG rules

    @Test("Source wires NSSplitView.dividerStyle = .thin (= Apple HIG hairline divider)")
    func sourceThinDividerStyle() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("self.splitView.dividerStyle = .thin"),
                "EditorChatNSController must set dividerStyle = .thin (= Apple HIG Keynote/Pages standard)")
    }

    @Test("Source wires NSSplitView.isVertical = false (= top-to-bottom Keynote speaker-notes layout)")
    func sourceTopToBottomLayout() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("self.splitView.isVertical = false"),
                "EditorChatNSController must set isVertical = false so editor sits above the chat zone")
    }

    @Test("Source wires splitView.autosaveName so the user's drag persists across launches")
    func sourceAutosaveWiring() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("self.splitView.autosaveName = Self.autosaveName"),
                "EditorChatNSController must assign the static autosaveName (= persistence is automatic once wired)")
    }

    @Test("Source applies 50:50 first-launch reset via splitView.bounds.height / 2 (= canonical formula)")
    func sourceFiftyFiftyFormula() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("splitView.bounds.height / 2"),
                "applyFiftyFiftyFirstLaunch must compute dividerY = splitView.bounds.height / 2 (= 50% from the top)")
        #expect(content.contains("setPosition(dividerY, ofDividerAt: 0)"),
                "applyFiftyFiftyFirstLaunch must call setPosition on divider index 0 (= between editor and chat)")
    }

    @Test("Source toggles chat zone visibility via animator().isCollapsed (= native NSSplitView animation)")
    func sourceAnimatedCollapseToggle() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("item.animator().isCollapsed.toggle()"),
                "toggleChatZone must use animator().isCollapsed.toggle() (= canonical NSSplitView animated collapse)")
    }

    // MARK: - The width rule (= pure; = no window and no split view)

    @Test("The width rule: side by side at 1000 PT and above, stacked below 920 PT, the band between keeps the current arrangement")
    func widthRule() {
        // The two measured numbers.
        #expect(EditorChatNSController.sideBySideMinimumWidth == 1000)
        #expect(EditorChatNSController.stackedMaximumWidth == 920)
        // Side by side when the split gives both columns room.
        #expect(EditorChatNSController.arrangement(forSplitWidth: 1000, mode: .automatic, current: .stacked) == .sideBySide)
        #expect(EditorChatNSController.arrangement(forSplitWidth: 1209, mode: .automatic, current: .stacked) == .sideBySide)
        // Stacked when the split is too narrow for two columns.
        #expect(EditorChatNSController.arrangement(forSplitWidth: 919, mode: .automatic, current: .sideBySide) == .stacked)
        #expect(EditorChatNSController.arrangement(forSplitWidth: 689, mode: .automatic, current: .sideBySide) == .stacked)
        // The band between the two numbers keeps the current arrangement.
        #expect(EditorChatNSController.arrangement(forSplitWidth: 950, mode: .automatic, current: .stacked) == .stacked)
        #expect(EditorChatNSController.arrangement(forSplitWidth: 950, mode: .automatic, current: .sideBySide) == .sideBySide)
        // The two manual cases win over the width rule.
        #expect(EditorChatNSController.arrangement(forSplitWidth: 1209, mode: .stacked, current: .sideBySide) == .stacked)
        #expect(EditorChatNSController.arrangement(forSplitWidth: 689, mode: .sideBySide, current: .stacked) == .sideBySide)
    }

    @Test("The layout mode has exactly the three cases the View menu offers")
    func threeModes() {
        #expect(EditorLayoutMode.allCases.count == 3)
        #expect(EditorLayoutMode.allCases == [.automatic, .stacked, .sideBySide])
        #expect(EditorLayoutMode(rawValue: "sideBySide") == .sideBySide)
        #expect(EditorLayoutMode(rawValue: "nonsense") == nil)
    }

    // MARK: - Source-level assertions for the arrangement switch

    @Test("Source keeps one autosave name per arrangement")
    func sourceTwoAutosaveNames() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("\"wenshu.editor.split.autosave.side\""),
                "the side-by-side arrangement needs its own autosave name (= each arrangement keeps its own dragged position)")
        #expect(content.contains("private static let sideAutosaveName"),
                "the side-by-side autosave name must be a named constant (= the two names travel together)")
    }

    @Test("Source clamps the thickness on the arrangement's own axis")
    func sourceAxisAwareClamp() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height"),
                "updateAutomaticThicknessBounds must clamp the width when side by side and the height when stacked")
    }

    @Test("Source reads the stored payload with object(forKey:) (= data(forKey:) is always nil for AppKit's array)")
    func sourcePayloadRead() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".object(forKey: \"NSSplitView Subview Frames"),
                "the stored payload must be read with object(forKey:) (= AppKit stores it as an array of strings)")
        #expect(!content.contains("defaults.data(forKey:"),
                "data(forKey:) is always nil for AppKit's array (= the 50:50 reset re-applied on every layout pass and wiped the dragged position)")
    }

    @Test("Source resets 50:50 on the arrangement's own axis and only when the entered arrangement has no stored payload")
    func sourceArrangementAwareReset() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("let dividerX = self.splitView.bounds.width / 2"),
                "the side-by-side 50:50 reset must divide the width (= the width carries the split side by side)")
        #expect(content.contains("self.splitView.setPosition(dividerX, ofDividerAt: 0)"),
                "the side-by-side 50:50 reset must set the divider position")
        #expect(content.contains("pendingResetArrangement = keepsOwnPosition ? nil : target"),
                "the 50:50 reset is owed only when the arrangement being entered has no stored payload of its own")
        #expect(content.contains("func applyLayoutMode(_ mode: EditorLayoutMode)"),
                "the SwiftUI side needs an entry point that applies the chosen mode")
    }

    @Test("Source binds the View menu to the three layout modes")
    func sourceViewMenuBinding() throws {
        let scene = SourceLocator.url("Sources/WenshuApp/App/AppRootScene.swift")
        let sceneContent = try String(contentsOf: scene, encoding: .utf8)
        #expect(sceneContent.contains("workspaceUI.editorLayoutMode"),
                "the View menu must bind to the layout mode")
        #expect(sceneContent.contains(".pickerStyle(.radioGroup)"),
                "the three choices must render as a radio group (= the checkmark follows the choice)")
        #expect(sceneContent.contains("menu.view.editor_layout"),
                "the View menu needs the layout group's title")

        let state = SourceLocator.url("Sources/WenshuApp/Shared/State/WorkspaceUIState.swift")
        let stateContent = try String(contentsOf: state, encoding: .utf8)
        #expect(stateContent.contains("enum EditorLayoutMode"),
                "the layout mode type lives with the other workspace UI state")
        #expect(stateContent.contains("case automatic")
                && stateContent.contains("case stacked")
                && stateContent.contains("case sideBySide"),
                "the mode must carry the three cases the menu offers")
        #expect(stateContent.contains("forKey: .editorLayoutMode"),
                "the mode must persist through UserDefaultsStore")
    }

    // MARK: - The divider's share (= the user's dragged position)

    @Test("The share of the axis: pane 0's thickness over the two panes' thickness together")
    func shareFromFrames() {
        // The frames AppKit writes for a side-by-side split (= the
        // width carries the panes' thickness).
        let sideBySide = [
            "0.000000, 0.000000, 270.000000, 600.000000, NO, NO",
            "271.000000, 0.000000, 730.000000, 600.000000, NO, NO"
        ]
        let share = EditorChatNSController.share(fromFrames: sideBySide, isVertical: true)
        #expect(share != nil, "the stored frames must yield a share")
        #expect(abs((share ?? 0) - 270.0 / 1000.0) < 0.0001,
                "the share is pane 0's thickness over the two panes' thickness together")

        // The same frames read as a stacked split (= the height
        // carries the panes' thickness) give the even split, because
        // both panes are the same height there.
        let stacked = [
            "0.000000, 0.000000, 600.000000, 270.000000, NO, NO",
            "0.000000, 271.000000, 600.000000, 730.000000, NO, NO"
        ]
        let stackedShare = EditorChatNSController.share(fromFrames: stacked, isVertical: false)
        #expect(abs((stackedShare ?? 0) - 270.0 / 1000.0) < 0.0001,
                "the stacked arrangement reads the panes' heights")
    }

    @Test("The share survives the spaces AppKit writes after every comma (= an untrimmed parse reads no share at all)")
    func shareParsesSpacedNumbers() {
        // The exact format AppKit writes: a space after every comma.
        // Swift's `Double(" 0.0")` is nil, so an untrimmed parse
        // returns no share (= the divider falls back to the middle
        // and the layout runs away).
        let spaced = [
            "0.000000, 0.000000, 270.000000, 600.000000, NO, NO",
            "271.000000, 0.000000, 730.000000, 600.000000, NO, NO"
        ]
        let share = EditorChatNSController.share(fromFrames: spaced, isVertical: true)
        #expect(share != nil, "the spaced numbers must parse (= the payload is written with a space after every comma)")
        #expect(abs((share ?? 0) - 0.27) < 0.0001,
                "the share must be the user's own position, not the middle")
    }

    @Test("The share of a payload that cannot be read is nil (= the caller falls back to the middle)")
    func shareOfUnreadablePayload() {
        #expect(EditorChatNSController.share(fromFrames: [], isVertical: true) == nil)
        #expect(EditorChatNSController.share(fromFrames: ["0.0, 0.0, 10.0, 10.0, NO, NO"], isVertical: true) == nil,
                "one frame is not a split")
        #expect(EditorChatNSController.share(fromFrames: ["nonsense", "nonsense"], isVertical: true) == nil,
                "unparseable numbers are not a share")
    }

    @Test("The share names the editor's pane (= the chat leads when the panes stand side by side)")
    func shareNamesTheEditorsPane() {
        // The frames of a side-by-side split whose FIRST frame is
        // 270 PT wide (= the chat, because the chat is on the left).
        let chatLeads = [
            "0.000000, 0.000000, 270.000000, 600.000000, NO, NO",
            "271.000000, 0.000000, 730.000000, 600.000000, NO, NO"
        ]
        // The chat leads: the EDITOR's share is the second frame's.
        let editorShare = EditorChatNSController.share(
            fromFrames: chatLeads, isVertical: true, firstPaneLeads: false)
        #expect(abs((editorShare ?? 0) - 0.73) < 0.0001,
                "the editor's share is the pane that is not the leading one")

        // The same frames with the editor leading: the editor's
        // share is the first frame's.
        let editorLeads = EditorChatNSController.share(
            fromFrames: chatLeads, isVertical: true, firstPaneLeads: true)
        #expect(abs((editorLeads ?? 0) - 0.27) < 0.0001,
                "the editor's share is the leading frame's")
    }

    // MARK: - The re-assert (= what keeps the layout convergent)

    @Test("Source re-asserts the divider on every layout pass when a payload is stored (= the re-assert is what keeps the layout convergent)")
    func sourceReassertsEveryLayoutPass() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("} else if hasAutosave {"),
                "a stored payload must still be re-asserted on every layout pass (= without it the split's width oscillates and AppKit's runaway-layout guard aborts the app)")
        #expect(content.contains("applyStoredShare()"),
                "the stored share is the re-assert's value")
        #expect(content.contains("items[0].preferredThicknessFraction = leadingShare"),
                "AppKit's own layout must agree with the re-assert (= both items carry 0.5 otherwise, and the two fight every pass)")
        #expect(content.contains("splitView.setPosition(axis * leadingShare, ofDividerAt: 0)"),
                "the divider is asserted at the leading pane's share of the axis")
    }

    @Test("Source holds the share instead of re-reading it on every pass (= reading it back moves the target every pass)")
    func sourceHoldsTheShare() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("if assertedShare == nil {"),
                "the share is captured once (= the payload is written by AppKit as the layout settles, so reading it after asserting into it moves the target every pass)")
        #expect(content.contains("assertedShare = nil"),
                "the share is released when the arrangement changes (= the other arrangement has its own position)")
        #expect(content.contains("arrangement.isVertical ? splitView.bounds.width : splitView.bounds.height"),
                "the axis is the arrangement's own (= the width when side by side, the height when stacked)")
    }

    // MARK: - The panes' order (= the chat on the left, the editor on the right)

    @Test("Source puts the panes in the arrangement's own order (= the chat on the left, the editor on the right)")
    func sourcePaneOrder() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("applyPaneOrder(for: target)"),
                "entering an arrangement must put the panes in that arrangement's order")
        #expect(content.contains("let editorShouldLead = target == .stacked"),
                "the editor leads when the panes are stacked (= the editor on top) and the chat leads when they stand side by side (= the chat on the left)")
        #expect(content.contains("insertSplitViewItem(editorItem, at: editorShouldLead ? 0 : 1)"),
                "the editor's item is moved to the arrangement's own index")
        #expect(content.contains("removeSplitViewItem(editorItem)"),
                "an item cannot be moved without being removed first")
    }

    @Test("Source reads the stored frames in the arrangement's own order (= the frames follow the panes)")
    func sourceReadsFramesInOrder() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("firstPaneLeads: arrangement == .stacked"),
                "the frames are in the panes' own order (= the chat leads when the panes stand side by side), so the reader must be told which pane leads")
        #expect(content.contains("let leadingShare = editorLeads ? share : 1 - share"),
                "the assertion puts the divider at the LEADING pane's share (= the fraction AppKit lays out for)")
    }
}
