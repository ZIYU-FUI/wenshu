//
//  ChatToolDiffPreviewTests.swift · wenshu · chat-diff-preview 2026-09-28
//
//  RED tests for the unified-diff preview component. Phase-1 of the
//  chat-diff-preview arc.
//
//  The component is read-only and self-contained: it takes a unified
//  diff string and renders added lines green, removed lines red, with
//  +N / -N character counts in the header (= mirrors hermes commit
//  a61baa9615 `feat(desktop): PR-style file diffs in chat` and the
//  chat-side diff rendering API in tool-fallback-model.ts).
//
//  Phase 2 of the arc wires this into ChatToolResultPartView when the
//  tool result payload carries a diff field (= LLM-authored chapter
//  writes surface as red/green hunks rather than raw JSON).
//
//  Source-level + behavior pin (the SwiftUI render itself is hard to
//  unit-test without bringing up a render host; = we pin the API
//  surface and the helper behavior in this file).
//
//  Repo-root walk: Tests/WenshuAppTests/Views/Chat/*.swift → 5 dirs up.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatToolDiffPreview (chat-diff-preview 2026-09-28 T1)")
struct ChatToolDiffPreviewTests {

    private func repoRootFromTestFile() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url
    }

    @Test("ChatToolDiffPreview.swift exists with the canonical API")
    func sourceLevelAPISurface() throws {
        let path = repoRootFromTestFile()
            .appendingPathComponent("Sources/WenshuApp/Views/Chat/ChatToolDiffPreview.swift")
        let text = try String(contentsOf: path, encoding: .utf8)
        // The view must:
        //  - be a SwiftUI View (struct … : View)
        //  - take a unified diff string + filename
        //  - expose static helpers for line stats + headers stripping
        //    (= test-only consumers reach the helpers via the type,
        //    not via instance state).
        #expect(text.contains("struct ChatToolDiffPreview"))
        #expect(text.contains(": View"))
        #expect(text.contains("func countLineStats"))
        #expect(text.contains("func stripFileHeaders"))
    }

    @Test("countLineStats counts +N added lines and -M removed lines (excluding file headers)")
    func behaviorCountStats() {
        let diff = """
        --- a/chapter-1.md
        +++ b/chapter-1.md
        @@ -1,3 +1,4 @@
        Line one stays.
        -removed line
        +added line 1
        +added line 2
        Line two stays.
        """
        let stats = ChatToolDiffPreview.countLineStats(diff)
        #expect(stats.addedLines == 2)
        #expect(stats.removedLines == 1)
    }

    @Test("countLineStats counts chars (not just lines) — the user-visible metric")
    func behaviorCountChars() {
        let diff = "-short\n+longer line here\n+another line\n"
        let stats = ChatToolDiffPreview.countLineStats(diff)
        // removedChars = length of "short" = 5
        // addedChars = "longer line here".count + "another line".count
        let addedExpected = "longer line here".count + "another line".count
        #expect(stats.removedChars == "short".count)
        #expect(stats.addedChars == addedExpected)
    }

    @Test("stripFileHeaders drops the git preamble up to the first @@ hunk header")
    func behaviorStripHeaders() {
        let diff = """
        diff --git a/c.md b/c.md
        index abc..def 100644
        --- a/c.md
        +++ b/c.md
        @@ -1,1 +1,2 @@
        unchanged
        +added
        """
        let stripped = ChatToolDiffPreview.stripFileHeaders(diff)
        // The result should start at the hunk header (the git noise is gone).
        #expect(stripped.hasPrefix("@@"))
        #expect(stripped.contains("diff --git") == false)
        #expect(stripped.contains("--- a/c.md") == false)
    }
}
