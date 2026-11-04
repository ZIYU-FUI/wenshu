//
//  Tests/Agent/LibrarianReportTests.swift · Wenshu
//
//  Reading what the librarian reported.
//
//  Why this test exists (= the gap it closes):
//
//  The librarian's prompt asks for a JSON object, = and nothing ever
//  read it. = The user saw the raw string the model produced, = and
//  the `LibrarianResult` type that was supposed to carry the run's
//  meaning had no producer at all.
//
//  What is pinned here:
//
//  1. A report is read: = which documents, = what happened to each,
//     = which were already there.
//  2. A report wrapped in prose or in a code fence is still read, =
//     because a model writes either way.
//  3. A text that is NOT a report is not read as "nothing landed". =
//     It is read as a failure, = and the user is shown what the run
//     actually said.
//  4. The count comes from the report. = If the report says two
//     documents landed and names one, = the result says so, = rather
//     than quietly believing the model.
//  5. A run that declined says why.
//  6. Every other agent's prose is left alone.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The librarian's report is read")
struct LibrarianReportTests {

    @Test("a report names the documents it landed")
    func readsTheLandedDocuments() throws {
        let text = """
        {"landed": 2, "documents": [
          {"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"},
          {"title": "Cao Cao", "id": "22222222-2222-2222-2222-222222222222", "action": "extended"}
        ], "notes": []}
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.documentIDs.count == 2)
        #expect(result.documentIDs.first?.uuidString == "11111111-1111-1111-1111-111111111111")
        #expect(result.duplicateTitles.isEmpty)
    }

    @Test("a document that was already there is reported as a duplicate")
    func readsTheDuplicates() throws {
        let text = """
        {"landed": 1, "documents": [
          {"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "duplicate"}
        ]}
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.duplicateTitles == ["Red Cliff"])
    }

    @Test("a report wrapped in a code fence is still read")
    func readsAFencedReport() throws {
        let text = """
        Here is the report:
        ```json
        {"landed": 1, "documents": [{"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}]}
        ```
        That is all.
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.documentIDs.count == 1)
    }

    @Test("a report surrounded by prose is still read")
    func readsAReportInProse() throws {
        let text = """
        I filed one document. {"landed": 1, "documents": [{"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}]} Let me know.
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.documentIDs.count == 1)
    }

    @Test("a text that is not a report is not read as an empty success")
    func anUnreadableTextIsNotAnEmptySuccess() throws {
        guard case .unreadable(let raw) = LibrarianReport.parse("I could not finish the task.") else {
            Issue.record("expected an unreadable text")
            return
        }
        #expect(raw == "I could not finish the task.")
    }

    @Test("a report that says two and names one is reported, not believed")
    func aMiscountIsReported() throws {
        let text = """
        {"landed": 2, "documents": [{"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}]}
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.errorMessage != nil, "the mismatch must be reported")
        #expect(result.errorMessage?.contains("said 2") == true)
    }

    @Test("a run that declined says why")
    func readsADeclinedRun() throws {
        let text = #"{"landed": false, "reason": "out of scope"}"#

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.skipped == "out of scope")
        #expect(result.documentIDs.isEmpty)
    }

    @Test("the notes reach the user")
    func readsTheNotes() throws {
        let text = """
        {"landed": 1, "documents": [{"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}], "notes": ["the body was empty"]}
        """

        guard case let .report(result, _) = LibrarianReport.parse(text) else {
            Issue.record("expected a report")
            return
        }
        #expect(result.skipped == "the body was empty")
    }

    // MARK: - The formatter

    @Test("the librarian's result reads as a report, not as a JSON blob")
    func theLibrarianResultReadsAsAReport() async {
        let text = """
        {"landed": 1, "documents": [{"title": "Red Cliff", "id": "11111111-1111-1111-1111-111111111111", "action": "created"}]}
        """

        let formatted = await SubAgentResultFormatter.format(
            handle: Self.formatterHandle(agentName: "librarian"),
            text: text
        )

        #expect(formatted.text.contains("1 document"))
        #expect(formatted.text.contains("Red Cliff") == false, "the report names the count, not the JSON")
        #expect(formatted.result != nil)
    }

    @Test("every other agent's prose is left alone")
    func otherAgentsProseIsLeftAlone() async {
        let prose = "The sources say the battle was in 208."

        let formatted = await SubAgentResultFormatter.format(
            handle: Self.formatterHandle(agentName: "researcher"),
            text: prose
        )

        #expect(formatted.text == prose)
        #expect(formatted.result == nil)
    }

    @Test("a librarian run whose text cannot be read shows what it said")
    func anUnreadableLibrarianTextShowsWhatItSaid() async {
        let raw = "The library is not reachable."

        let formatted = await SubAgentResultFormatter.format(
            handle: Self.formatterHandle(agentName: "librarian"),
            text: raw
        )

        #expect(formatted.text == raw)
    }

    /// A handle, = for the formatter.
    private static func formatterHandle(agentName: String) -> BackgroundDelegationHandle {
        BackgroundDelegationHandle(
            id: "run-format",
            agentName: agentName,
            userMessage: "do something",
            scope: AgentScope(sessionID: SessionID(rawValue: "session-a"), bookID: nil)
        )
    }
}
