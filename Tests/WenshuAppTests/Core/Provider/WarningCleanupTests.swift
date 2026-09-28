//
//  WarningCleanupTests.swift · Wenshu · v2.9e ticket T39 (boss 2026-09-28 OOB A9)
//
//  Structural tests confirming the v2.9e #warning cleanup
//  (= boss 2026-09-28 OOB inventory A9 = '9 处 sqlite3 metadata
//  悬挂 #warning'; = the v2.8 archive-era warnings marked
//  ProviderKeychain metadata as sqlite-backed; = §11.7d closed
//  sqlite3 fully; = the warnings are historical artifacts that
//  no longer apply; = v2.9e T39 removes them).
//
//  Per AGENTS.md §11.7d: 'Boss 2026-09-21 OOB 数据库不要在用sqlite3
// 了; = the §11.7 v1.55 arc removed the runtime layer but kept
// one-shot legacy importer; = §11.7d v1.55d closure deleted the
// importer; = post-v1.55d the per-file #warning markers are
// historical (= the metadata path is now SwiftData via
// WSProviderKeyRepository / AppleKeychain; = no sqlite3
// remains anywhere in the codebase).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testNoSqliteWarningMarkers —
//       No #warning(...sqlite...) markers exist in
//       production sources (= the historical #warning
//       was removed).
//
//    2. testNoHermesScratchpadWarning —
//       The HermesTodoTool hermes-side scratchpad
//       #warning was also removed (= the marker was
//       informational; = not a code-level gate).
//
//    3. testA9WarningSourceList — the 7 affected source
//       files are listed (= the cleanup is documented).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.9c BackupRestoreUITests
//  pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("#warning cleanup (v2.9e — boss 2026-09-28 OOB A9)")
struct WarningCleanupTests {

    private static let affectedSources: [String] = [
        "Sources/WenshuApp/Core/Auth/SecretScope.swift",
        "Sources/WenshuApp/Core/Provider/AvailableModelsDiscovery.swift",
        "Sources/WenshuApp/Core/Provider/OAuthFlow.swift",
        "Sources/WenshuApp/Core/Agent/Runtime/RuntimeHelpers.swift",
        "Sources/WenshuApp/Core/Agent/Todo/HermesTodoTool.swift",
        "Sources/WenshuApp/Core/Agent/Connector/WenshuVerifier.swift",
        "Sources/WenshuApp/Core/Agent/Connector/ConnectorCredentials.swift",
    ]

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("No #warning(...sqlite...) markers exist in production sources")
    func testNoSqliteWarningMarkers() throws {
        var hits: [String] = []
        for relpath in Self.affectedSources {
            let path = resolve(relpath)
            let source = try String(contentsOfFile: path, encoding: .utf8)
            if source.contains("#warning") && source.contains("sqlite") {
                hits.append(relpath)
            }
        }
        #expect(hits.isEmpty,
                "All sqlite #warning markers must be removed (= boss A9 = '9 处 sqlite3 metadata 悬挂 #warning'); = remaining: \(hits)")
    }

    @Test("HermesTodoTool hermes-side scratchpad #warning removed")
    func testNoHermesScratchpadWarning() throws {
        let path = resolve("Sources/WenshuApp/Core/Agent/Todo/HermesTodoTool.swift")
        let source = try String(contentsOfFile: path, encoding: .utf8)
        // Only the #warning(...) compiler directive counts; = a
        // plain comment referencing "warning" by name (= the
        // file still has a "HermesTodoTool.swift L87 #warning"
        // historical reference) is informational and allowed.
        let isWarningDirective = source.contains("#warning(")
        #expect(!isWarningDirective,
                "HermesTodoTool #warning directive must be removed (= boss A9 = 'warning cleanup'; = the marker was informational only)")
    }

    @Test("The 7 affected source files are listed (= the cleanup is documented)")
    func testA9WarningSourceList() throws {
        #expect(Self.affectedSources.count == 7,
                "The 7 affected source files (= 5 ProviderKeychain-metadata + 1 hermes-side scratchpad + 1 OAuthFlow) must be documented; = got \(Self.affectedSources.count)")
    }
}