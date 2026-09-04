// CrossRefInjectTests.swift · Wenshu (文枢) · v0.27 (FCP library replica)
//
// Contract tests for the CrossRefInject pipeline. Mirrors the
// SmartQueryParserTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("CrossRefInject contract")
struct CrossRefInjectTests {

    private func makeStores() throws -> (ReferenceStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-crossref-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let chaptersDir = bookDir.appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        let refLib = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: refLib, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: refLib)
        return (store, bookDir)
    }

    @Test("FrontmatterParser.parse handles empty source")
    func parseEmpty() {
        let (fm, body) = FrontmatterParser.parse("hello world")
        #expect(fm.title == nil)
        #expect(body == "hello world")
    }

    @Test("FrontmatterParser.parse roundtrips with serialize")
    func frontmatterRoundtrip() {
        let source = "---\ntitle: Test\nreferenceRefIds: [00000000-0000-0000-0000-000000000001]\n---\n\nbody content"
        let (fm, body) = FrontmatterParser.parse(source)
        #expect(fm.title == "Test")
        #expect(fm.referenceRefIds?.count == 1)
        // Body after `---\n\n` is "\nbody content" (= the leading blank
        // line is preserved so serialize/parse roundtrips without drift).
        #expect(body == "\nbody content")
        let reserialized = FrontmatterParser.serialize(frontmatter: fm, body: body)
        #expect(reserialized.contains("title: Test"))
        #expect(reserialized.contains("body content"))
    }

    @Test("CrossRefInject finds entities in chapter body and injects refs")
    func injectFindsEntities() throws {
        let (store, bookDir) = try makeStores()
        let entity = Reference(title: "张三", layer: .layerEntities)
        try store.saveReference(entity, bodyMarkdown: "# 张三\n")
        let chapterURL = bookDir.appendingPathComponent("chapters/chapter1.md")
        try "# Chapter 1\n\n张三在城里遇到了李四。".write(to: chapterURL, atomically: true, encoding: .utf8)
        let inject = CrossRefInject(referenceStore: store, bookDirectory: bookDir)
        let updated = try inject.runInjection()
        #expect(updated == 1)
        let updatedContent = try String(contentsOf: chapterURL, encoding: .utf8)
        #expect(updatedContent.contains(entity.id.uuidString))
    }

    @Test("CrossRefInject is idempotent (no duplicate refs on second run)")
    func injectIdempotent() throws {
        let (store, bookDir) = try makeStores()
        let entity = Reference(title: "王五", layer: .layerEntities)
        try store.saveReference(entity, bodyMarkdown: "# 王五\n")
        let chapterURL = bookDir.appendingPathComponent("chapters/chapter1.md")
        try "# Chapter 1\n\n王五在山脚下。".write(to: chapterURL, atomically: true, encoding: .utf8)
        let inject = CrossRefInject(referenceStore: store, bookDirectory: bookDir)
        _ = try inject.runInjection()
        _ = try inject.runInjection()
        let content = try String(contentsOf: chapterURL, encoding: .utf8)
        // Count occurrences of the entity UUID; should be exactly 1 (= idempotent).
        let occurrences = content.components(separatedBy: entity.id.uuidString).count - 1
        #expect(occurrences == 1)
    }

    @Test("CrossRefInject does NOT inject when entity is not in chapter body")
    func injectNoMatch() throws {
        let (store, bookDir) = try makeStores()
        let entity = Reference(title: "完全无关的实体", layer: .layerEntities)
        try store.saveReference(entity, bodyMarkdown: "# 完全无关\n")
        let chapterURL = bookDir.appendingPathComponent("chapters/chapter1.md")
        try "# Chapter 1\n\n不包含任何实体的章节。".write(to: chapterURL, atomically: true, encoding: .utf8)
        let inject = CrossRefInject(referenceStore: store, bookDirectory: bookDir)
        let updated = try inject.runInjection()
        #expect(updated == 0)
    }
}