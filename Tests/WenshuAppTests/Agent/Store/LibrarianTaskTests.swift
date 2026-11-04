//
//  LibrarianTaskTests.swift · Wenshu
//
//  What the librarian is asked to do.
//
//  The librarian is a procedure runner, = not a chat partner. A
//  procedure runner's contract is that the same task runs the same way
//  twice, = so the contract is stated in values, = not in prose the
//  model interprets.
//
//  These tests pin that the task carries everything a run needs, =
//  and that a result says what happened rather than returning an
//  empty success.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("The librarian task")
struct LibrarianTaskTests {

    // MARK: - The procedures

    @Test("the librarian runs two procedures")
    func theProcedures() {
        #expect(LibrarianProcedure.allCases.count == 2)
        #expect(LibrarianProcedure.importDocuments.rawValue == "import")
        #expect(LibrarianProcedure.curate.rawValue == "curate")
    }

    // MARK: - What a task carries

    @Test("a task names the procedure, the request and the scope")
    func aTaskCarriesWhatARunNeeds() {
        let task = LibrarianTask(
            procedure: .importDocuments,
            requestID: "req-1",
            sourcePaths: ["/tmp/a.md"],
            scope: .referenceLibrary,
            dryRun: true
        )
        #expect(task.procedure == .importDocuments)
        #expect(task.requestID == "req-1")
        #expect(task.sourcePaths == ["/tmp/a.md"])
        #expect(task.scope == .referenceLibrary)
        #expect(task.dryRun, "a dry run must be visible on the task")
    }

    @Test("a curate task carries no source")
    func aCurateTaskCarriesNoSource() {
        let task = LibrarianTask(procedure: .curate, requestID: "req-2")
        #expect(task.sourcePaths.isEmpty, "curate works on what is already there")
        #expect(task.scope == nil, "no scope means the whole library")
    }

    @Test("a task with no request id has no identity")
    func aTaskWithNoRequestIDHasNoIdentity() {
        let task = LibrarianTask(procedure: .curate, requestID: "")
        #expect(task.requestID.isEmpty, "an empty request id means the run cannot be matched to a retry")
    }

    // MARK: - The scopes

    @Test("the scope names a book folder by its book and its folder")
    func theScopeNamesABookFolder() {
        let bookID = UUID()
        let scope = LibrarianScope.bookFolder(bookID: bookID, folder: "world")
        #expect(scope == .bookFolder(bookID: bookID, folder: "world"))
    }

    // MARK: - The result

    @Test("a result that landed nothing says so")
    func aResultThatLandedNothingSaysSo() {
        let result = LibrarianResult()
        #expect(!result.landedAnything)
        #expect(result.errorMessage == nil, "landing nothing is not a failure")
        #expect(result.skipped == nil, "landing nothing without a reason is a silent success")
    }

    @Test("a result names the documents, their layers and the duplicates")
    func aResultNamesWhatLanded() {
        let id = UUID()
        let result = LibrarianResult(
            documentIDs: [id],
            duplicateTitles: ["Ming tax system"],
            layers: [id: "entities"],
            indexed: true,
            archiveTarget: "archives/2026-11-04"
        )
        #expect(result.landedAnything)
        #expect(result.documentIDs == [id])
        #expect(result.duplicateTitles == ["Ming tax system"], "the deduplication report must survive")
        #expect(result.layers[id] == "entities")
        #expect(result.indexed, "the result must say whether the index was updated")
        #expect(result.archiveTarget == "archives/2026-11-04", "the result must say where the snapshot went")
    }

    @Test("a failed result says why")
    func aFailedResultSaysWhy() {
        let result = LibrarianResult(errorMessage: "the source could not be read")
        #expect(result.errorMessage == "the source could not be read")
        #expect(!result.landedAnything)
    }

    @Test("a skipped result says what was skipped and why")
    func aSkippedResultSaysWhy() {
        let result = LibrarianResult(skipped: "dry run")
        #expect(result.skipped == "dry run")
        #expect(result.errorMessage == nil, "a skip is not a failure")
    }
}
