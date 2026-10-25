//
//  ReferenceLibraryLocatorTests.swift
//
//  The agent's reference-library tool must write into the library the
//  user has open, not into a directory the tool made for itself.
//
//  Before this, the tool registry built the tool against a throwaway
//  /tmp root (the registry needs an instance before the library
//  exists), so every document the agent wrote landed there: invisible
//  in the user's library, gone with the next launch, and no
//  constraint for the writing that follows.
//
//  Covers:
//  - the launch sequence binds the user's reference library,
//  - a document the agent writes lands in that library,
//  - the tool still works when no library is bound.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference library locator", .serialized)
@MainActor
struct ReferenceLibraryLocatorTests {

    private static func makeLibraryRoot() throws -> URL {
        let root = URL(fileURLWithPath: "/tmp/wenshu-reference-locator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("the launch sequence binds the user's reference library")
    func launchBindsTheLibrary() throws {
        let wsRoot = try Self.makeLibraryRoot()
        defer { ReferenceLibraryLocator.shared.unbindForTest() }

        let result = try LibraryLifecycleHook(wsRoot: wsRoot).runLaunch()

        let bound = try #require(ReferenceLibraryLocator.shared.referenceStore)
        #expect(bound.referenceLibraryRoot == result.stores.referenceLibraryRoot)
        #expect(
            ReferenceLibraryLocator.shared.referenceLibraryRoot == result.stores.referenceLibraryRoot,
            "the bound root must be the library the UI reads from (= one library, not two)"
        )
    }

    @Test("a document the agent writes lands in the bound library")
    func agentWriteLandsInTheBoundLibrary() async throws {
        let wsRoot = try Self.makeLibraryRoot()
        defer { ReferenceLibraryLocator.shared.unbindForTest() }
        let result = try LibraryLifecycleHook(wsRoot: wsRoot).runLaunch()

        let tool = ReferenceLibraryTool(
            actor: ReferenceLibraryActor(
                referenceStoreProvider: {
                    ReferenceLibraryLocator.shared.referenceStore ?? result.stores.referenceStore
                }
            )
        )
        let output = try await tool.execute(input: """
        {"action":"create","title":"Harbor survey","layer":"raw","summary":"A survey of the harbor tide gauges.","body":"# Harbor survey"}
        """)
        #expect(output.contains("\"ok\":true"))

        // The document is in the USER's library (= the file is under
        // the library root, not under a tool-private directory).
        let references = try result.stores.referenceStore.loadAllReferences()
        let created = try #require(references.first { $0.title == "Harbor survey" })
        #expect(result.stores.referenceStore.loadReferenceBody(id: created.id) == "# Harbor survey")
    }

    @Test("the tool still works when no library is bound")
    func toolFallsBackToItsOwnStore() async throws {
        ReferenceLibraryLocator.shared.unbindForTest()
        let fallbackRoot = URL(fileURLWithPath: "/tmp/wenshu-reference-fallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)
        let fallbackStore = FileSystemReferenceStore(referenceLibraryRoot: fallbackRoot)

        let tool = ReferenceLibraryTool(
            actor: ReferenceLibraryActor(
                referenceStoreProvider: {
                    ReferenceLibraryLocator.shared.referenceStore ?? fallbackStore
                }
            )
        )
        let output = try await tool.execute(input: """
        {"action":"create","title":"Harbor survey","layer":"raw","summary":"A survey.","body":"# Harbor survey"}
        """)
        #expect(output.contains("\"ok\":true"))
        #expect(try fallbackStore.loadAllReferences().contains { $0.title == "Harbor survey" })
    }
}
