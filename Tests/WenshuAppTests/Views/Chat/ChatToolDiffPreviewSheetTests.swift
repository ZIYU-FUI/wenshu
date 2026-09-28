//
//  ChatToolDiffPreviewSheetTests.swift · wenshu · chat-diff-sheet 2026-09-28 T6
//
//  RED tests for the long-diff sheet. Phase 3 of chat-diff-preview arc
//  (future ticket 3 per §11.20). Mirrors KanbanTicketDetailSheet
//  (= Apple HIG `.sheet(item:)` + `NavigationStack` + scrollable
//  content + toolbar Close). The sheet hosts the same diff rendering
//  (= ChatToolDiffPreview) so the user's visual model is consistent
//  across inline + expanded states.
//
//  Pure layout/API tests; = no SwiftUI render host needed.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolDiffPreviewSheet (chat-diff-sheet 2026-09-28 T6)")
struct ChatToolDiffPreviewSheetTests {

    @Test("sheet exposes the canonical init (diff + filename)")
    func canonicalInit() throws {
        // Source-content anchor (= Q112 1 source + 1 test = the
        // sheet's surface lives in a single file). Verifies the
        // canonical API matches `KanbanTicketDetailSheet`'s shape.
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("struct ChatToolDiffPreviewSheet"))
        #expect(source.contains("let diff:"))
        #expect(source.contains("let filename:"))
        // Apple HIG navigation toolbar Close button.
        #expect(source.contains("NavigationStack"))
    }

    @Test("sheet reuses the canonical diff helpers from ChatToolDiffPreview")
    func reusesCanonicalHelpers() throws {
        // The sheet's body should call into ChatToolDiffPreview's
        // helpers (= countLineStats + present + color) so the
        // expanded view shows the same +N/-N char header and
        // red/green line coloring as the inline preview.
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("ChatToolDiffPreview.countLineStats"))
        #expect(source.contains("ChatToolDiffPreview.color"))
        #expect(source.contains("ChatToolDiffPreview.present"))
    }

    @Test("sheet text body is textSelection(.enabled) (= her skans diff to clipboard)")
    func textBodyIsSelectable() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolDiffPreviewSheet.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains(".textSelection(.enabled)"))
    }

    // MARK: - Repo-root path helper (= Q112 source-content anchor)
    //
    // Tests live at Tests/WenshuAppTests/Views/Chat/,
    // which is 3 dirs deep under Tests/,
    // (= Tests/WenshuAppTests/Views/Chat/<file>.swift
    //  => /Volumes/ANAN/Engineering/wenshu/wt/<wt-name>/Sources/...).
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/\(relativeFromRepoRoot)"
        return path
    }
}