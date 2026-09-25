//
//  ReferenceStoreMigrationTests.swift · Wenshu · v2.6 facet model
//
//  Verifies the FileSystemReferenceStore legacy-layout migration:
//  - Saves at the flat path `entities/<uuid>.md` (not category-subdir)
//  - On first load, scans for legacy `entities/<category>/<uuid>.md`
//    files and moves them to the flat path (= one-shot, idempotent)
//  - The entities.json index survives the migration (= category
//    metadata is preserved as JSON metadata, not directory location)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceStore v2.6 facet migration")
struct ReferenceStoreMigrationTests {

    /// Test helper: build a FileSystemReferenceStore against an isolated
    /// temporary `.ws/reference-library/` directory (= no leakage to the
    /// user's real library).
    private func makeStore() throws -> (FileSystemReferenceStore, URL, URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-ref-store-migration-\(UUID().uuidString)")
            .appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmp)
        return (store, tmp, tmp.deletingLastPathComponent())
    }

    @Test("saveReference writes to entities/<title>--<uuid8>.md (v2.6 facet convention)")
    func saveTitleFilename() throws {
        let (store, reflibRoot, _) = try makeStore()
        let refID = UUID()
        let ref = Reference(
            id: refID,
            title: "李白",
            layer: .layerEntities,
            category: .i,
            tags: ["诗人", "唐朝"]
        )
        try store.saveReference(ref, bodyMarkdown: "# 李白\n")

        // The file must land at the v2.6 facet path: entities/<title>--<uuid8>.md.
        let expectedName = "李白--\(String(refID.uuidString.prefix(8))).md"
        let expectedPath = reflibRoot
            .appendingPathComponent("entities")
            .appendingPathComponent(expectedName)
        #expect(FileManager.default.fileExists(atPath: expectedPath.path),
                "expected v2.6 facet filename at \(expectedPath.path)")

        // No UUID-only file should also exist (= one file per reference).
        let legacyFlatPath = reflibRoot
            .appendingPathComponent("entities")
            .appendingPathComponent("\(refID.uuidString).md")
        #expect(!FileManager.default.fileExists(atPath: legacyFlatPath.path),
                "no UUID-only file should exist; found \(legacyFlatPath.path)")

        // No category subdir should be created by saveReference.
        let categoryDir = reflibRoot.appendingPathComponent("entities/i")
        #expect(!FileManager.default.fileExists(atPath: categoryDir.path),
                "no category subdir should be created by saveReference; = found \(categoryDir.path)")
    }

    @Test("filename sanitizer strips filesystem-unsafe characters")
    func sanitizeFilenameSafety() {
        #expect(Reference.sanitizeFilename("李白") == "李白")
        #expect(Reference.sanitizeFilename("hello world") == "hello-world")
        #expect(Reference.sanitizeFilename("  spaced  ") == "spaced")
        #expect(Reference.sanitizeFilename("a/b\\c:d|e?f*g\"h<i>j") == "abcdefghij")
        #expect(Reference.sanitizeFilename("multiple   spaces") == "multiple-spaces")
        #expect(Reference.sanitizeFilename("--leading-and-trailing--") == "leading-and-trailing")
        #expect(Reference.sanitizeFilename("") == "")
    }

    @Test("legacy `entities/<category>/<uuid>.md` migrates to flat path on first load")
    func legacyMigration() throws {
        let (store, reflibRoot, _) = try makeStore()
        let entitiesDir = reflibRoot.appendingPathComponent("entities")
        try FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)
        // Build a legacy file at entities/i/<uuid>.md (= pre-v2.6 layout).
        let refID = UUID()
        let legacyPath = entitiesDir
            .appendingPathComponent("i")  // legacy category subdir
            .appendingPathComponent("\(refID.uuidString).md")
        try FileManager.default.createDirectory(
            at: legacyPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "# 李白 (legacy)".write(to: legacyPath, atomically: true, encoding: .utf8)
        // Build a minimal entities.json so loadReferences returns the entry.
        let ref = Reference(
            id: refID,
            title: "李白",
            layer: .layerEntities,
            category: .i,
            tags: []
        )
        let entitiesJSON = entitiesDir.appendingPathComponent("entities.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode([ref]).write(to: entitiesJSON, options: .atomic)

        // Trigger the migration (= happens during loadReferences).
        let loaded = try store.loadReferences(layer: .layerEntities)
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == refID)

        // Legacy file moved to v2.6 facet filename (= title--uuid8).
        let expectedName = "李白--\(String(refID.uuidString.prefix(8))).md"
        let titlePath = entitiesDir.appendingPathComponent(expectedName)
        #expect(FileManager.default.fileExists(atPath: titlePath.path),
                "legacy file should be renamed to title-filename on first load")
        // Legacy path is gone.
        #expect(!FileManager.default.fileExists(atPath: legacyPath.path),
                "legacy path should be removed after migration")

        // Migration is idempotent — second call is a no-op.
        let loaded2 = try store.loadReferences(layer: .layerEntities)
        #expect(loaded2.count == 1)
        #expect(FileManager.default.fileExists(atPath: titlePath.path),
                "title path still exists after second load (= migration is idempotent)")
    }

    @Test("flat-UUID filename migrates to title filename on first load")
    func flatUUIDToTitleFilename() throws {
        let (store, reflibRoot, _) = try makeStore()
        let entitiesDir = reflibRoot.appendingPathComponent("entities")
        try FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)
        // Pre-v2.6.1 layout: file at entities/<uuid>.md (= flat UUID).
        let refID = UUID()
        let legacyFlatPath = entitiesDir
            .appendingPathComponent("\(refID.uuidString).md")
        try "# 李白 (flat)".write(to: legacyFlatPath, atomically: true, encoding: .utf8)
        // entities.json has the title mapping.
        let ref = Reference(
            id: refID,
            title: "李白",
            layer: .layerEntities,
            category: .i,
            tags: ["诗人"]
        )
        let entitiesJSON = entitiesDir.appendingPathComponent("entities.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode([ref]).write(to: entitiesJSON, options: .atomic)

        // Trigger the migration.
        _ = try store.loadReferences(layer: .layerEntities)

        // The file should now be at entities/<title>--<uuid8>.md.
        let expectedName = "李白--\(String(refID.uuidString.prefix(8))).md"
        let titlePath = entitiesDir.appendingPathComponent(expectedName)
        #expect(FileManager.default.fileExists(atPath: titlePath.path),
                "flat-UUID file should be renamed to title-filename")
        #expect(!FileManager.default.fileExists(atPath: legacyFlatPath.path),
                "flat-UUID path should be removed after title-filename migration")
    }

    @Test("category metadata survives migration (= preserved in entities.json)")
    func categoryMetadataPreserved() throws {
        let (store, reflibRoot, _) = try makeStore()
        let entitiesDir = reflibRoot.appendingPathComponent("entities")
        try FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)
        // Pre-v2.6 layout: file at entities/i/<uuid>.md
        let refID = UUID()
        let legacyPath = entitiesDir
            .appendingPathComponent("i")
            .appendingPathComponent("\(refID.uuidString).md")
        try FileManager.default.createDirectory(
            at: legacyPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "# 李白".write(to: legacyPath, atomically: true, encoding: .utf8)
        // entities.json: category="I" preserved as metadata.
        let ref = Reference(
            id: refID,
            title: "李白",
            layer: .layerEntities,
            category: .i,
            tags: ["诗人"]
        )
        let entitiesJSON = entitiesDir.appendingPathComponent("entities.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode([ref]).write(to: entitiesJSON, options: .atomic)

        let loaded = try store.loadReferences(layer: .layerEntities)
        #expect(loaded.first?.category == .i,
                "category metadata must be preserved across the migration (= it lives in entities.json, not the directory tree)")
        #expect(loaded.first?.tags == ["诗人"],
                "tags metadata must survive the migration")
    }
}