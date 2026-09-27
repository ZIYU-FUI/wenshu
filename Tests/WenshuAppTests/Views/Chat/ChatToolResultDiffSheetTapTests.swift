//
//  ChatToolResultDiffSheetTapTests.swift · wenshu · chat-diff-sheet 2026-09-28 T7
//
//  RED tests for tap-to-expand wire-up. Phase 4 of chat-diff-sheet
//  arc. The inline ChatToolDiffPreview card opens ChatToolDiffPreviewSheet
//  when tapped, IF the diff body exceeds a threshold (= 8 lines or
//  480 chars; = same heuristic as ChatToolResultPartView's expand
//  toggle). Short diffs stay inline (= the sheet would be empty).
//
//  Source-content anchor (= Q112 single-file-per-ticket): the
//  wire-up lives in ChatToolResultPartView.swift; = this test
//  verifies the source contains the expected `sheet(...)` +
//  `ChatToolDiffPreviewSheet(` host pattern.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolResultPartView tap-to-expand diff sheet (chat-diff-sheet 2026-09-28 T7)")
struct ChatToolResultDiffSheetTapTests {

    @Test("ChatToolResultPartView hosts a .sheet(item:) on the long-diff path")
    func hostSheetOnLongDiff() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // The host pattern (= same shape as KanbanView's KanbanCard sheet
        // host per the kanban-detail-sheet arc) = sheet(item: $sheetTicket).
        #expect(source.contains(".sheet(item:"), "the long-diff card must host a sheet")
    }

    @Test("ChatToolResultPartView wires ChatToolDiffPreviewSheet on sheet content")
    func wireChatToolDiffPreviewSheet() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains("ChatToolDiffPreviewSheet("),
                "sheet content must construct ChatToolDiffPreviewSheet with the diff + filename")
    }

    @Test("ChatToolDiffPreview card body is .contentShape(Rectangle()) + .onTapGesture")
    func cardIsTappable() throws {
        let path = Self.repoSourcePath("Sources/WenshuApp/Views/Chat/ChatToolResultPartView.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        #expect(source.contains(".contentShape(Rectangle())"),
                "diff card body must accept taps over its full rectangle")
        #expect(source.contains(".onTapGesture"),
                "diff card body must wire .onTapGesture to open the sheet")
    }

    // MARK: - Repo-root path helper
    private static func repoSourcePath(_ relativeFromRepoRoot: String) -> String {
        let path = "/Volumes/ANAN/Engineering/wenshu/wt/chat-diff-sheet-2026-09-28/\(relativeFromRepoRoot)"
        return path
    }
}