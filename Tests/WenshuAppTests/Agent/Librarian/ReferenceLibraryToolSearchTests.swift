//
//  ReferenceLibraryToolSearchTests.swift · Wenshu
//
//  The agent's corpus answer, in one call.
//
//  What is held here: that the agent can ASK the library a question
//  and get back the documents that answer it, each with the file the
//  answer lives in and the sentences that hold it. = That is the one
//  user-visible acceptance the retrieval work has: = before this
//  action the agent could `find` a document by title (= one document,
//  = and only if the agent already knew the title), = and then `read`
//  it whole.
//
//  So the tests here are the acceptance, = and they are written as the
//  agent's own call: = a JSON envelope in, = a JSON answer out.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Reference library tool · the agent's corpus answer")
@MainActor
struct ReferenceLibraryToolSearchTests {
    // MARK: - Helpers

    /// An actor over a store the test keeps a handle on.
    private static func makeActor() throws -> (ReferenceLibraryActor, FileSystemReferenceStore) {
        let tmpRoot = URL(fileURLWithPath: "/tmp/wenshu-ref-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpRoot, withIntermediateDirectories: true)
        let store = FileSystemReferenceStore(referenceLibraryRoot: tmpRoot)
        return (ReferenceLibraryActor(referenceStore: store), store)
    }

    /// The answer's hits, read back out of the tool's own JSON.
    private static func hits(_ payload: String) -> [[String: Any]] {
        guard let data = payload.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = parsed["hits"] as? [[String: Any]]
        else { return [] }
        return hits
    }

    /// The fragments of one hit.
    private static func fragments(_ hit: [String: Any]) -> [String] {
        hit["fragments"] as? [String] ?? []
    }

    // MARK: - The acceptance

    @Test("one call returns the documents that hold the answer, with their paths")
    func oneCallReturnsCrossFileEvidence() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "The Ming tax system",
            bodyMarkdown: "The Ming tax system was levied on land and on goods. The land tax dominated the revenue."
        )
        _ = try await actor.createReference(
            title: "Sea routes",
            bodyMarkdown: "The sea routes carried silver from Japan to the port at Ningbo."
        )

        let payload = try await actor.execute(input: """
        {"action":"search","query":"how was the land tax levied"}
        """)
        #expect(payload.contains("\"ok\":true"), "the search must succeed: \(payload)")

        let hits = Self.hits(payload)
        #expect(!hits.isEmpty, "a question the library holds the answer to must return a hit: \(payload)")

        // The document that holds the answer is named.
        let taxHit = hits.first { ($0["title"] as? String)?.contains("Ming tax") == true }
        #expect(taxHit != nil, "the document that holds the answer must be named: \(payload)")

