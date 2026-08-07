// WenshuProjectStoreTests.swift · 文枢 (Wenshu) · v0.01.0 WO-005
//
// Covers save / load / re-save paths on `WenshuProjectStore`. Each test
// builds its own in-memory `NSPersistentContainer` so they're isolated
// (no SQLite file on disk, no shared state between tests).
//
// Per WO-005 spec: "至少 3 个 case:save/load/delete". Since the underlying
// WenshuStoreActor has no `delete` method (and we can't add one — its
// signature is PM-locked), we interpret:
//   save   → save persists all 3 entity kinds + count is accurate
//   load   → previously-saved data can be read back via firstSavedStory /
//            savedCharacterNames
//   delete → not applicable; we substitute a "second save accumulates, not
//            overwrites" test (testMultipleSaves_accumulateEntities).

import XCTest
@testable import WenshuApp
import CoreData

final class WenshuProjectStoreTests: XCTestCase {

    // MARK: - Fixtures

    /// Build a `WenshuProjectStore` backed by an in-memory CoreData store.
    /// Identical pattern to `WenshuStoreActorTests.makeStore()` — the
    /// in-memory store gives us real `create*` semantics without touching
    /// `~/Documents/wenshu-projects/`.
    private func makeStore() -> WenshuProjectStore {
        let container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Failed to load in-memory store: \(String(describing: error))")
        }
        let storeActor = WenshuStoreActor(container: container)
        return WenshuProjectStore(storeActor: storeActor)
    }

    /// A canonical WO-004 mock payload — 1 project + 3 characters + 4 rules.
    private func sampleProject() -> ProjectSnapshot {
        ProjectSnapshot(name: "测试故事", style: "轻松", verbosity: 5, tags: ["都市", "言情"])
    }

    private func sampleCharacters() -> [CharacterSnapshot] {
        MockLLMResponse.characters()
    }

    private func sampleWorldRules() -> [WorldRuleSnapshot] {
        MockLLMResponse.worldRules()
    }

    // MARK: - Tests

    /// save → 1 CDNote + 3 CDCharacter + 4 CDWorldRule = 8 entities.
    /// Equivalent to a "save" test in the WO-005 spec checklist.
    func testSave_persistsAllEntityTypes() async throws {
        let store = makeStore()
        try await store.save(
            project: sampleProject(),
            characters: sampleCharacters(),
            worldRules: sampleWorldRules(),
            initialStory: "女主角在雨天咖啡店偶遇十年未见的初恋"
        )
        let total = try await store.savedEntityCount()
        XCTAssertEqual(total, 8, "Expected 1 note + 3 characters + 4 world rules = 8")
    }

    /// save → initial story text can be read back via `firstSavedStory()`.
    /// Equivalent to a "load" test in the WO-005 spec checklist.
    func testSave_initialStoryIsReadable() async throws {
        let store = makeStore()
        let story = "咖啡、雨、十年——一段尘封的旧事在此刻重新打开。"
        try await store.save(
            project: sampleProject(),
            characters: sampleCharacters(),
            worldRules: sampleWorldRules(),
            initialStory: story
        )
        let stories = try await store.firstSavedStory()
        XCTAssertEqual(stories, story, "listNotes must echo the saved story text")
    }

    /// save → character names can be read back via `savedCharacterNames()`.
    /// This is the closest thing to a "load specific row" test we have at
    /// the WenshuStoreActor API surface.
    func testSave_characterNamesAreReadable() async throws {
        let store = makeStore()
        try await store.save(
            project: sampleProject(),
            characters: sampleCharacters(),
            worldRules: sampleWorldRules(),
            initialStory: "irrelevant"
        )
        let names = try await store.savedCharacterNames()
        let expected = Set(["林渊", "苏锦", "沈望"])
        XCTAssertEqual(Set(names), expected)
    }

    /// Two saves back-to-back must accumulate (no overwrite), since we have
    /// no `delete` API at the store-actor level. This is the closest thing
    /// to a "delete" test the v0.01.0 schema allows — it verifies that
    /// saving a second project does NOT wipe the first one's data.
    func testMultipleSaves_accumulateEntities() async throws {
        let store = makeStore()
        try await store.save(
            project: sampleProject(),
            characters: sampleCharacters(),
            worldRules: sampleWorldRules(),
            initialStory: "故事 A"
        )
        // Second project: 1 note + 1 character + 0 world rules = 2 entities
        try await store.save(
            project: ProjectSnapshot(name: "第二本", style: "严肃", verbosity: 7),
            characters: [CharacterSnapshot(name: "孤狼", role: "主角", backstory: "独自穿行在荒原上的赏金猎人。")],
            worldRules: [],
            initialStory: "故事 B"
        )
        let total = try await store.savedEntityCount()
        XCTAssertEqual(total, 10, "Expected 8 (first save) + 2 (second save) = 10")
    }

    /// `~/Documents/wenshu-projects/` directory must exist after `init`
    /// (WO-005 verification: "swift run 后 目录被建出来"). We can't easily
    /// redirect the singleton's URL via DI (it's `nonisolated let`), so we
    /// just check the FileManager reports the default path exists.
    func testSharedStore_createsProjectsDirectory() {
        // Touching `.shared` triggers the actor's init, which calls
        // FileManager.createDirectory on the standard path.
        _ = WenshuProjectStore.shared
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("wenshu-projects", isDirectory: true)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expected.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists, "Expected \(expected.path) to exist after init")
        XCTAssertTrue(isDirectory.boolValue, "Expected path to be a directory")
    }
}
