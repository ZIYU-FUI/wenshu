//
//  EditorOutOfScopeFollowupStubsTests.swift · Wenshu · v0.39 ticket 001 followup stubs
//
// 4 Swift Testing tests for the v0.39 ticket 001 out-of-scope followup stubs
// (per .scratch/2026-09-04-editor-migration/spec.md §2.2). Each test verifies
// the corresponding View type exists + instantiates + exposes a SwiftUI body
// that compiles (= stub compiles cleanly per AGENTS.md §11 hard rules).
//
// Per Q182.4: Swift Testing framework (= wenshu convention since v0.30+);
// @MainActor isolation because the stubs conform to `View` (= SwiftUI main-actor).
//
// Per boss 2026-09-05 OOB "推 2345678" item #2: ship 4 STUB implementations
// (full behavior is TODO pending boss拍; per spec.md §4.2 the future tickets
// are 002 LaTeX, 003 wiki-link creation, 004 drag-drop image).
//

import Testing
import SwiftUI
@testable import WenshuApp

@MainActor
@Suite("Editor out-of-scope followup stubs (v0.39 ticket 001)")
struct EditorOutOfScopeFollowupStubsTests {

    // MARK: - Stubs

    @Test("DragDropImageInsertion stub compiles + instantiates")
    func dragDropImageInsertionStub() {
        let view = DragDropImageInsertion()
        // Body type-erasure check: View body must produce a SwiftUI view.
        let _: any View = view.body
    }

    @Test("WikiLinkCreation stub compiles + instantiates")
    func wikiLinkCreationStub() {
        let view = WikiLinkCreation()
        let _: any View = view.body
    }

    @Test("LaTeXOptIn stub compiles + instantiates")
    func latexOptInStub() {
        let view = LaTeXOptIn()
        let _: any View = view.body
    }

    @Test("EditorOutlineBacklinksTabs stub compiles + instantiates")
    func editorOutlineBacklinksTabsStub() {
        let view = EditorOutlineBacklinksTabs()
        let _: any View = view.body
    }
}
