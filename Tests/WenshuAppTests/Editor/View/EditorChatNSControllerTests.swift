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

    @Test("The width rule: side by side only when BOTH panes can hold their own chrome, and every width resolves")
    func widthRule() throws {
        // The three measured numbers.
        //
        // 595 PT = the editor's own comfortable prose measure (the
        // paper-canvas notes: 595-680 PT). It is ABOVE the editor's
        // chrome width (448 PT = the format toolbar's 12 buttons of
        // 28 PT, the trailing close button, the chunk separators, the
        // spacing and ChromeTopBar's padding), so a pane the rule
        // accepts always holds its chrome.
        //
        // 280 PT = the chat's floor, measured 2026-10-26 from a
        // running capture (the chat column was 282 PT and read well).
        //
        // 1190 PT = an EVEN split of the available width that gives
        // both panes their floor (= 2 x 595; the editor's floor binds).
        #expect(EditorChatNSController.editorPaneMinimumWidth == 595)
        #expect(EditorChatNSController.chatPaneMinimumWidth == 280)
        #expect(EditorChatNSController.sideBySideMinimumWidth == 1190)

        // Side by side when an even split of the available width
        // gives both panes their floor.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1190, editorShare: 0.5, mode: .automatic) == .sideBySide)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1600, editorShare: 0.5, mode: .automatic) == .sideBySide)

        // Stacked when the width cannot hold two columns: the
        // screenshot's own width (= 742 PT: the editor+chat region
        // measured 855..2338 px at 2x) hands each column 371 PT,
        // which is below the editor's own floor.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 742, editorShare: 0.5, mode: .automatic) == .stacked)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1189, editorShare: 0.5, mode: .automatic) == .stacked)

        // The OLD band (920..1000 PT) kept the current arrangement.
        // A band that keeps the current value is a band that never
        // resolves: the window could be dragged narrower and
        // narrower and the arrangement stayed whatever it had been.
        // Every width now resolves to a DEFINITE arrangement.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 950, editorShare: 0.5, mode: .automatic) == .stacked)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1000, editorShare: 0.5, mode: .automatic) == .stacked)

        // The decision does NOT depend on the incoming arrangement
        // any more (= the band is gone). The rule takes no `current`
        // at all, so the only way to pin that is to show the answer
        // is a function of the width and the share ALONE: the same
        // width and the same share must give the same arrangement
        // for every arrangement the split could be in. The old band
        // (920..1000 PT) is the case that breaks this: there the
        // answer depended on the incoming arrangement, so the same
        // width gave a different answer depending on where it came
        // from.
        //
        // The widths below are the ones the OLD band covered, plus
        // the widths on either side of it. Each is asserted against
        // the arrangement the chrome arithmetic gives, and the
        // arithmetic is spelled out in the comment: at an even split
        // the editor needs 595 PT and the chat 280 PT, so the width
        // must be at least 1190 PT (= 2 x 595) for both to fit.
        //
        // 950 PT: an even split gives each 475 PT, which is under
        // the editor's 595 PT floor => stacked. The OLD rule said
        // "keep the current arrangement" here, so a 950 PT window
        // kept whatever it had been.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 950, editorShare: 0.5, mode: .automatic) == .stacked)
        // 1000 PT: an even split gives each 500 PT, still under the
        // editor's floor => stacked. The OLD rule said "keep the
        // current arrangement" here too (= the band was 920..1000).
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1000, editorShare: 0.5, mode: .automatic) == .stacked)
        // Just below the even-split width: 1189 PT gives each
        // 594.5 PT, one half-point under the editor's 595 PT floor.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1189, editorShare: 0.5, mode: .automatic) == .stacked)
        // At it: 1190 PT gives each 595 PT => both floors met.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1190, editorShare: 0.5, mode: .automatic) == .sideBySide)

        // The rule takes no `current` parameter at all (= the band
        // is gone by construction, not by a branch that happens to
        // be unreachable). This is a source-level assertion because
        // it is a property of the SIGNATURE: a pure call cannot
        // depend on an argument it was never given.
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let ruleBody = try #require(
            Self.functionBody(named: "arrangement", in: content),
            "the width rule must exist")
        #expect(!ruleBody.contains("current"),
                "the width rule must not take the incoming arrangement (= a rule that keeps the current arrangement is a rule that never resolves)")
        #expect(!content.contains("return current"),
                "no branch of the width rule may keep the current arrangement (= that was the band)")

        // The two manual cases win over the width rule, at every
        // width (= a manual choice still wins, and it survives a
        // relaunch).
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1600, editorShare: 0.5, mode: .stacked) == .stacked)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 742, editorShare: 0.5, mode: .stacked) == .stacked)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1600, editorShare: 0.5, mode: .sideBySide) == .sideBySide)
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 742, editorShare: 0.5, mode: .sideBySide) == .sideBySide)
    }

    @Test("The rule judges the share the LAYOUT asserts (= a stored share that cannot host the chrome must not end up side by side with that share)")
    func ruleJudgesTheAssertedShare() {
        // The defect this pins: the rule used to substitute an even
        // 0.5 for a stored share that could not host the chrome, so
        // the rule chose side by side on the strength of a 595 PT
        // editor pane, while the layout went on asserting the
        // STORED share (= 0.30) and gave the editor 357 PT at a
        // 1190 PT width (= 238 PT under the floor the rule itself
        // declares). The chrome was clipped, which is the card's own
        // bug class.
        //
        // The rule now judges the share the layout asserts, so the
        // two cannot disagree inside one layout pass.
        // 1190 PT at an even split: both panes meet their floors.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1190, editorShare: 0.5, mode: .automatic) == .sideBySide)
        // The SAME width with the user's own 0.30 share: the editor
        // gets 357 PT, which cannot hold its chrome, so side by side
        // is NOT viable at that share and the rule resolves to
        // stacked. This is the case the substitution broke.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1190, editorShare: 0.30, mode: .automatic) == .stacked)
        // 1400 PT with the same 0.30 share: the editor gets 420 PT,
        // still under its 595 PT floor => stacked.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1400, editorShare: 0.30, mode: .automatic) == .stacked)
        // The share that WOULD be viable: at 1400 PT the editor
        // needs 0.425 of the width to reach 595 PT.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: 1400, editorShare: 0.5, mode: .automatic) == .sideBySide)
        #expect(!EditorChatNSController.holdsChrome(width: 1400, editorShare: 0.30),
                "0.30 of 1400 PT gives the editor 420 PT, which cannot hold its own chrome")
        #expect(EditorChatNSController.holdsChrome(width: 1400, editorShare: 0.5),
                "an even split of 1400 PT gives the editor 700 PT (= its prose measure) and the chat 700 PT (= above its 280 PT floor)")
    }

    @Test("The stacked chrome test is the FULL width (= the stored share is a HEIGHT share and cannot clip a horizontal chrome)")
    func stackedChromeTest() {
        // Stacked, the divider runs ACROSS the split: the height
        // carries the arrangement and each pane is as wide as the
        // whole split. So the chrome test is the width itself.
        //
        // The editor's chrome is 448 PT (the format toolbar's 12
        // buttons of 28 PT, the trailing close button, the two
        // chunk separators, the intra-/inter-chunk spacing and
        // ChromeTopBar's horizontal padding) and the chat's is
        // 254 PT (the composer's 5 buttons of 36 PT, 5 gaps of
        // 10 PT and the 12 PT horizontal padding).
        #expect(EditorChatNSController.editorChromeMinimumWidth == 448)
        #expect(EditorChatNSController.chatChromeMinimumWidth == 254)

        // The screenshot's own width (= 742 PT) and the detail
        // column with the inspector counted (= 1012 PT) both hold
        // both panes' chrome when stacked.
        #expect(EditorChatNSController.holdsStackedChrome(width: 742))
        #expect(EditorChatNSController.holdsStackedChrome(width: 1012))
        // Below the editor's chrome width, stacked cannot host the
        // chrome either.
        #expect(!EditorChatNSController.holdsStackedChrome(width: 447))
        #expect(!EditorChatNSController.holdsStackedChrome(width: 253))

        // The bug this pins: the stacked case used to feed a HEIGHT
        // share into the WIDTH-share test, which asked whether
        // `width x heightShare` held the chrome. At 742 PT that is
        // false for EVERY share (it needs h >= 0.802 for the editor
        // and h <= 0.623 for the chat at the same time), so the
        // 50:50 reset was owed on every entry into stacked and an
        // extra setPosition write landed in the layout pass.
        #expect(EditorChatNSController.holdsStackedChrome(width: 742),
                "the stacked chrome test is the full width, so it does not depend on the height share at all")
    }

    @Test("The chrome test: a pane's negotiated thickness must hold that pane's own chrome")
    func chromeTest() {
        // The share is the divider's position (= the editor's share
        // of the available width), and the panes' negotiated
        // thicknesses are the width times the shares.
        //
        // 1209 PT with the editor on half: the editor gets 604 PT
        // (= its prose measure) and the chat 605 PT (= above its
        // 280 PT floor). Viable.
        #expect(EditorChatNSController.holdsChrome(width: 1209, editorShare: 0.5))
        // The same width with the editor on a tenth: the editor gets
        // 120 PT, which cannot hold its chrome, so the arrangement is
        // NOT viable however wide the split is.
        #expect(!EditorChatNSController.holdsChrome(width: 1209, editorShare: 0.1))
        // The screenshot's own case: 742 PT at half = 371 PT each,
        // which is below the editor's 595 PT floor.
        #expect(!EditorChatNSController.holdsChrome(width: 742, editorShare: 0.5))
        // The chat's own floor binds when the editor is given nearly
        // everything: 1000 PT with the editor on 0.75 leaves the chat
        // 250 PT, which is below its 280 PT floor.
        #expect(!EditorChatNSController.holdsChrome(width: 1000, editorShare: 0.75))
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

    // MARK: - The divider's position (= what keeps the layout convergent)

    @Test("Source positions the divider at the leading pane's share of the axis (= the position AppKit's own layout must agree with)")
    func sourcePositionsTheDividerAtTheLeadingShare() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
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
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        let body = try #require(Self.functionBody(named: "applyStoredShare", in: content),
                                "applyStoredShare must exist")
        let writes = body.components(separatedBy: "splitView.setPosition(").count - 1
        #expect(writes == 1,
                "the divider is written on exactly one path (= the decision function's outcome), not unconditionally on every layout pass")
        #expect(content.contains("case .assertAt(let share):"),
                "the write happens on the decision's outcome (= the seed, or a repair after a resize left the share off)")
        #expect(content.contains("case .adopt(let share):"),
                "a user drag is adopted (= the assert must never write over it, = the drag is eaten otherwise)")
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
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("private var dividerLatch = DividerLatch()"),
                "the controller owns one latch (= the state that spans layout passes)")
        #expect(content.contains("dividerLatch.pass("),
                "the layout's caller must drive the latch (= the latch's lifecycle is the defect's home)")
        #expect(content.contains("dividerLatch.reset()"),
                "an arrangement change resets the latch (= the divider is positioned again on the new axis)")
    }

    @Test("Source: the thickness cap is written in quanta (= a write per frame re-arms the window's update-constraints pass)")
    func sourceWritesTheThicknessCapInQuanta() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
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

    @Test("Source: the layout callback does NOT reach the arrangement's structural change (= the change is deferred to the next runloop turn)")
    func sourceStructuralChangeIsNotReachableFromLayoutCallback() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

        // Name the method that does the structural change, and prove
        // it IS the structural change (= it moves an item).
        let structuralBody = try #require(
            Self.functionBody(named: "applyPaneOrder", in: content),
            "applyPaneOrder must exist (= the method that does the structural change)")
        #expect(structuralBody.contains("removeSplitViewItem(editorItem)"),
                "applyPaneOrder removes the editor's item (= the structural change)")
        #expect(structuralBody.contains("insertSplitViewItem(editorItem, at: editorShouldLead ? 0 : 1)"),
                "applyPaneOrder re-inserts the editor's item (= the structural change)")

        // The layout callback must not call it, and must not call
        // the method that calls it either.
        let layoutBody = try #require(
            Self.functionBody(named: "viewDidLayout", in: content),
            "viewDidLayout must exist")
        #expect(!layoutBody.contains("applyPaneOrder"),
                "viewDidLayout must not move a split view item (= removing one invalidates the split's constraints while AppKit is laying out, and each invalidation re-arms the window's update-constraints pass)")
        #expect(!layoutBody.contains("transition(to:"),
                "viewDidLayout must not run the arrangement change (= it reaches the split's structure)")

        // The width rule only REQUESTS the arrangement, and the
        // request is deferred.
        let ruleBody = try #require(
            Self.functionBody(named: "applyAutomaticArrangement", in: content),
            "applyAutomaticArrangement must exist")
        #expect(ruleBody.contains("requestArrangement("),
                "the width rule requests the arrangement (= it does not move the panes itself)")
        #expect(!ruleBody.contains("transition(to:"),
                "the width rule must not move the panes itself")

        let requestBody = try #require(
            Self.functionBody(named: "requestArrangement", in: content),
            "requestArrangement must exist")
        #expect(requestBody.contains("Task { @MainActor"),
                "the structural change is deferred to the next runloop turn (= the layout pass finishes before the panes move)")
    }

    @Test("Source: the thickness bounds and the preferred fractions are written only when the value differs")
    func sourceWritesOnlyWhenTheValueDiffers() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

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
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift")
        let content = try String(contentsOf: url, encoding: .utf8)

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

    @Test("The width rule reads a real allocation: the degenerate passes do not make every width viable")
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

        // And the rule, fed that allocation, resolves.
        #expect(EditorChatNSController.arrangement(forCompetingWidth: recorded ?? 0, editorShare: 0.5, mode: .automatic) == .stacked,
                "the screenshot's own width (= 740 PT) cannot hold two columns, so it resolves to stacked (= the chrome is never hidden to make room)")
    }
}
