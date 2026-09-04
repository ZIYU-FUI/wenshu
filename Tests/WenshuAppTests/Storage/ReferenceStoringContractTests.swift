// ReferenceStoringContractTests.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Contract tests for the ReferenceStoring protocol (= ticket 023).
// Mirrors the WorldStoringContractTests pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceStoring contract")
struct ReferenceStoringContractTests {

    private func makeStore() throws -> (any ReferenceStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let refLib = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(at: refLib, withIntermediateDirectories: true)
        return (FileSystemReferenceStore(referenceLibraryRoot: refLib), refLib)
    }

    @Test("loadMetadata on fresh store returns .empty defaults")
    func loadMetadataDefaults() throws {
        let (store, _) = try makeStore()
        let metadata = try store.loadMetadata()
        #expect(metadata.schemaVersion == 1)
    }

    @Test("saveMetadata + loadMetadata roundtrips")
    func metadataRoundtrip() throws {
        let (store, _) = try makeStore()
        let original = ReferenceLibraryMetadata(schemaVersion: 1, createdAt: Date())
        try store.saveMetadata(original)
        let loaded = try store.loadMetadata()
        #expect(loaded.schemaVersion == 1)
    }

    @Test("loadAllReferences on fresh store returns []")
    func loadAllEmpty() throws {
        let (store, _) = try makeStore()
        let all = try store.loadAllReferences()
        #expect(all.isEmpty)
    }

    @Test("saveReference + loadReferences(layer:) roundtrips")
    func saveLoadReference() throws {
        let (store, _) = try makeStore()
        let reference = Reference(
            title: "万历十五年",
            source: "黄仁宇",
            url: nil,
            layer: .layerRaw,
            summary: "明代研究的经典著作"
        )
        try store.saveReference(reference, bodyMarkdown: "# 万历十五年\n\n...")
        let loaded = try store.loadReferences(layer: .layerRaw)
        #expect(loaded.count == 1)
        #expect(loaded[0].id == reference.id)
        #expect(loaded[0].title == "万历十五年")
    }

    @Test("loadReferenceBody returns the .md body verbatim")
    func loadBodyVerbatim() throws {
        let (store, _) = try makeStore()
        let reference = Reference(title: "Test", layer: .layerRaw)
        let body = "# Test\n\nSome body content here.\n"
        try store.saveReference(reference, bodyMarkdown: body)
        let loaded = try store.loadReferenceBody(id: reference.id)
        #expect(loaded == body)
    }
}