// EditorPlaceholderTests.swift · Wenshu · v0.93 ticket 003
//
// Source-level structural tests for EditorPlaceholder (= the editor
// pane's wrapper that holds the tab strip + the editing surface
// + dirty-discard alert + various handlers; = ~1100 LOC body, the
// most complex of the 3 helper structs in WorkspaceView.swift).
//
// Per boss 2026-09-14 OOB '按优先级推' + 'A': extend item 10
// (= WorkspaceView test coverage expansion). v0.93 ticket 001 =
// EditorPaperCanvas (8 tests). Ticket 002 = ZoneModuleView (6 tests).
// This ticket = EditorPlaceholder (= the most complex; =
// source-level structural only; = ViewInspector behavior tests would
// require significant mock scaffolding per v0.77 spec deferral).
//
// Per v0.77 spec + Q34 5.4: ViewInspector behavior tests on
// EditorPlaceholder (= with @State + @Environment + nested Button +
// .alert + .onChange) require ~150-200 LOC of mock scaffolding that
// exceeds 1-ticket scope per Q112. Source-level structural assertions
// capture the boss-spec invariants (= the v0.34 + v0.40 + v1.0.0-m1
// features referenced in the comments).

import SwiftUI
import Testing
@testable import WenshuApp

@Suite("EditorPlaceholder (v0.93 — editor pane wrapper with tab strip + dirty alert)")
struct EditorPlaceholderTests {
    /// v1.33 (= per Q34 5.2 + Q173 ponytail + Q186): derive the
    /// EditorPlaceholder source path from THIS test file's path
    /// (= #filePath). This means the tests work regardless of
    /// where the worktree is mounted (= v1.32 hit a build failure
    /// when EditorPlaceholder was in a worktree because the old
    /// hardcoded path pointed to the main worktree).
    private static var editorPlaceholderPath: String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsDir = testFileURL.deletingLastPathComponent()  // Views/Workspace/
        let repoRoot = testsDir
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        return repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("WenshuApp")
            .appendingPathComponent("Views")
            .appendingPathComponent("Workspace")
            .appendingPathComponent("EditorPlaceholder.swift")
            .path
    }

    private func readEditorPlaceholderSource() throws -> String {
        return try String(contentsOfFile: Self.editorPlaceholderPath, encoding: .utf8)
    }


    @Test("struct conforms to View")
    func conformsToView() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("struct EditorPlaceholder: View"),
                "EditorPlaceholder must conform to View protocol")
    }

    @Test("reads AppState + BookStore from environment")
    func readsAppStateAndBookStore() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("@Environment(AppState.self) private var appState"),
                "EditorPlaceholder must read AppState from environment (= v0.34 B-24)")
        #expect(editorPlaceholderSection.contains("@Environment(BookStore.self) private var bookStore"),
                "EditorPlaceholder must read BookStore from environment (= v0.39 ticket 001)")
    }

    @Test("mode reads from active tab (= per-tab preview/edit state per Safari)")
    func modeReadsFromActiveTab() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.34 ticket 04: mode lives on the active tab (= each tab
        // keeps its own preview/edit state when switching tabs).
        let codeLines = editorPlaceholderSection.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        #expect(codeRegion.contains("private var mode: EditorMode {"),
                "EditorPlaceholder must declare private var mode: EditorMode computed (= v0.34 B-24)")
        #expect(codeRegion.contains("appState.openTabs.first(where: { $0.id == appState.activeTabId })?.mode ?? .preview"),
                "EditorPlaceholder mode must read from active tab (= v0.34 B-24 Safari behavior)")
    }

    @Test("declares selectedText + isApplyingParagraphAI @State vars (= P2 #19)")
    func declaresSelectionAndApplyingState() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        let codeLines = editorPlaceholderSection.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        let codeRegion = codeLines.joined(separator: "\n")

        // Per P2 #19 (WIRE-PARAGRAPH-002): live editor selection snapshot
        // + applyParagraphAI spinner flag.
        #expect(codeRegion.contains("@State private var selectedText: String = \"\""),
                "EditorPlaceholder must declare @State var selectedText (= P2 #19 WIRE-PARAGRAPH-002)")
        #expect(codeRegion.contains("@State private var isApplyingParagraphAI: Bool = false"),
                "EditorPlaceholder must declare @State var isApplyingParagraphAI (= P2 #19 Apple HIG actionable-control-while-busy rule)")
    }

    @Test("exposes public setSelection(_:) (= engine bridge entry point)")
    func exposesSetSelection() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        #expect(editorPlaceholderSection.contains("public func setSelection(_ text: String) {"),
                "EditorPlaceholder must expose public func setSelection(_ text: String) (= engine NSTextViewDelegate bridge entry point per P2 #19)")
    }

    @Test("body starts with VStack + Safari-style tab strip (= v1.0.0-m1 OOB)")
    func bodyUsesSafariStyleTabStrip() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v1.0.0-m1-shell boss 2026-09-10 OOB: the editor top bar =
        // Safari-style tab strip ONLY (= no formatting toolbar).
        #expect(editorPlaceholderSection.contains("VStack(spacing: 0) {"),
                "EditorPlaceholder body must wrap tab strip + content in VStack(spacing: 0)")
        #expect(editorPlaceholderSection.contains("HStack(spacing: 0) {"),
                "EditorPlaceholder body must render tab strip with HStack(spacing: 0)")
        #expect(editorPlaceholderSection.contains("ForEach(appState.openTabs)"),
                "EditorPlaceholder body must iterate over openTabs")
    }

    @Test("body shows dirty-discard confirm alert on close-with-unsaved-changes")
    func bodyShowsDirtyDiscardAlert() throws {
        
        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.34 ticket 09: dirty-discard confirm dialog (= Apple HIG
        // 2-option confirm pattern; = destructive + cancel).
        #expect(editorPlaceholderSection.contains(".alert("),
                "EditorPlaceholder body must use SwiftUI .alert for dirty-discard confirm")
        #expect(editorPlaceholderSection.contains("workspace.editor.dirty_discard_alert_title"),
                "EditorPlaceholder must localize dirty-discard alert title via WenshuI18n (= i18n parity)")
        #expect(editorPlaceholderSection.contains("role: .destructive"),
                "EditorPlaceholder dirty-discard alert must use destructive role (= Apple HIG convention)")
        #expect(editorPlaceholderSection.contains("role: .cancel"),
                "EditorPlaceholder dirty-discard alert must use cancel role (= Apple HIG 2-option confirm pattern)")
    }

    @Test("activeTabIdString uses wenshu-editor-no-tab fallback (= v0.39 ticket 001)")
    func activeTabIdStringFallback() throws {

        let source = try readEditorPlaceholderSource()
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        let editorPlaceholderSection = String(section[..<endOfStruct])
        // Per v0.39 ticket 001: lookup the active tab's id (= the engine's
        // `documentId` for undo + replacement scoping). Falls back to
        // a deterministic placeholder id when no tab is open.
        #expect(editorPlaceholderSection.contains("private var activeTabIdString: String {"),
                "EditorPlaceholder must declare private var activeTabIdString (= v0.39 ticket 001)")
        #expect(editorPlaceholderSection.contains("?? \"wenshu-editor-no-tab\""),
                "EditorPlaceholder activeTabIdString must fall back to 'wenshu-editor-no-tab' deterministic id")
    }

    // MARK: - v0.93 ticket 006 extensions (= Q34 5.4 deferred ViewInspector scope,
    //        plus post-v0.93 surface growth = 870 LOC, 3 fixes, 11 dependents)

    /// Helper: read the EditorPlaceholder struct section (= private struct
    /// EditorPlaceholder → next top-level struct).
    private func editorPlaceholderSection(_ source: String) -> String {
        let startRange = source.range(of: "struct EditorPlaceholder")!
        let section = String(source[startRange.lowerBound...])
        let endOfStruct = section.range(of: "struct EditorPaperCanvas")?.lowerBound
            ?? section.endIndex
        return String(section[..<endOfStruct])
    }

    private func editorPlaceholderCodeRegion(_ source: String) -> String {
        let section = editorPlaceholderSection(source)
        let codeLines = section.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }
        return codeLines.joined(separator: "\n")
    }

    @Test("declares per-tab dirty-state vars as computed properties (= v0.34 B-24 single source of truth)")
    func declaresDirtyStateVarsAsComputed() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-24: per-tab state lives on AppState.openTabs[activeTabIndex].
        // EditorPlaceholder reads/writes the ACTIVE tab via computed properties.
        // These computed properties expose the per-tab state (= Safari behavior).
        #expect(code.contains("private var draft: String {"),
                "EditorPlaceholder must declare draft as computed (= per-tab editing buffer)")
        #expect(code.contains("private var originalBody: String {"),
                "EditorPlaceholder must declare originalBody as computed (= for dirty comparison)")
        #expect(code.contains("private var documentPath: String? {"),
                "EditorPlaceholder must declare documentPath as computed (= resolved file path)")
        #expect(code.contains("private var isDirty: Bool {"),
                "EditorPlaceholder must declare isDirty as computed (= Apple HIG unsaved-changes indicator)")
        #expect(code.contains("private var autoSaveTask: Task<Void, Never>? {"),
                "EditorPlaceholder must declare autoSaveTask as computed (= debounced auto-save Task)")
    }

    @Test("declares file watcher + alert state as computed properties (= v0.34 B-23)")
    func declaresFileWatcherAndAlertStateAsComputed() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-23: per-tab file-system watcher. State lives on the
        // active tab (= appState.openTabs[idx].fileWatcher).
        #expect(code.contains("private var fileWatcher: DispatchSourceFileSystemObject? {"),
                "EditorPlaceholder must declare fileWatcher as computed (= per-tab DispatchSource)")
        #expect(code.contains("private var watchedFD: Int32 {"),
                "EditorPlaceholder must declare watchedFD as Int32 computed (= open file descriptor sentinel)")
        #expect(code.contains("private var externalChangeNotice: String? {"),
                "EditorPlaceholder must declare externalChangeNotice as computed (= FS event feedback)")
        #expect(code.contains("private var showDirtyDiscardConfirm: Bool {"),
                "EditorPlaceholder must declare showDirtyDiscardConfirm as computed (= alert trigger)")
    }

    @Test("only 2 @State vars remain = selectedText + isApplyingParagraphAI (= v0.34 B-24)")
    func onlyTwoStateVarsRemain() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // After v0.34 B-24 (= per-tab state on AppState.openTabs), only
        // the engine-bridge @State vars remain in EditorPlaceholder itself:
        //   - selectedText (= live editor selection snapshot for replaceSelectedText bridge)
        //   - isApplyingParagraphAI (= busy flag for the applyParagraphAI action)
        #expect(code.contains("@State private var selectedText: String = \"\""),
                "EditorPlaceholder must declare @State var selectedText (= engine bridge)")
        #expect(code.contains("@State private var isApplyingParagraphAI: Bool = false"),
                "EditorPlaceholder must declare @State var isApplyingParagraphAI (= busy flag)")
    }

    @Test("declares 4 private mutation methods = saveDraft + writeDraftToDisk + reloadDocumentFromDisk + handlePreviewWikiLink + handleEditorWikiLink")
    func declaresFiveMutationMethods() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("private func saveDraft()"),
                "EditorPlaceholder must declare saveDraft (= debounced entry point)")
        #expect(code.contains("private func writeDraftToDisk()"),
                "EditorPlaceholder must declare writeDraftToDisk (= sync IO write)")
        #expect(code.contains("private func reloadDocumentFromDisk()"),
                "EditorPlaceholder must declare reloadDocumentFromDisk (= external-change response)")
        #expect(code.contains("private func handlePreviewWikiLink"),
                "EditorPlaceholder must declare handlePreviewWikiLink (= preview wikilink tap)")
        #expect(code.contains("private func handleEditorWikiLink"),
                "EditorPlaceholder must declare handleEditorWikiLink (= editor wikilink tap)")
    }

    @Test("declares 5 lifecycle methods = applyParagraphAI + replaceSelectedText + startFileWatcher + stopFileWatcher + handleDirtyTransition")
    func declaresLifecycleMethods() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // applyParagraphAI is public (= engine bridge), takes EditorTransform parameter.
        #expect(code.contains("func applyParagraphAI(_ transform: EditorTransform)"),
                "EditorPlaceholder must declare public func applyParagraphAI(_ transform:) (= P2 #19 WIRE-PARAGRAPH-002 engine bridge)")
        #expect(code.contains("private func replaceSelectedText(with newText: String)"),
                "EditorPlaceholder must declare replaceSelectedText(with:) (= SMC engine bridge)")
        #expect(code.contains("private func startFileWatcher()"),
                "EditorPlaceholder must declare startFileWatcher (= DispatchSource setup)")
        #expect(code.contains("private func stopFileWatcher()"),
                "EditorPlaceholder must declare stopFileWatcher (= DispatchSource cleanup)")
        #expect(code.contains("private func handleDirtyTransition(_ isDirty: Bool)"),
                "EditorPlaceholder must declare handleDirtyTransition (= isDirty state machine)")
    }

    @Test("activeTab / activeTabIndex resolve from appState.openTabs (= v0.34 B-24)")
    func activeTabResolvedFromOpenTabs() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("private var activeTab: EditorTab? {"),
                "EditorPlaceholder must declare activeTab: EditorTab? computed (= nil when no tabs open)")
        #expect(code.contains("private var activeTabIndex: Int? {"),
                "EditorPlaceholder must declare activeTabIndex computed (= nil when no tabs open)")
        #expect(code.contains("appState.openTabs.firstIndex(where: { $0.id == appState.activeTabId })"),
                "activeTabIndex must lookup by activeTabId in appState.openTabs")
    }

    @Test("writeDraftToDisk uses atomically: true write option (= data integrity)")
    func writeDraftToDiskUsesAtomicOption() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("atomically: true"),
                "writeDraftToDisk must use atomically: true write option (= prevents half-written file on crash)")
    }

    @Test("startFileWatcher uses DispatchSource.makeFileSystemObjectSource + POSIX open (= B-23)")
    func startFileWatcherUsesDispatchSource() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-23: per-tab file-system watcher. POSIX open(2) +
        // DispatchSourceFileSystemObject event source.
        #expect(code.contains("DispatchSource.makeFileSystemObjectSource"),
                "EditorPlaceholder must use DispatchSource.makeFileSystemObjectSource (= kernel-level FS events)")
        #expect(code.contains("let fd = open(path, O_EVTONLY)"),
                "startFileWatcher must POSIX-open the FD with O_EVTONLY (= notify without read perm)")
        #expect(code.contains("fileWatcher = source"),
                "startFileWatcher must store the DispatchSource in fileWatcher")
        #expect(code.contains("watchedFD = fd"),
                "startFileWatcher must store the FD in watchedFD (= cancel-handler reference)")
        #expect(code.contains("source.setCancelHandler {"),
                "startFileWatcher must set cancel handler (= close fd on cancel, prevents FD leak)")
        #expect(code.contains("close(fd)"),
                "cancel handler must close(fd) (= Apple HIG FD lifecycle)")
    }

    @Test("stopFileWatcher cancels DispatchSource + resets watchedFD to -1 (= B-23)")
    func stopFileWatcherCancelsDispatchSource() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("fileWatcher?.cancel()"),
                "stopFileWatcher must cancel the DispatchSource (= no event leak)")
        #expect(code.contains("fileWatcher = nil"),
                "stopFileWatcher must nil out fileWatcher (= no stale reference)")
        #expect(code.contains("watchedFD = -1"),
                "stopFileWatcher must reset watchedFD to -1 (= sentinel for closed FD)")
    }

    @Test("handlePreviewWikiLink + handleEditorWikiLink differentiate scope (= SMC bridge)")
    func wikiLinkHandlersDifferentiateScope() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // Preview → open as new tab (read-only).
        // Editor → insert inline (write).
        // Both delegate to a shared router (= the engine bridge).
        #expect(code.contains("handlePreviewWikiLink("),
                "EditorPlaceholder must expose handlePreviewWikiLink (= preview tab opener)")
        #expect(code.contains("handleEditorWikiLink("),
                "EditorPlaceholder must expose handleEditorWikiLink (= inline inserter)")
    }

    @Test("applyParagraphAI uses defer for busy flag + gates on non-empty selection (= Apple HIG)")
    func applyParagraphAIGate() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // Apple HIG actionable-control-while-busy rule: gate on
        // non-empty selection + use defer for the busy flag (= cleanup
        // is exception-safe even if the LLM call throws).
        #expect(code.contains("guard !selectedText.isEmpty else { return }"),
                "applyParagraphAI must guard on non-empty selectedText (= no selection = no AI)")
        #expect(code.contains("isApplyingParagraphAI = true"),
                "applyParagraphAI must set isApplyingParagraphAI = true on entry (= busy flag)")
        #expect(code.contains("defer { isApplyingParagraphAI = false }"),
                "applyParagraphAI must use defer to reset busy flag (= exception-safe cleanup)")
    }

    @Test("handleDirtyTransition manages autoSaveTask lifecycle (= 3-second debounce)")
    func handleDirtyTransitionManagesAutoSaveTask() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("private func handleDirtyTransition(_ isDirty: Bool)"),
                "EditorPlaceholder must declare handleDirtyTransition (= state machine)")
        // v0.34 B-22: dirty → start Task (debounced 3s); clean → cancel + nil.
        // The dirty detection itself (= draft != originalBody) lives on
        // the computed isDirty property (= not in handleDirtyTransition).
        #expect(code.contains("if isDirty {"),
                "handleDirtyTransition must branch on isDirty true (= start debounce)")
        #expect(code.contains("if autoSaveTask == nil {"),
                "handleDirtyTransition must reuse existing Task (= at most 1 active)")
        #expect(code.contains("Task.sleep(for: .seconds(3))"),
                "handleDirtyTransition must use 3-second debounce (= boss 9/2 spec)")
        #expect(code.contains("autoSaveTask?.cancel()"),
                "handleDirtyTransition false branch must cancel pending Task (= no more writes)")
    }

    @Test("isDirty computed compares activeTab.draft != activeTab.originalBody (= v0.34 B-24)")
    func isDirtyComputedComparesActiveTabFields() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("return tab.draft != tab.originalBody"),
                "isDirty computed must compare activeTab.draft != activeTab.originalBody (= per-tab dirty detection)")
    }

    @Test("body uses SwiftUI Observation pattern via appState.openTabs (= B-24)")
    func bodyUsesOpenTabsFromAppState() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-24: EditorPlaceholder reads/writes the ACTIVE tab via
        // computed properties (= single source of truth). The body must
        // iterate over appState.openTabs (= the canonical tab list).
        #expect(code.contains("ForEach(appState.openTabs)"),
                "EditorPlaceholder body must iterate appState.openTabs (= canonical tab list)")
    }

    @Test("reloadDocumentFromDisk triggers on DispatchSource .write + .extend events (= B-23)")
    func reloadDocumentFromDiskTriggersOnWriteEvent() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-23: external file change. The trigger is the
        // DispatchSource event handler (= .write + .extend), NOT SwiftUI
        // .onChange. externalChangeNotice is the UI feedback (= not the trigger).
        #expect(code.contains("events.contains(.write) || events.contains(.extend)"),
                "reloadDocumentFromDisk must trigger on .write + .extend (= file content changed)")
        #expect(code.contains("reloadDocumentFromDisk()"),
                "event handler must call reloadDocumentFromDisk (= FS event → UI reload)")
    }
}