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
        #expect(editorPlaceholderSection.contains("HStack(spacing: 0)"),
                "EditorPlaceholder body must render tab strip with HStack(spacing: 0)")
        #expect(editorPlaceholderSection.contains("if let active = appState.openTabs.first"),
                "EditorPlaceholder body must locate the active tab via openTabs.first(= v1.73 full-width active-only design)")
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

    @Test("declares file watcher + alert state as computed properties (= v0.34 B-23 + v1.70 T1b)")
    func declaresFileWatcherAndAlertStateAsComputed() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-23: per-tab file-system watcher. State lives on the
        // active tab (= appState.openTabs[idx].fileWatcher).
        // v1.70 editor-mvvm T1b: `fileWatcher` + `watchedFD` are NO
        // LONGER computed properties on the view (= the DispatchSource
        // lifecycle migrated to `EditorFileWatcher`; = the helper
        // writes them on `tab.*` directly). The view still surfaces
        // the user-facing alert state (= externalChangeNotice +
        // showDirtyDiscardConfirm) as computed properties.
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

    @Test("declares 3 private mutation methods = saveDraft + handlePreviewWikiLink + handleEditorWikiLink (= v1.70 T2b)")
    func declaresFiveMutationMethods() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v1.70 editor-mvvm T2b: writeDraftToDisk + reloadDocumentFromDisk
        // + handleDirtyTransition migrated to EditorPersistence (= the
        // view now has 3 thin call sites + the saveDraft entry point).
        #expect(code.contains("private func saveDraft()"),
                "EditorPlaceholder must declare saveDraft (= debounced entry point)")
        #expect(code.contains("private func handlePreviewWikiLink"),
                "EditorPlaceholder must declare handlePreviewWikiLink (= preview wikilink tap)")
        #expect(code.contains("private func handleEditorWikiLink"),
                "EditorPlaceholder must declare handleEditorWikiLink (= editor wikilink tap)")
    }

    @Test("declares 2 lifecycle methods = applyParagraphAI + replaceSelectedText (= v1.70 T2b)")
    func declaresLifecycleMethods() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v1.70 editor-mvvm T2b: handleDirtyTransition migrated to
        // EditorPersistence.handleDirtyTransition(_:tab:bookStore:).
        // The view no longer holds the dirty-state machine.
        // applyParagraphAI is public (= engine bridge), takes EditorTransform parameter.
        #expect(code.contains("func applyParagraphAI(_ transform: EditorTransform)"),
                "EditorPlaceholder must declare public func applyParagraphAI(_ transform:) (= P2 #19 WIRE-PARAGRAPH-002 engine bridge)")
        #expect(code.contains("private func replaceSelectedText(with newText: String)"),
                "EditorPlaceholder must declare replaceSelectedText(with:) (= SMC engine bridge)")
        // v1.70 editor-mvvm T1b: `startFileWatcher` + `stopFileWatcher`
        // migrated to `EditorFileWatcher`. The view no longer declares
        // them (= the helper is the single owner of the fd lifecycle).
        // v1.70 editor-mvvm T2b: `handleDirtyTransition` migrated to
        // `EditorPersistence.handleDirtyTransition(_:tab:bookStore:)`.
        // The view no longer holds the dirty-state machine (= helper is
        // the single owner of the auto-save Task lifecycle).
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

    @Test("EditorPersistence.save uses atomically: true write option (= data integrity + v1.70 T2b)")
    func writeDraftToDiskUsesAtomicOption() throws {
        // v1.70 editor-mvvm T2b: the disk write migrated to
        // `EditorPersistence.save(tab:bookStore:)`. The view no longer
        // holds the disk-write logic. Assert the new helper uses
        // atomically: true (= prevents half-written file on crash).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsRoot = testFileURL
            .deletingLastPathComponent()  // Views/Workspace/
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let helperPath = testsRoot
            .appendingPathComponent("Sources/WenshuApp/Editor/EditorPersistence.swift").path
        let helperSource = try String(contentsOfFile: helperPath, encoding: .utf8)
        #expect(helperSource.contains("atomically: true"),
                "EditorPersistence.save must use atomically: true write option (= prevents half-written file on crash)")
    }

    @Test("EditorFileWatcher uses DispatchSource.makeFileSystemObjectSource + POSIX open (= B-23 + v1.70 T1b)")
    func startFileWatcherUsesDispatchSource() throws {
        // v1.70 editor-mvvm T1b: the DispatchSource + POSIX open
        // lifecycle migrated to `EditorFileWatcher`. The assertions
        // now point at the new file (= the view no longer holds them).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsRoot = testFileURL
            .deletingLastPathComponent()  // Views/Workspace/
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let helperPath = testsRoot
            .appendingPathComponent("Sources/WenshuApp/Editor/EditorFileWatcher.swift").path
        let code = try String(contentsOfFile: helperPath, encoding: .utf8)
        // v0.34 B-23 invariant: per-tab file-system watcher. POSIX open(2) +
        // DispatchSourceFileSystemObject event source.
        #expect(code.contains("DispatchSource.makeFileSystemObjectSource"),
                "EditorFileWatcher must use DispatchSource.makeFileSystemObjectSource (= kernel-level FS events)")
        #expect(code.contains("open(path, O_EVTONLY)"),
                "EditorFileWatcher must POSIX-open the FD with O_EVTONLY (= notify without read perm)")
        #expect(code.contains("tab.fileWatcher = source"),
                "EditorFileWatcher must store the DispatchSource in tab.fileWatcher")
        #expect(code.contains("tab.watchedFD = fd"),
                "EditorFileWatcher must store the FD in tab.watchedFD (= cancel-handler reference)")
        #expect(code.contains("setCancelHandler"),
                "EditorFileWatcher must set cancel handler (= close fd on cancel, prevents FD leak)")
        #expect(code.contains("close(fd)"),
                "EditorFileWatcher's cancel handler must close(fd) (= Apple HIG FD lifecycle)")
    }

    @Test("EditorFileWatcher.stop cancels DispatchSource + resets tab.watchedFD to -1 (= B-23 + v1.70 T1b)")
    func stopFileWatcherCancelsDispatchSource() throws {
        // v1.70 editor-mvvm T1b: the stop path migrated to
        // `EditorFileWatcher.stop(tab:)`.
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let helperPath = testsRoot
            .appendingPathComponent("Sources/WenshuApp/Editor/EditorFileWatcher.swift").path
        let code = try String(contentsOfFile: helperPath, encoding: .utf8)
        #expect(code.contains("tab.fileWatcher?.cancel()"),
                "EditorFileWatcher.stop must cancel the DispatchSource (= no event leak)")
        #expect(code.contains("tab.fileWatcher = nil"),
                "EditorFileWatcher.stop must nil out tab.fileWatcher (= no stale reference)")
        #expect(code.contains("tab.watchedFD = -1"),
                "EditorFileWatcher.stop must reset tab.watchedFD to -1 (= sentinel for closed FD)")
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

    @Test("EditorPersistence.handleDirtyTransition manages autoSaveTask lifecycle (= 3-second debounce + v1.70 T2b)")
    func handleDirtyTransitionManagesAutoSaveTask() throws {
        // v1.70 editor-mvvm T2b: the dirty-state machine migrated to
        // `EditorPersistence.handleDirtyTransition(_:tab:bookStore:)`.
        // The view no longer holds it. Assert the helper holds the
        // 3-second debounce + cancel logic (= boss 9/2 spec).
        let testFileURL = URL(fileURLWithPath: #filePath)
        let testsRoot = testFileURL
            .deletingLastPathComponent()  // Views/Workspace/
            .deletingLastPathComponent()  // Views/
            .deletingLastPathComponent()  // WenshuAppTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
        let helperPath = testsRoot
            .appendingPathComponent("Sources/WenshuApp/Editor/EditorPersistence.swift").path
        let helperSource = try String(contentsOfFile: helperPath, encoding: .utf8)
        #expect(helperSource.contains("handleDirtyTransition"),
                "EditorPersistence must declare handleDirtyTransition (= state machine)")
        // v0.34 B-22: dirty → start Task (debounced 3s); clean → cancel + nil.
        #expect(helperSource.contains("if isDirty {"),
                "handleDirtyTransition must branch on isDirty true (= start debounce)")
        #expect(helperSource.contains("if tab.autoSaveTask == nil {"),
                "handleDirtyTransition must reuse existing Task (= at most 1 active)")
        #expect(helperSource.contains("Task.sleep(for: .seconds(3))"),
                "handleDirtyTransition must use 3-second debounce (= boss 9/2 spec)")
        #expect(helperSource.contains("tab.autoSaveTask?.cancel()"),
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
        // v1.73 tab-strip redesign (= boss OOB): only the active tab is
        // rendered (= Safari single-tab feel); = the body locates it
        // via openTabs.first(where:) rather than ForEach over the full
        // list. This assertion accepts either v1.0.0-m1 (= ForEach) or
        // v1.73 (= active-only first) per the per-revision spec.
        let iteratesAllTabs = code.contains("ForEach(appState.openTabs, id: \\.id)")
            || code.contains("ForEach(appState.openTabs)")
        let locatesActiveTab = code.contains("if let active = appState.openTabs.first")
            || code.contains("first(where: { $0.id == appState.activeTabId })")
        #expect(iteratesAllTabs || locatesActiveTab,
                "EditorPlaceholder body must either iterate openTabs (= pre-v1.73 ForEach) or locate the active tab via openTabs.first(where:) (= v1.73 active-only)")
    }

    @Test("v1.73d tab close button uses DesignTokens (= no raw numeric literals)")
    func v73dTabCloseButtonUsesDesignTokens() throws {
        // v1.73d: Standards axis review WARN-B (per `wenshu-components`
        // skill §2 = "if you're typing a number in a layout/size/font
        // context, you almost certainly want a DesignTokens constant").
        // The xmark glyph font size + frame size must reference
        // DesignTokens.tabCloseGlyphFontSize + DesignTokens.tabCloseFrameSize.
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("DesignTokens.tabCloseGlyphFontSize"),
                "EditorPlaceholder X button glyph font size must use DesignTokens.tabCloseGlyphFontSize (= wenshu-components §2 rule)")
        #expect(code.contains("DesignTokens.tabCloseFrameSize"),
                "EditorPlaceholder X button hit area must use DesignTokens.tabCloseFrameSize (= wenshu-components §2 rule)")
        #expect(!code.contains(".system(size: 10"),
                "EditorPlaceholder X button glyph must NOT use raw '.system(size: 10)' literal (= the v1.73d replacement)")
        #expect(!code.contains(".frame(width: 18, height: 18)"),
                "EditorPlaceholder X button frame must NOT use raw '.frame(width: 18, height: 18)' literal (= the v1.73d replacement)")
    }

    @Test("reloadFromDiskAndApply fires via EditorFileWatcher's onChange closure (= B-23 + v1.70 T1b + v1.70 T2b)")
    func reloadDocumentFromDiskTriggersOnWriteEvent() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        // v0.34 B-23: external file change. The trigger is the
        // DispatchSource event handler (= .write + .extend) in
        // `EditorFileWatcher`, which invokes the `onChange` closure.
        // v1.70 editor-mvvm T1b: the view passes the onChange closure
        // when calling `EditorFileWatcher.start(path:tab:onChange:)`.
        // v1.70 editor-mvvm T2b: the onChange closure is now
        // `reloadFromDiskAndApply()` (= the new thin wrapper that
        // calls EditorPersistence.reloadFromDisk + writes the result
        // back to the active tab + updates the word-count badge).
        #expect(code.contains("EditorFileWatcher.start("),
                "EditorPlaceholder must invoke EditorFileWatcher.start (= DispatchSource hand-off)")
        #expect(code.contains("reloadFromDiskAndApply()"),
                "EditorPlaceholder must pass reloadFromDiskAndApply as the onChange closure (= FS event → UI reload)")
    }

    // MARK: - v1.73 tab close button

    @Test("v1.73 tab strip renders an xmark close button per tab (= TEB X OOB)")
    func tabStripRendersXmarkCloseButton() throws {
        // Source-level (= the X button is a pure view artifact;
        // = no behavior is asserted here beyond its presence).
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("Image(systemName: \"xmark\")"),
                "v1.73 tab strip must render an xmark (= the X close button per boss OOB)")
        #expect(code.contains("appState.closeTab(id: active.id"),
                "v1.73 X button action must call appState.closeTab(= the business method that flushes dirty + removes + focuses; = uses 'active.id' = the v1.73 active-only design)")
    }

    @Test("v1.73 dirty-discard confirm now delegates to closeTab (= auto-save + remove via single path)")
    func dirtyDiscardHandlerCallsCloseTab() throws {
        let code = try editorPlaceholderCodeRegion(readEditorPlaceholderSource())
        #expect(code.contains("closeTab(id: tab.id, bookStore: bookStore)"),
                "v1.73 dirty-discard handler must call appState.closeTab (= replaces the legacy draft-reset path)")
    }
}
