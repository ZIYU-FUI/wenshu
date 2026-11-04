//
//  RawLayerGovernanceTests.swift
//
//  The raw layer, = and the user's ability to know it is there.
//
//  Why: the library has two layers. = The entities layer is what the
//  grid shows. = The raw layer holds the originals, = and NOTHING in
//  the app listed it: = the agent could write there, = the librarian's
//  report could name a document there, = and the user had no way to
//  find out that the document existed. = A report that says "landed"
//  about a document the user cannot open is a report the user cannot
//  act on.
//
//  Three things are held here, = and each one is a way the app used to
//  hide the raw layer:
//
//  1. The librarian's curate report NAMES the raw-layer documents, =
//     because a count tells the user that something is there and the
//     names tell him WHICH.
//  2. The report says what the raw layer IS FOR, = because a user who
//     finds a document he cannot browse has to be able to tell
//     whether it was lost (= a bug) = or kept on purpose (= the
//     design).
//  3. The sidebar's count is of what the user can SEE. = The grid
//     shows the entities layer only, = so a count that included the
//     raw layer put a number on a row that opened to fewer documents
//     than the number said.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The raw layer is governed, not hidden")
struct RawLayerGovernanceTests {
    /// A document in the given layer.
    private static func document(
        title: String,
        layer: ReferenceLayer,
        tags: Set<String> = [],
        summary: String = ""
    ) -> Reference {
        Reference(
            title: title,
            layer: layer,
            tags: tags,
            summary: summary
        )
    }

    // MARK: - 1. The report names them

    @Test("The report names the documents in the raw layer")
    func reportNamesRawDocuments() {
        let report = LibrarianCurator().curate(references: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw),
            Self.document(title: "Cao Cao", layer: .layerEntities),
        ])
        #expect(report.rawLayerDocuments == ["The Ming tax roll"])
    }

    @Test("The report says how many documents are in the layer the user browses")
    func reportCountsVisibleDocuments() {
        let report = LibrarianCurator().curate(references: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw),
            Self.document(title: "Cao Cao", layer: .layerEntities),
            Self.document(title: "Red Cliff", layer: .layerEntities),
        ])
        #expect(report.visibleLayerDocuments == 2)
    }

    @Test("The raw-layer documents are named in the text the user reads")
    func textNamesRawDocuments() {
        let report = LibrarianCurator().curate(references: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw),
        ])
        let text = LibrarianCurationRunner.text(for: report)
        #expect(text.contains("The Ming tax roll"))
    }

    @Test("A library with nothing in the raw layer does not claim to have some")
    func noRawLayerMeansNoRawSection() {
        let report = LibrarianCurator().curate(references: [
            Self.document(title: "Cao Cao", layer: .layerEntities),
        ])
        #expect(report.rawLayerDocuments.isEmpty)
        let text = LibrarianCurationRunner.text(for: report)
        #expect(!text.contains("In the raw layer"))
    }

    // MARK: - 2. The layer says what it is for

    @Test("The raw layer says it holds the originals")
    func rawLayerStatesItsPurpose() {
        let purpose = ReferenceLayer.layerRaw.purpose
        #expect(purpose.contains("originals"))
    }

    @Test("The raw layer says the originals are kept FOR ingestion")
    func rawLayerStatesWhyItIsKept() {
        // Both halves, = because a user who finds a document he cannot
        // browse has to be able to tell whether it was lost or kept on
        // purpose. = "the originals" alone does not say that; = it says
        // what they ARE, = not what they are FOR.
        let purpose = ReferenceLayer.layerRaw.purpose
        #expect(purpose.contains("ingestion"))
    }

    @Test("The entities layer says it holds what the user browses")
    func entitiesLayerStatesItsPurpose() {
        let purpose = ReferenceLayer.layerEntities.purpose
        #expect(purpose.contains("browse"))
    }

    @Test("The text tells the user the raw layer is not shown in the grid")
    func textSaysTheRawLayerIsNotShown() {
        let report = LibrarianCurator().curate(references: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw),
        ])
        let text = LibrarianCurationRunner.text(for: report)
        // The LINE that names the raw layer, = and not the whole text:
        // the summary line above also says the grid does not show the
        // raw layer, = so a whole-text assertion would be satisfied by
        // the wrong occurrence (= the very trap a mutation hides
        // behind).
        let rawSection = text
            .split(separator: "\n")
            .first { $0.hasPrefix("In the raw layer") }
        #expect(rawSection != nil)
        #expect(rawSection?.contains("does not show") == true)
    }

    // MARK: - 3. The count is of what the user can see

    @Test("The sidebar's tag count is of the documents the grid can show")
    @MainActor
    func sidebarCountCountsVisibleDocuments() {
        // One visible document and one raw document, = both carrying
        // the same tag. = The grid shows one, = so the count says one.
        let rows = SidebarService.groupedTagRows(for: [
            Self.document(title: "Cao Cao", layer: .layerEntities, tags: ["Three Kingdoms"]),
            Self.document(title: "The Ming tax roll", layer: .layerRaw, tags: ["Three Kingdoms"]),
        ])
        let count: String? = rows
            .flatMap { $0.children ?? [] }
            .compactMap { node -> String? in
                guard node.kind == .tag else { return nil }
                return node.subtitle
            }
            .first
        #expect(count == "1 items")
    }

    @Test("A tag carried only by raw documents does not put a row on the sidebar")
    @MainActor
    func rawOnlyTagMakesNoRow() {
        let rows = SidebarService.groupedTagRows(for: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw, tags: ["Taxes"]),
        ])
        let tags = rows.flatMap { $0.children ?? [] }.filter { $0.kind == .tag }
        #expect(tags.isEmpty)
    }
}
