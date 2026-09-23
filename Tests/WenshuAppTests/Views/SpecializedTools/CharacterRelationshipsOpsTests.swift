//
//  CharacterRelationshipsOpsTests.swift · Wenshu · v1.75 character-relationships-mvvm T1a
//
//  Behavior + source-level tests for `CharacterRelationshipsOps`
//  (= the stateless enum extracted from CharacterRelationshipsView;
//  = the P0 view listed in .scratch/2026-09-23-mvvm-audit/spec.md §9).
//
//  Coverage (= 11 tests):
//    1.  fileExistsAtCanonicalPath
//    2.  reload returns empty LoadResult when manager is nil
//    3.  reload returns empty LoadResult when bookId is nil
//    4.  addRelationship returns didSave=false when manager is nil
//    5.  addRelationship returns didSave=false when bookId is nil
//    6.  addRelationship returns didSave=false when from is nil
//    7.  addRelationship returns didSave=false when to is nil
//    8.  addRelationship returns didSave=false when from == to
//    9.  removeRelationship returns didSave=false when manager is nil
//    10. sourceHasThreePublicStaticFuncs marker
//    11. sourceIsStatelessEnum marker
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("v1.75 character-relationships-mvvm T1a — CharacterRelationshipsOps (per-book relationship business layer)")
struct CharacterRelationshipsOpsTests {

    // MARK: - Path guard

    @Test("CharacterRelationshipsOps.swift exists at the canonical path under Views/SpecializedTools/")
    func fileExistsAtCanonicalPath() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsOps.swift")
        let exists = FileManager.default.fileExists(atPath: sourcePath.path)
        #expect(exists, "CharacterRelationshipsOps.swift must exist at \(sourcePath.path)")
    }

    // MARK: - reload

    @Test("reload returns empty LoadResult when manager is nil")
    func reloadIgnoresNilManager() async {
        let r = await CharacterRelationshipsOps.reload(manager: nil, bookId: UUID())
        #expect(r.didLoad == false)
        #expect(r.relationships.isEmpty)
        #expect(r.inconsistencies.isEmpty)
        #expect(r.error == nil)
    }

    @Test("reload returns empty LoadResult when bookId is nil")
    func reloadIgnoresNilBookId() async {
        let r = await CharacterRelationshipsOps.reload(manager: nil, bookId: nil)
        #expect(r.didLoad == false)
        #expect(r.relationships.isEmpty)
    }

    // MARK: - addRelationship

    @Test("addRelationship returns didSave=false when manager is nil")
    func addRelationshipIgnoresNilManager() async {
        let r = await CharacterRelationshipsOps.addRelationship(
            manager: nil,
            bookId: UUID(),
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .ally,
            description: "childhood friends"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addRelationship returns didSave=false when bookId is nil")
    func addRelationshipIgnoresNilBookId() async {
        let r = await CharacterRelationshipsOps.addRelationship(
            manager: nil,
            bookId: nil,
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .ally,
            description: "childhood friends"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addRelationship returns didSave=false when from is nil")
    func addRelationshipIgnoresNilFrom() async {
        let r = await CharacterRelationshipsOps.addRelationship(
            manager: nil,
            bookId: UUID(),
            fromCharacterId: nil,
            toCharacterId: UUID(),
            kind: .ally,
            description: "test"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addRelationship returns didSave=false when to is nil")
    func addRelationshipIgnoresNilTo() async {
        let r = await CharacterRelationshipsOps.addRelationship(
            manager: nil,
            bookId: UUID(),
            fromCharacterId: UUID(),
            toCharacterId: nil,
            kind: .ally,
            description: "test"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    @Test("addRelationship returns didSave=false when from == to")
    func addRelationshipIgnoresSelfLoop() async {
        let same = UUID()
        let r = await CharacterRelationshipsOps.addRelationship(
            manager: nil,
            bookId: UUID(),
            fromCharacterId: same,
            toCharacterId: same,
            kind: .ally,
            description: "test"
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - removeRelationship

    @Test("removeRelationship returns didSave=false when manager is nil")
    func removeRelationshipIgnoresNilManager() async {
        let row = CharacterRelationship(
            bookId: UUID(),
            fromCharacterId: UUID(),
            toCharacterId: UUID(),
            kind: .ally,
            description: ""
        )
        let r = await CharacterRelationshipsOps.removeRelationship(
            manager: nil,
            bookId: UUID(),
            row: row
        )
        #expect(r.didSave == false)
        #expect(r.error != nil)
    }

    // MARK: - Source-level markers

    @Test("source-marker: ops file contains 3 public static funcs")
    func sourceHasThreePublicStaticFuncs() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("static func reload"))
        #expect(source.contains("static func addRelationship"))
        #expect(source.contains("static func removeRelationship"))
    }

    @Test("ops file is a stateless enum (= no @Observable / @MainActor class)")
    func sourceIsStatelessEnum() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcePath = repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsOps.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)
        #expect(source.contains("@MainActor"))
        #expect(source.contains("enum CharacterRelationshipsOps"))
        #expect(!source.contains("@Observable"))
        #expect(!source.contains("class CharacterRelationshipsOps"))
    }
}