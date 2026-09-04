// CharacterStoringContractTests.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Contract tests for the CharacterStoring protocol (= ticket 023).
// Mirrors the WorldStoringContractTests pattern at WorldStoringContractTests.swift.

import Testing
import Foundation
@testable import WenshuApp

@Suite("CharacterStoring contract")
struct CharacterStoringContractTests {

    private func makeStore() throws -> (any CharacterStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test-book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        return (FileSystemCharacterStore(bookDirectory: bookDir), bookDir)
    }

    @Test("empty character store returns []")
    func emptyReturnsEmpty() throws {
        let (store, _) = try makeStore()
        let characters = try store.loadCharacters()
        #expect(characters.isEmpty)
    }

    @Test("saveCharacter + loadCharacters roundtrips")
    func saveLoadRoundtrips() throws {
        let (store, _) = try makeStore()
        let character = Character(bookId: UUID(), name: "张三", age: 30, role: .protagonist, arc: "从 a 到 c", summary: "主角")
        try store.saveCharacter(character, bodyMarkdown: "# 张三\n\n主角，30岁。\n")
        let loaded = try store.loadCharacters()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == character.id)
        #expect(loaded[0].name == "张三")
        #expect(loaded[0].role == .protagonist)
    }

    @Test("characterExists returns true after save")
    func existsCheck() throws {
        let (store, _) = try makeStore()
        let character = Character(bookId: UUID(), name: "李四", role: .antagonist)
        #expect(store.characterExists(id: character.id) == false)
        try store.saveCharacter(character, bodyMarkdown: "# 李四\n")
        #expect(store.characterExists(id: character.id) == true)
    }

    @Test("deleteCharacter is idempotent")
    func deleteIdempotent() throws {
        let (store, _) = try makeStore()
        let character = Character(bookId: UUID(), name: "王五", role: .supporting)
        try store.saveCharacter(character, bodyMarkdown: "# 王五\n")
        try store.deleteCharacter(id: character.id)
        try store.deleteCharacter(id: character.id)  // should not throw
        #expect(try store.loadCharacters().isEmpty)
    }
}