//
//  LibrarianActivationTests.swift · Wenshu
//
//  How a librarian run is asked for.
//
//  The librarian's activation surface is one syntax, = and it has to
//  behave the same way twice: = a retry after a failure must land the
//  same document against the same source, = not a second copy.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("The librarian's activation")
struct LibrarianActivationTests {

    // MARK: - The procedures

    @Test("a mention that names a procedure is a librarian task")
    func aProcedureMakesATask() throws {
        let parsed = LibrarianActivation.parse("import /tmp/a.md")
        let task = try #require({
            if case .task(let t) = parsed { return t }
            return nil
        }())
        #expect(task.procedure == .importDocuments)
        #expect(task.sourcePaths == ["/tmp/a.md"])
        #expect(!task.dryRun)
    }

    @Test("a curate mention is a librarian task")
    func curateMakesATask() throws {
        let parsed = LibrarianActivation.parse("curate")
        guard case .task(let task) = parsed else {
            Issue.record("curate must parse to a task")
            return
        }
        #expect(task.procedure == .curate)
        #expect(task.sourcePaths.isEmpty, "curate works on what is already there")
    }

    @Test("the procedure name is case-insensitive")
    func theProcedureIsCaseInsensitive() throws {
        let parsed = LibrarianActivation.parse("IMPORT /tmp/a.md")
        guard case .task(let task) = parsed else {
            Issue.record("IMPORT must parse to a task")
            return
        }
        #expect(task.procedure == .importDocuments)
    }

    // MARK: - The dry run

    @Test("the dry-run flag is read")
    func theDryRunFlagIsRead() throws {
        let parsed = LibrarianActivation.parse("import /tmp/a.md --dry-run")
        guard case .task(let task) = parsed else {
            Issue.record("the dry run must parse to a task")
            return
        }
        #expect(task.dryRun, "the dry run must be visible on the task")
        #expect(
            task.sourcePaths == ["/tmp/a.md"],
            "the flag must not leak into the sources; = got \(task.sourcePaths)"
        )
    }

    @Test("the dry-run flag may come before the source")
    func theDryRunFlagMayComeFirst() throws {
        let parsed = LibrarianActivation.parse("import --dry-run /tmp/a.md")
        guard case .task(let task) = parsed else {
            Issue.record("the dry run must parse to a task")
            return
        }
        #expect(task.dryRun)
        #expect(task.sourcePaths == ["/tmp/a.md"])
    }

    // MARK: - What is not a librarian task

    @Test("an empty mention is not a librarian task")
    func anEmptyMentionIsNotATask() {
        #expect(LibrarianActivation.parse("") == .notALibrarianTask)
        #expect(LibrarianActivation.parse("   ") == .notALibrarianTask)
    }

    @Test("a mention that names no procedure is not a librarian task")
    func aMentionWithNoProcedureIsNotATask() {
        #expect(LibrarianActivation.parse("整理一下资料") == .notALibrarianTask)
    }

    @Test("a mention that names an unknown procedure says so")
    func anUnknownProcedureSaysSo() {
        #expect(LibrarianActivation.parse("archive /tmp/a.md") == .unknownProcedure("archive"))
    }

    // MARK: - The request id

    @Test("the same inputs produce the same request id")
    func theSameInputsProduceTheSameRequestID() throws {
        let first = LibrarianActivation.parse("import /tmp/a.md")
        let second = LibrarianActivation.parse("import /tmp/a.md")
        guard case .task(let a) = first, case .task(let b) = second else {
            Issue.record("both must parse to tasks")
            return
        }
        #expect(
            a.requestID == b.requestID,
            "the request id is the idempotency key; = a retry must land the same way"
        )
    }

    @Test("different inputs produce different request ids")
    func differentInputsProduceDifferentRequestIDs() throws {
        let first = LibrarianActivation.parse("import /tmp/a.md")
        let second = LibrarianActivation.parse("import /tmp/b.md")
        guard case .task(let a) = first, case .task(let b) = second else {
            Issue.record("both must parse to tasks")
            return
        }
        #expect(a.requestID != b.requestID, "two sources are two requests")
    }

    @Test("the request id names the procedure")
    func theRequestIDNamesTheProcedure() throws {
        let parsed = LibrarianActivation.parse("curate")
        guard case .task(let task) = parsed else {
            Issue.record("curate must parse to a task")
            return
        }
        #expect(
            task.requestID.hasPrefix("curate-"),
            "the id must say which procedure it belongs to; = got \(task.requestID)"
        )
    }

    // MARK: - The surface

    /// The librarian is activated by a mention, = and the mention
    /// parser reads its slugs from the role table. = So the row is
    /// what makes `@librarian` work.
    @Test("the librarian is mentionable")
    func theLibrarianIsMentionable() {
        #expect(
            SubAgentMentionParser.availableSlugs.contains("librarian"),
            "the mention parser reads the role table; = the row is what makes `@librarian` work"
        )
    }

    // MARK: - The round trip

    /// The task text is what carries the procedure to the runner.
    ///
    /// The delegation's task is a string, = so the procedure travels
    /// inside it. = The round trip must be lossless: = the runner has
    /// to know which procedure to run, = and it has to know that the
    /// task was an activation rather than free text.
    @Test("the procedure survives the trip to the runner")
    func theProcedureSurvivesTheRoundTrip() throws {
        for procedure in LibrarianProcedure.allCases {
            let task = LibrarianTask(
                procedure: procedure,
                requestID: "req-1",
                sourcePaths: ["/tmp/a.md"],
                dryRun: false
            )
            let encoded = LibrarianActivation.encodedTask(for: task)
            #expect(
                LibrarianActivation.procedure(fromTaskText: encoded) == procedure,
                "the \(procedure.rawValue) procedure must survive the round trip"
            )
        }
    }

    @Test("the dry run survives the trip to the runner")
    func theDryRunSurvivesTheRoundTrip() throws {
        let task = LibrarianTask(
            procedure: .importDocuments,
            requestID: "req-1",
            sourcePaths: ["/tmp/a.md"],
            dryRun: true
        )
        let encoded = LibrarianActivation.encodedTask(for: task)
        #expect(encoded.contains("--dry-run"), "the dry run must travel with the task")
    }

    @Test("a task that was not an activation carries no procedure")
    func aHandWrittenTaskCarriesNoProcedure() {
        #expect(
            LibrarianActivation.procedure(fromTaskText: "整理一下资料") == nil,
            "free text is not a librarian procedure; = the runner must be able to tell"
        )
    }
}
