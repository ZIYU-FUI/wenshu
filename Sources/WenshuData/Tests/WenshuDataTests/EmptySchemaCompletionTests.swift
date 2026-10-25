//
//  EmptySchemaCompletionTests.swift · Wenshu · v2.9d ticket T38 (boss 2026-09-28 OOB A3 follow-up)
//
//  Structural tests confirming the v2.9d empty @Model schema
//  completion (= boss 2026-09-28 OOB inventory follow-up A3 =
//  'WSBody / WSBookShelf empty schemas'; = the v0.72 SwiftData
//  migration authored these @Model declarations but they had no
//  production callers / repository wrapper / schema array entry
//  = effectively dead schema).
//
//  Per boss 2026-09-28 OOB: 'the ones I did not mention count as
//  agreed; = v2.9d T38 confirms the schemas are complete
//  (= declare fields + @Relationship + init) AND wired
//  (= listed in the canonical WSPersistenceContainer.schema
//  array so SwiftData migrates them).
//
//  The 2026-10-25 residue cleanup dropped the empty schemas whose
//  storage served the already-removed Attachments window, the old
//  outline model, and the old outline tree. The surviving empty
//  schemas (= the ones with no repository wrapper) are WSBody and
//  WSBookShelf, so the contract below is pinned against those 2.
//
//  Three source-level tests pin the canonical shape:
//
//    1. testEmptySchemasHaveFieldsAndInit —
//       Each empty schema has both field declarations
//       AND an init() (= the schema is complete).
//
//    2. testEmptySchemasRegisteredInContainer —
//       WSPersistenceContainer.schema includes both
//       (= SwiftData migrates them on first launch).
//
//    3. testEmptySchemasConformToPersistentModel —
//       Each declares `@Model` (= the SwiftData
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
import WenshuData

@Suite("Empty @Model schema completion (v2.9d — boss 2026-09-28 OOB A3 follow-up)")
struct EmptySchemaCompletionTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    private static let schemaNames: [(name: String, file: String)] = [
        ("WSBody",              "WSBody.swift"),
        ("WSBookShelf",         "WSBookShelf.swift"),
    ]

    @Test("Each empty schema has fields + @Model + init (= the schema is complete)")
    func testEmptySchemasHaveFieldsAndInit() throws {
        for entry in Self.schemaNames {
            let path = resolve("WenshuData/Sources/WenshuData/\(entry.file)")
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let hasModel = source.contains("@Model")
            let hasInit = source.contains("init(")
            let fieldCount = source.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return (trimmed.hasPrefix("var ") ||
                        trimmed.hasPrefix("let ") ||
                        trimmed.hasPrefix("@Attribute") ||
                        trimmed.hasPrefix("public var ") ||
                        trimmed.hasPrefix("public let ") ||
                        trimmed.hasPrefix("public @Attribute") ||
                        trimmed.hasPrefix("private var ") ||
                        trimmed.hasPrefix("private let "))
            }.count
            #expect(hasModel && hasInit && fieldCount >= 3,
                    "\(entry.name) must have @Model + init + >=3 fields (= schema is complete); = got fields=\(fieldCount)")
        }
    }

    @Test("Every empty schema is registered in WSPersistenceContainer.schema")
    func testEmptySchemasRegisteredInContainer() throws {
        let source = try String(contentsOfFile: resolve("WenshuData/Sources/WenshuData/Container.swift"), encoding: .utf8)
        for entry in Self.schemaNames {
            let registered = source.contains("\(entry.name).self")
            #expect(registered,
                    "WSPersistenceContainer.schema must include \(entry.name).self (= SwiftData migrates it on first launch)")
        }
    }

    @Test("Every empty schema declares @Model (= the canonical SwiftData attribute)")
    func testEmptySchemasConformToPersistentModel() throws {
        for entry in Self.schemaNames {
            let path = resolve("WenshuData/Sources/WenshuData/\(entry.file)")
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let hasModelAttr = source.contains("@Model\nfinal class \(entry.name)") ||
                               source.contains("@Model\nclass \(entry.name)") ||
                               source.contains("@Model\nactor \(entry.name)") ||
                               source.contains("@Model final class \(entry.name)") ||
                               source.contains("@Model\npublic final class \(entry.name)") ||
                               source.contains("@Model\npublic class \(entry.name)") ||
                               source.contains("@Model\npublic actor \(entry.name)") ||
                               source.contains("@Model public final class \(entry.name)") ||
                               source.contains("@Model public class \(entry.name)")
            #expect(hasModelAttr,
                    "\(entry.name) must declare @Model (= the canonical SwiftData @Model attribute per AGENTS.md §11.4 phase 1)")
        }
    }
}
