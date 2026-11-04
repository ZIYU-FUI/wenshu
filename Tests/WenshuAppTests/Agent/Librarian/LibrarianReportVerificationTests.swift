//
//  Tests/Agent/Librarian/LibrarianReportVerificationTests.swift · Wenshu
//
//  The librarian's report is checked against the corpus.
//
//  Why this suite exists (= the gap it closes):
//
//  The librarian writes the corpus with a tool, = so the tool's call
//  is the only thing that puts a document there. = A report that
//  says a document landed is the MODEL's word for it. = And the
//  model can be wrong in two ways that matter:
//
//  - It can say it landed a document it never wrote. = The user
//    reads "landed two documents" = and believes there are two.
//  - It can write a document into the RAW layer, = which the user
//    cannot see, = and say it landed it. = The report was true and
//    the document was still invisible.
//
//  So the report is checked against the corpus, = and the check is
//  printed apart from the model's own words. = A report that says
//  "landed two" and then says "the library holds one of them, = and
//  the other is not there" is a report the user can act on.
//
//  What is pinned here:
//
//  1. A document the corpus holds, = in a layer the user sees, = is
//     reported as there.
//  2. A document the corpus does NOT hold is reported as NOT there,
//     even when the model said it landed.
//  3. A document the corpus holds in the RAW layer is reported as
//     there AND as invisible, = because the user cannot act on it.
//  4. The titles are matched by the corpus's own rule, = so a
//     document written under a slightly different spelling is found
//     and not reported missing.
//  5. Without a way to read the corpus, = the report is the model's
//     words and nothing more.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The librarian's report is checked against the corpus")
struct LibrarianReportVerificationTests {
    // MARK: - The helpers

    /// A report the model wrote: = two documents, = both said to
    /// have landed.
    private static let reportJSON = """
    {"landed": 2, "documents": [
      {"title": "Ming tax system", "id": "11111111-1111-1111-1111-111111111111", "action": "created"},
      {"title": "Ming tax codes", "id": "22222222-2222-2222-2222-222222222222", "action": "created"}
    ], "notes": []}
    """

    /// The documents the corpus holds.
    private static func corpus(_ references: [Reference]) -> [Reference] {
        references
    }

    private static func reference(
        title: String,
        layer: ReferenceLayer = .layerEntities
    ) -> Reference {
        Reference(
            title: title,
            source: "a source",
            layer: layer,
            category: nil,
            tags: [],
            entityType: .other,
            summary: "A summary."
        )
    }

    /// A handle, = for the formatter.
    private static func handle(agentName: String) -> BackgroundDelegationHandle {
        BackgroundDelegationHandle(
            id: "run-verification",
            agentName: agentName,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )
    }

    // MARK: - The check

