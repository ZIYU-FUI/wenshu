//
//  ChapterFocusLockDialogTests.swift · wenshu · chapter-dialog 2026-09-28 T1
//
//  the Allow/Deny dialog surface. When the LLM
//  tool call hits the chapter focus lock (= §11.23 ChapterFocusLockedError),
//  the conductor surfaces a dialog request to ChatZoneView instead
//  of auto-allowing (= §11.23 MVP). The boss picks Allow or Deny;
//  = the dialog's continuation resumes with the choice. This
//  ticket ships the dialog state holder + ChatZoneView alert host
//  + the source-content anchors that pin the canonical API.
//
//  Source-content anchors (= Q112 1 source + 1 test per commit):
//  the dialog lives in ChatZoneView (= it shares the existing
//  chat transcript surface); = the request struct lives in
//  ChapterFocusLockDialog.swift (= new file).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChapterFocusLockDialog (chapter-dialog 2026-09-28 T1)")
struct ChapterFocusLockDialogTests {

    @Test("ChapterFocusLockDialogRequest struct exposes canonical fields")
    func requestStructHasCanonicalFields() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChapterFocusLockDialog.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("struct ChapterFocusLockDialogRequest"))
        #expect(source.contains("let chapterPath:"))
        #expect(source.contains("let toolName:"))
        #expect(source.contains("let summary:"))
        #expect(source.contains("let continuation:"))
    }

    @Test("ChatZoneView hosts the dialog via .alert(item:) modifier")
    func chatZoneHostsAlert() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatZoneView.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains(".alert(") || source.contains(".alert(item:"),
                "ChatZoneView must host the dialog via .alert modifier")
        #expect(source.contains("ChapterFocusLockDialogPresenter"),
                "ChatZoneView must wire ChapterFocusLockDialogPresenter.shared.pendingRequest")
    }

    @Test("Dialog UI mentions Allow and Deny buttons (= matching hermes boss-decision UX)")
    func dialogMentionsAllowAndDeny() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChapterFocusLockDialog.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let hasAllow = source.contains("WenshuI18n.t(\"chatview.focus_lock.allow\")") ||
            source.contains("允许")
        let hasDeny = source.contains("WenshuI18n.t(\"chatview.focus_lock.deny\")") ||
            source.contains("拒绝")
        #expect(hasAllow, "dialog must render an Allow button")
        #expect(hasDeny, "dialog must render a Deny button")
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/\(relativeFromRepoRoot)"
        return path
    }
}