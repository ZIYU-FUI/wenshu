//
//  ReferenceLibraryToolLayerTests.swift · Wenshu
//
//  Where a tool write lands.
//
//  The reference library has two layers. `entities` is the user-facing
//  one: = the card grid, the tag tree and the category buckets all
//  filter on it. `raw` is the internal ingestion layer: = nothing in
//  production reads it and nothing in production writes it.
//
//  So a write that lands in `raw` is a document the user never sees,
//  and a researcher's grounded summary landing there is work the
//  product performed and the user cannot find. The default the tool
//  carries decides which of the two happens, and the default used to
//  be the invisible one.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Reference library tool · the layer a write lands in")
@MainActor
struct ReferenceLibraryToolLayerTests {

    // MARK: - Helpers

    /// An actor over a store the test keeps a handle on (= the store is
    /// the actor's own dependency, so the test can read back what the
    /// actor wrote).
    private static func makeActor() throws -> (ReferenceLibraryActor, FileSystemReferenceStore) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-ref-layer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
        return (ReferenceLibraryActor(referenceStore: store), store)
    }

    private static func storedLayers(_ store: FileSystemReferenceStore) -> [ReferenceLayer] {
        ((try? store.loadAllReferences()) ?? []).map(\.layer)
    }

    // MARK: - The default

    @Test("a create with no layer lands in the user-facing layer")
    func createDefaultsToTheUserFacingLayer() async throws {
        let (actor, store) = try Self.makeActor()
        let payload = try await actor.execute(input: """
        {"action":"create","title":"Ming tax system","body":"# Ming tax\\n\\nKey concepts.","tags":["tax"]}
        """)
        #expect(payload.contains("\"ok\":true"), "the create must succeed: \(payload)")

        let layers = Self.storedLayers(store)
        #expect(layers.count == 1, "the reference must be stored")
        #expect(
            layers[0] == .layerEntities,
            "a create with no layer must land in the layer the user can see; = got \(layers[0])"
        )
    }

    @Test("an upsert with no layer lands in the user-facing layer")
    func upsertDefaultsToTheUserFacingLayer() async throws {
        let (actor, store) = try Self.makeActor()
        let payload = try await actor.execute(input: """
        {"action":"upsert","title":"Beijing history","body":"# Beijing\\n\\nCity history.","tags":["history"]}
        """)
        #expect(payload.contains("\"ok\":true"), "the upsert must succeed: \(payload)")

        let layers = Self.storedLayers(store)
        #expect(layers.count == 1, "the reference must be stored")
        #expect(
            layers[0] == .layerEntities,
            "an upsert with no layer must land in the layer the user can see; = got \(layers[0])"
        )
    }

    // MARK: - The escape hatch

    @Test("a caller that asks for the raw layer still gets it")
    func explicitRawLayerIsHonoured() async throws {
        let (actor, store) = try Self.makeActor()
        let payload = try await actor.execute(input: """
        {"action":"create","title":"Source material","body":"# Source\\n\\nRaw.","layer":"raw"}
        """)
        #expect(payload.contains("\"ok\":true"), "the create must succeed: \(payload)")

        let layers = Self.storedLayers(store)
        #expect(layers.count == 1, "the reference must be stored")
        #expect(
            layers[0] == .layerRaw,
            "an explicit layer must be honoured; = got \(layers[0])"
        )
    }

    // MARK: - The reason

    /// The layer that matters is the one the user's surfaces read.
    ///
    /// A default that lands somewhere no surface reads is a default
    /// that loses the document. This pins WHICH layer that is, so a
    /// future change to the default is caught here rather than by a
    /// user reporting a missing document.
    @Test("the user-facing surfaces read the entities layer, and the raw layer is not one of them")
    func theUserFacingLayerIsEntities() {
        #expect(ReferenceLayer.layerEntities.isUserFacing,
                "the entities layer is the user-facing one")
        #expect(!ReferenceLayer.layerRaw.isUserFacing,
                "the raw layer is the internal ingestion one")
    }
}
