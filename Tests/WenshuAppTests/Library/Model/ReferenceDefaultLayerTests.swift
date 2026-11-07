//
//  ReferenceDefaultLayerTests.swift
//
//  Where a reference lands when nobody says.
//
//  **⇒ The root of "the user cannot see these documents" was still
//  there.** = `Reference.init`'s default layer was `.layerRaw` (= the
//  layer the user CANNOT browse), = so every construction that did not
//  name a layer landed there. = The writer's default was fixed (= the
//  tool writes `entities`), = and the test fixture was corrected (=
//  it now names the layer it means), = **⇒ but the MODEL's default
//  was still raw.** = Changing a model default is not a side effect
//  of a count fix, = so it is its own piece of work, = and this is
//  that piece.
//
//  Coverage:
//    - the model's default layer is the layer the user can browse
//    - the writer's default layer is the SAME one (= one answer, = not
//      two that disagree)
//    - a row persisted under an unknown layer still decodes (= the
//      graceful migration path, = and it is NOT the default)
//    - a row persisted under the entities layer survives the round trip
//    - no production construction relies on the default (= so the
//      change moves no production document, = and the next one that
//      forgets is a visible choice)
//
//  Q112: 1 source + 1 test per ticket
//  (= Reference.swift + this file).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("A reference lands where the user can see it")
struct ReferenceDefaultLayerTests {

    // MARK: - The model's default

    @Test("the model's default layer is the layer the user can browse")
    func theModelDefaultIsTheBrowsableLayer() {
        let reference = Reference(title: "A document")
        #expect(reference.layer == .layerEntities,
                "a reference that does not name a layer must land where the user can browse it")
        #expect(reference.layer.isUserFacing,
                "the default layer must be one the user can see")
    }

    @Test("the writer's default layer is the SAME one (= one answer)")
    func theWritersDefaultIsTheSameLayer() throws {
        // **⇒ The tool writes `entities`** (= the fix that already
        // landed), = and the MODEL now says the same thing. = Two
        // defaults that disagree are how a document ends up written
        // in one place and shown in another.
        let toolProtocol = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Agent/Service/ReferenceLibraryActor+ToolProtocol.swift"
            ),
            encoding: .utf8
        )
        #expect(toolProtocol.contains("\"entities\""),
                "the tool must write the entities layer (= the layer the user browses)")

        // And the store's own write path defaults to the same layer.
        let store = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Library/Service/FileSystemReferenceStore+FileSystem.swift"
            ),
            encoding: .utf8
        )
        #expect(store.contains("layer: ReferenceLayer = .layerEntities"),
                "the store's write path must default to the entities layer (= the model and the writer must say the same thing)")
    }

    // MARK: - The graceful migration path

    @Test("a row persisted under an unknown layer still decodes")
    func anUnknownLayerStillDecodes() throws {
        // **⇒ The graceful migration path is NOT the default.** = A row
        // persisted under a layer the app no longer has must not throw
        // (= one unknown value would fail the whole index decode, =
        // and the library would read as empty). = It falls back to the
        // raw layer, = because a row nobody can place is a document
        // the app does not claim.
        let json = """
        [{"id":"B5F8E3D6-1234-5678-9ABC-DEF012345678","title":"A document","layer":"layerWhatever",\
        "tags":[],"entityType":"other","summary":"","characterRefIds":[],"worldRefIds":[],\
        "bookRefIds":[],"createdAt":0,"updatedAt":0}]
        """
        let decoded = try JSONDecoder().decode([Reference].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded.first?.layer == .layerRaw,
                "a row under an unknown layer falls back to the raw layer (= the app does not claim it)")
    }

    @Test("a row persisted under the entities layer survives the round trip")
    func aPersistedLayerSurvives() throws {
        let json = """
        [{"id":"B5F8E3D6-1234-5678-9ABC-DEF012345678","title":"A document","layer":"layerEntities",\
        "tags":[],"entityType":"other","summary":"","characterRefIds":[],"worldRefIds":[],\
        "bookRefIds":[],"createdAt":0,"updatedAt":0}]
        """
        let decoded = try JSONDecoder().decode([Reference].self, from: Data(json.utf8))
        #expect(decoded.first?.layer == .layerEntities)
    }

    // MARK: - No production document relies on the default

    @Test("no production construction relies on the default layer")
    func noProductionConstructionReliesOnTheDefault() throws {
        // **⇒ The default change moves NO production document.** = The
        // change is a guard for the NEXT construction that forgets, =
        // and this test says so (= so a future construction that
        // relies on the default is a visible choice, = not an
        // accident).
        //
        // **⇒ The scan reads the file as TEXT, = not line by line** (= a
        // construction spans lines, = and a line-by-line scan cannot see
        // the `layer:` that a later line carries).
        let root = SourceLocator.path("Sources/WenshuApp")
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: URL(fileURLWithPath: root),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            Issue.record("the source tree must be walkable")
            return
        }
        var offenders: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let content = try String(contentsOf: url, encoding: .utf8)
            // The comments are stripped first (= a comment that names
            // = `Reference(` is not a construction).
            let code = content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.hasPrefix("//") ? "" : String($0) }
                .joined(separator: "\n")
            var searchStart = code.startIndex
            while let range = code.range(of: "Reference(", range: searchStart..<code.endIndex) {
                searchStart = range.upperBound
                let before = code[code.index(before: range.lowerBound)]
                // `WSReference(` is a different type (= the row), = and
                // `Reference(` as part of a longer identifier is not
                // the model either.
                guard !before.isLetter, !before.isNumber, before != "_" else { continue }
                // The call's own argument list.
                var depth = 1
                var block = ""
                var index = range.upperBound
                while index < code.endIndex {
                    let character = code[index]
                    block.append(character)
                    if character == "(" { depth += 1 }
                    if character == ")" {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    index = code.index(after: index)
                }
                guard !block.contains("layer:") else { continue }
                let line = code[..<range.lowerBound].split(separator: "\n").count
                let path = url.path.replacingOccurrences(of: "\(root)/", with: "")
                offenders.append("\(path):\(line)")
            }
        }
        #expect(offenders.isEmpty,
                "every production reference must name its layer (= the default is a guard, = not a place to put a document): \(offenders)")
    }
}
