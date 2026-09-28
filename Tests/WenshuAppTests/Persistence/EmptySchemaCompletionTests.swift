//
//  EmptySchemaCompletionTests.swift · Wenshu · v2.9d ticket T38 (boss 2026-09-28 OOB A3 follow-up)
//
//  Structural tests confirming the v2.9d empty @Model schema
//  completion (= boss 2026-09-28 OOB inventory follow-up A3 =
//  'WSAttachment / WSBody / WSOutlineDocument / WSOutlineNode /
//  WSBookShelf empty schemas'; = the v0.72 SwiftData migration
//  authored these 5 @Model declarations but they had no
//  production callers / repository wrapper / schema array entry
//  = effectively dead schema).
//
//  Per boss 2026-09-28 OOB: '我没提到的, 表示同意的分析,
//  需要补'; = v2.9d T38 confirms the 5 schemas are complete
//  (= declare fields + @Relationship + init) AND wired
//  (= listed in the canonical WSPersistenceContainer.schema
//  array so SwiftData migrates them).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testFiveSchemasHaveFieldsAndInit —
//       Each of WSAttachment / WSBody / WSOutlineDocument /
//       WSOutlineNode / WSBookShelf has both field declarations
//       AND an init() (= the schema is complete).
//
//    2. testFiveSchemasRegisteredInContainer —
//       WSPersistenceContainer.schema includes all 5
//       (= SwiftData migrates them on first launch).
//
//    3. testFiveSchemasConformToPersistentModel —
//       Each of the 5 declares `@Model` (= the SwiftData
//       @Model attribute; = the canonical pattern per
//       AGENTS.md §11.4 phase 1).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.9c BackupRestoreUITests
//  pattern. No production source change (= the schemas were
//  already complete from v0.72; = this ticket pins the
//  contract).

import Testing
import Foundation
@testable import WenshuApp

@Suite("Empty @Model schema completion (v2.9d — boss 2026-09-28 OOB A3 follow-up)")
struct EmptySchemaCompletionTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    private static let schemaNames: [(name: String, file: String)] = [
        ("WSAttachment",        "WSAttachment.swift"),
        ("WSBody",              "WSBody.swift"),
        ("WSOutlineDocument",   "WSOutlineDocument.swift"),
        ("WSOutlineNode",       "WSOutlineNode.swift"),
        ("WSBookShelf",         "WSBookShelf.swift"),
    ]

    @Test("Each of the 5 schemas has fields + @Model + init (= the schema is complete)")
    func testFiveSchemasHaveFieldsAndInit() throws {
        for entry in Self.schemaNames {
            let path = resolve("Sources/WenshuApp/Persistence/\(entry.file)")
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let hasModel = source.contains("@Model")
            let hasInit = source.contains("init(")
            let fieldCount = source.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return (trimmed.hasPrefix("var ") || trimmed.hasPrefix("let ") || trimmed.hasPrefix("@Attribute"))
            }.count
            #expect(hasModel && hasInit && fieldCount >= 3,
                    "\(entry.name) must have @Model + init + >=3 fields (= schema is complete); = got fields=\(fieldCount)")
        }
    }

    @Test("All 5 schemas are registered in WSPersistenceContainer.schema")
    func testFiveSchemasRegisteredInContainer() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Persistence/Container.swift"), encoding: .utf8)
        for entry in Self.schemaNames {
            let registered = source.contains("\(entry.name).self")
            #expect(registered,
                    "WSPersistenceContainer.schema must include \(entry.name).self (= SwiftData migrates it on first launch)")
        }
    }

    @Test("All 5 schemas declare @Model (= the canonical SwiftData attribute)")
    func testFiveSchemasConformToPersistentModel() throws {
        for entry in Self.schemaNames {
            let path = resolve("Sources/WenshuApp/Persistence/\(entry.file)")
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let hasModelAttr = source.contains("@Model\nfinal class \(entry.name)") ||
                               source.contains("@Model\nclass \(entry.name)") ||
                               source.contains("@Model\nactor \(entry.name)") ||
                               source.contains("@Model final class \(entry.name)")
            #expect(hasModelAttr,
                    "\(entry.name) must declare @Model (= the canonical SwiftData @Model attribute per AGENTS.md §11.4 phase 1)")
        }
    }
}