    @Test("a document the corpus holds is reported as there")
    func aDocumentTheCorpusHoldsIsReportedAsThere() {
        guard case let .report(_, documents) = LibrarianReport.parse(Self.reportJSON) else {
            Issue.record("expected a report")
            return
        }
        let held = Self.corpus([Self.reference(title: "Ming tax system")])

        let verifications = LibrarianReport.verify(documents, against: held)

        #expect(verifications.count == 2, "every document the report named is checked")
        #expect(verifications.first?.title == "Ming tax system")
        #expect(verifications.first?.actual == .presentInVisibleLayer,
                "a document in a layer the user sees is there")
    }

    @Test("a document the corpus does not hold is reported as NOT there")
    func aDocumentTheCorpusDoesNotHoldIsReportedAsNotThere() {
        guard case let .report(_, documents) = LibrarianReport.parse(Self.reportJSON) else {
            Issue.record("expected a report")
            return
        }
        // The corpus holds neither of them, = and the model said both
        // landed. = That is the case the check exists for.
        let held = Self.corpus([])

        let verifications = LibrarianReport.verify(documents, against: held)

        #expect(verifications.allSatisfy { $0.actual == .absent },
                "a document the corpus does not hold is not there, = whatever the model said")
    }

    @Test("a document in the raw layer is reported as there AND as invisible")
    func aDocumentInTheRawLayerIsReportedAsInvisible() {
        guard case let .report(_, documents) = LibrarianReport.parse(Self.reportJSON) else {
            Issue.record("expected a report")
            return
        }
        let held = Self.corpus([
            Self.reference(title: "Ming tax system", layer: .layerRaw),
        ])

        let verifications = LibrarianReport.verify(documents, against: held)

        #expect(verifications.first?.actual == .presentInRawLayer,
                "the document IS there, = but in the layer the user cannot see")
        #expect(verifications.first?.actual != .presentInVisibleLayer,
                "and it is not reported as something the user can act on")
    }

    @Test("the titles are matched by the corpus's own rule")
    func theTitlesAreMatchedByTheCorpusRule() {
        guard case let .report(_, documents) = LibrarianReport.parse(Self.reportJSON) else {
            Issue.record("expected a report")
            return
        }
        // The corpus's rule: = trimmed, = case-insensitive, =
        // whitespace-collapsed. = A document written under a
        // different spelling is the same document, = and reporting it
        // missing would be the check lying.
        let held = Self.corpus([Self.reference(title: "  ming  TAX   system ")])

        let verifications = LibrarianReport.verify(documents, against: held)

        #expect(verifications.first?.actual == .presentInVisibleLayer,
                "the same title under another spelling is the same document")
    }

    // MARK: - What the user reads

    @Test("the report says which documents the corpus does not hold")
    func theReportSaysWhichDocumentsTheCorpusDoesNotHold() async {
        let formatted = await SubAgentResultFormatter.format(
            handle: Self.handle(agentName: SubAgentRoleRegistry.librarian.slug),
            text: Self.reportJSON,
            readingLibrary: { [] }
        )

        #expect(formatted.text.contains("NOT in the library"),
                "the user must be told that a document did not land")
        #expect(formatted.text.contains("Ming tax system"),
                "and which document it was")
    }

    @Test("the report says when a document is in a layer the user cannot see")
    func theReportSaysWhenADocumentIsInvisible() async {
        let formatted = await SubAgentResultFormatter.format(
            handle: Self.handle(agentName: SubAgentRoleRegistry.librarian.slug),
            text: Self.reportJSON,
            readingLibrary: {
                [Self.reference(title: "Ming tax system", layer: .layerRaw)]
            }
        )

        #expect(formatted.text.contains("raw layer"),
                "the user must be told the document is where they cannot see it")
        #expect(formatted.text.contains("cannot see"),
                "and the report must say that in words")
    }

    @Test("without a way to read the corpus, the report is the model's words and nothing more")
    func withoutTheCorpusTheReportIsTheModelsWords() async {
        let formatted = await SubAgentResultFormatter.format(
            handle: Self.handle(agentName: SubAgentRoleRegistry.librarian.slug),
            text: Self.reportJSON
        )

        #expect(!formatted.text.contains("NOT in the library"),
                "nothing may be claimed about the corpus that was not read")
        #expect(!formatted.text.contains("Checked against the library"),
                "and the report must not pretend the corpus was checked")
        #expect(formatted.text.contains("landed 2 document(s)"),
                "the model's own claim is still what it says")
    }

    // MARK: - The wiring

    @MainActor
    @Test("the delivery checks the report against the corpus it was given")
    func theDeliveryChecksTheReportAgainstTheCorpusItWasGiven() async throws {
        // The formatter's own tests call the formatter, = so they say
        // nothing about whether the DELIVERY hands it a way to read
        // the corpus. = A delivery that dropped the reader would
        // leave every one of them green, = and the report the user
        // reads would be the model's words again.
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(
            repository: repository,
            libraryReading: { [Self.reference(title: "Ming tax system")] }
        )

        let handle = BackgroundDelegationHandle(
            id: "run-wiring",
            agentName: SubAgentRoleRegistry.librarian.slug,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )
        _ = await delivery.deliver(handle: handle, result: Self.reportJSON)

        let content = try #require(repository.appended.first?.content)
        #expect(content.contains("Checked against the library"),
                "the delivery must check the report before it lands in the conversation")
        #expect(content.contains("Ming tax system"),
                "and the check must say what the corpus holds")
    }

    @MainActor
    @Test("a delivery with no way to read the corpus says nothing about it")
    func aDeliveryWithNoCorpusSaysNothingAboutIt() async throws {
        let repository = RecordingChatRepository()
        let delivery = SubAgentResultDelivery(repository: repository)

        let handle = BackgroundDelegationHandle(
            id: "run-no-corpus",
            agentName: SubAgentRoleRegistry.librarian.slug,
            userMessage: "import something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )
        _ = await delivery.deliver(handle: handle, result: Self.reportJSON)

        let content = try #require(repository.appended.first?.content)
        #expect(!content.contains("Checked against the library"),
                "nothing may be claimed about the corpus that was not read")
    }
}