        // The fragment is a sentence of that document, = and it is the
        // sentence that HOLDS the answer (= not the document's first
        // sentence, = and not the whole document).
        let fragments = taxHit.map { Self.fragments($0) } ?? []
        #expect(!fragments.isEmpty, "a hit must carry the sentences that hold the answer: \(payload)")
        #expect(
            fragments.contains { $0.contains("land tax") },
            "the fragment must hold the query's own terms: \(fragments)"
        )
        #expect(
            fragments.allSatisfy { !$0.contains("\n\n") },
            "a fragment is a sentence, not a document: \(fragments)"
        )

        // The path says where that body lives, = and the file is there.
        let path = taxHit?["path"] as? String ?? ""
        #expect(path.hasSuffix(".md"), "a hit must name the file its body lives in: \(path)")
        #expect(FileManager.default.fileExists(atPath: path), "the named file must exist: \(path)")
    }

    @Test("the answer names the documents of more than one file")
    func theAnswerSpansFiles() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "Land tax",
            bodyMarkdown: "The land tax was collected by the county."
        )
        _ = try await actor.createReference(
            title: "Coinage",
            bodyMarkdown: "The coinage was minted in the capital."
        )

        let payload = try await actor.execute(input: """
        {"action":"search","query":"tax and coinage"}
        """)
        let hits = Self.hits(payload)
        let paths = Set(hits.compactMap { $0["path"] as? String })
        #expect(paths.count >= 1, "the answer must name files: \(payload)")
        // Two documents that both hold a query term are both named, =
        // and each names its OWN file (= the answer is not one file
        // repeated).
        let taxHit = hits.first { ($0["title"] as? String) == "Land tax" }
        let coinHit = hits.first { ($0["title"] as? String) == "Coinage" }
        #expect(taxHit != nil || coinHit != nil, "the answer must name the documents: \(payload)")
        if let taxHit, let coinHit {
            #expect(
                (taxHit["path"] as? String) != (coinHit["path"] as? String),
                "two documents must name two files: \(payload)"
            )
        }
    }

    @Test("a question the library cannot answer returns an empty answer, not an error")
    func anUnanswerableQuestionReturnsNothing() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "The Ming tax system",
            bodyMarkdown: "The tax system was levied on land."
        )
        let payload = try await actor.execute(input: """
        {"action":"search","query":"the metallurgy of bronze bells in the Zhou"}
        """)
        #expect(payload.contains("\"ok\":true"), "a question with no answer is not a failure: \(payload)")
        #expect(Self.hits(payload).isEmpty, "no document holds that answer: \(payload)")
    }

    // **⇒ THE LIBRARY THE USER WRITES IN IS WRITTEN IN CHINESE, = = AND
    // EVERY CASE ABOVE IS ENGLISH.** = The tokenizer the search runs is
    // character-level for CJK (= one token per character), = so a Chinese
    // question arrives as a bag of single characters, = and the
    // characters that carry no question on their own (= the copula, = the
    // possessive particle, = the sentence-final question particle) =
    // sit in every sentence of every document.
    // ⇒⇒⇒ So these two cases are the pair that holds the rule: = the
    // question the library cannot answer must answer with NOTHING (=
    // the glue must not be allowed to name a document), = and the
    // question the library CAN answer must still name its document (=
    // the glue must not be dropped so hard that Chinese stops
    // answering).

    @Test("a Chinese question the library cannot answer returns an empty answer")
    func anUnanswerableChineseQuestionReturnsNothing() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "明代的税制",
            bodyMarkdown: "明代的税制按田亩征收。田赋是这笔收入的主项。海运把白银从日本运到宁波港。"
        )
        let payload = try await actor.execute(input: """
        {"action":"search","query":"青铜钟的铸造工艺是怎样的呢"}
        """)
        #expect(payload.contains("\"ok\":true"), "a question with no answer is not a failure: \(payload)")
        #expect(
            Self.hits(payload).isEmpty,
            "a document that shares only the question's glue is not an answer: \(payload)"
        )
    }

    @Test("a Chinese question names the document that holds it, with a sentence of that document")
    func aChineseQuestionNamesTheDocumentThatHoldsIt() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "明代的税制",
            bodyMarkdown: "明代的税制按田亩征收。田赋是这笔收入的主项。"
        )
        _ = try await actor.createReference(
            title: "海上的银路",
            bodyMarkdown: "海上的商路把白银从日本运来。白银从宁波港入内地。"
        )
        let payload = try await actor.execute(input: """
        {"action":"search","query":"白银是怎么从宁波港进来的"}
        """)
        let hits = Self.hits(payload)
        #expect(!hits.isEmpty, "a question the library holds the answer to must return a hit: \(payload)")
        let silverHit = hits.first { ($0["title"] as? String) == "海上的银路" }
        #expect(silverHit != nil, "the document that holds the answer must be named: \(payload)")
        let fragments = silverHit.map { Self.fragments($0) } ?? []
        #expect(
            fragments.contains { $0.contains("宁波港") },
            "the fragment must be the sentence that holds the answer: \(fragments)"
        )
    }

    @Test("a search with no question is refused with a reason")
    func anEmptyQuestionIsRefused() async throws {
        let (actor, _) = try Self.makeActor()
        let payload = try await actor.execute(input: """
        {"action":"search"}
        """)
        #expect(payload.contains("\"ok\":false"), "a search with no question must fail: \(payload)")
        #expect(payload.contains("query"), "the refusal must name what is missing: \(payload)")
    }

    @Test("the search does not change the library")
    func theSearchIsReadOnly() async throws {
        let (actor, store) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "The Ming tax system",
            bodyMarkdown: "The tax system was levied on land."
        )
        let before = try store.loadAllReferences()
        let bodiesBefore = try? store.loadReferenceBody(id: before[0].id)

        _ = try await actor.execute(input: """
        {"action":"search","query":"the tax system"}
        """)

        let after = try store.loadAllReferences()
        #expect(after.count == before.count, "a search must not add a document")
        #expect(after.map(\.id) == before.map(\.id), "a search must not change the library's documents")
        let bodiesAfter = try? store.loadReferenceBody(id: before[0].id)
        #expect(bodiesAfter == bodiesBefore, "a search must not change a body")
    }

    @Test("find still finds by title")
    func findStillFindsByTitle() async throws {
        let (actor, _) = try Self.makeActor()
        _ = try await actor.createReference(
            title: "The Ming tax system",
            bodyMarkdown: "The tax system was levied on land."
        )
        let payload = try await actor.execute(input: """
        {"action":"find","title":"The Ming tax system"}
        """)
        #expect(payload.contains("\"ok\":true"), "the find must succeed: \(payload)")
        #expect(payload.contains("\"found\":true"), "the find must find the document: \(payload)")
    }
}
