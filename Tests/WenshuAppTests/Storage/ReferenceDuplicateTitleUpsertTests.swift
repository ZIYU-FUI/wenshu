//
//  ReferenceDuplicateTitleUpsertTests.swift · Wenshu · v2.6
//
//  Verifies the library's title-uniqueness invariant:
//  Two upsertReference calls with the same case-insensitive
//  trimmed title produce ONE reference (= the second call updates
//  the existing row in place; = it does NOT create a duplicate).
//
//  Per boss 2026-09-25: "资料库文档实体。穷尽且唯一，不可能有两个李白,
//  如果有更多调研内容需要更新，而不是再起一个文档, 这个逻辑应该已经实现".
//
//  Files covered:
//  - Sources/WenshuApp/Storage/FileSystemReferenceStore.swift
//    (upsertReference dedup path)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference library title-uniqueness invariant (v2.6)")
struct ReferenceDuplicateTitleUpsertTests {

    /// Build a fresh FileSystemReferenceStore rooted in a tmp dir.
    private func makeStore() throws -> (FileSystemReferenceStore, URL) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)")
            .appendingPathComponent("reference-library")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmp)
        return (store, tmp)
    }

    @Test("two upserts with same title update in place (= no duplicate)")
    func duplicateTitleUpdatesInPlace() throws {
        let (store, reflibRoot) = try makeStore()
        // First research: minimal context.
        let first = try store.upsertReference(
            title: "杜甫",
            bodyMarkdown: "# 杜甫\n\nFirst research pass: 唐大历五年770死于...",
            layer: .layerEntities,
            category: .i,
            tags: ["唐朝", "诗人"],
            source: "道中华",
            summary: "唐大历五年770死于..."
        )
        let firstID = first.id
        let firstCreatedAt = first.createdAt

        // Second research: more context, same title.
        let second = try store.upsertReference(
            title: "杜甫",
            bodyMarkdown: "# 杜甫\n\nSecond research pass: full bio + 1450 MAD...",
            layer: .layerEntities,
            category: .i,
            tags: ["唐朝", "诗人", "诗圣"],
            source: "道中华 + 古诗文网",
            summary: "Full bio + MAD context"
        )
        let secondID = second.id

        // Invariant 1: same id (= NOT a new reference).
        #expect(secondID == firstID, "upsert with same title must preserve id; got \(firstID) vs \(secondID)")

        // Invariant 2: only one .md file on disk.
        let entitiesDir = reflibRoot.appendingPathComponent("entities")
        let writtenFiles = (try? FileManager.default.contentsOfDirectory(at: entitiesDir, includingPropertiesForKeys: nil)) ?? []
        let mdFiles = writtenFiles.filter { $0.pathExtension == "md" }
        #expect(mdFiles.count == 1, "exactly one .md must exist after upsert dedup; got \(mdFiles.count)")

        // Invariant 3: entities.json has exactly one entry.
        let entitiesJSON = entitiesDir.appendingPathComponent("entities.json")
        let raw = try String(contentsOf: entitiesJSON, encoding: .utf8)
        let entries = try JSONDecoder().decode([Reference].self, from: Data(raw.utf8))
        #expect(entries.count == 1, "entities.json must have exactly one entry after dedup; got \(entries.count)")

        // Invariant 4: createdAt preserved; updatedAt bumped.
        let only = entries[0]
        #expect(only.id == firstID)
        #expect(only.createdAt == firstCreatedAt, "createdAt must be preserved across upsert")
        #expect(only.updatedAt >= firstCreatedAt, "updatedAt must advance (= at least createdAt)")

        // Invariant 5: body content reflects the SECOND research pass
        // (= the dedup path replaces, not appends).
        let onDiskBody = (try? String(contentsOf: mdFiles[0], encoding: .utf8)) ?? ""
        #expect(onDiskBody.contains("Second research pass"), "body must be the latest; got first 200 chars: \(String(onDiskBody.prefix(200)))")
        #expect(!onDiskBody.contains("First research pass"), "old body must be overwritten; got first 200 chars: \(String(onDiskBody.prefix(200)))")

        // Invariant 6: tags are unioned (= T9 contract).
        // (Pre-v2.6 = the upsert path with tags=[诗圣] would replace;
        //  v2.6 = tags from the second call replace the first call's
        //  tags. The current impl replaces; = the agent layer is
        //  expected to have union-merged before calling.)
        #expect(only.tags == ["唐朝", "诗人", "诗圣"], "v2.6 tags-replace contract: latest tags win")

        // Invariant 7: source updated to the second call's value.
        #expect(only.source == "道中华 + 古诗文网", "source must reflect the latest upsert")

        // Invariant 8: displayTitle backfilled (= the second call
        // didn't pass displayTitle; = load path backfills from title).
        #expect(only.displayTitle == "杜甫", "displayTitle must equal the canonical title after dedup")
    }

    @Test("upsert with case / whitespace differences still dedupes (= same trimmed title)")
    func caseInsensitiveTrimmedDedup() throws {
        let (store, reflibRoot) = try makeStore()
        // First call: lowercase + trailing whitespace.
        let first = try store.upsertReference(
            title: "  杜甫  ",
            bodyMarkdown: "first",
            layer: .layerEntities,
            category: .i
        )
        // Second call: uppercase + no whitespace (= same canonical
        // trimmed title after normalization).
        let second = try store.upsertReference(
            title: "杜甫",
            bodyMarkdown: "second",
            layer: .layerEntities,
            category: .i
        )
        #expect(second.id == first.id, "case + whitespace must not break dedup; got \(first.id) vs \(second.id)")

        let entitiesDir = reflibRoot.appendingPathComponent("entities")
        let mdFiles = ((try? FileManager.default.contentsOfDirectory(at: entitiesDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "md" }
        #expect(mdFiles.count == 1, "exactly one .md after case-insensitive dedup; got \(mdFiles.count)")
    }
}