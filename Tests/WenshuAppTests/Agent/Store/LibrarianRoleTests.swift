//
//  LibrarianRoleTests.swift · Wenshu
//
//  The librarian's place in the roster.
//
//  The librarian owns the library: = the documents already in it and
//  the documents about to enter it. That is a boundary, = and a
//  boundary that lives only in a prompt is a request rather than a
//  limit. So the tests here pin the boundary where it can be
//  enforced: = in the tools the role carries.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("The librarian role")
struct LibrarianRoleTests {

    // MARK: - The row

    @Test("the librarian is a row in the table")
    func theLibrarianIsARow() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(role.slug == "librarian")
        #expect(!role.displayLabel.isEmpty, "the row must carry a label")
        #expect(role.dispatch == .llmRun, "the librarian runs the ordinary LLM path")
    }

    @Test("the librarian's prompt names the procedures it runs")
    func thePromptNamesTheProcedures() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(role.prompt.contains("import"), "the prompt must name the import procedure")
        #expect(role.prompt.contains("curate"), "the prompt must name the curate procedure")
        #expect(
            role.prompt.contains("Librarian"),
            "the prompt must say who the role is"
        )
    }

    // MARK: - What the librarian may write

    @Test("the librarian writes the corpus")
    func theLibrarianWritesTheCorpus() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(
            role.toolNames.contains("reference_library"),
            "the librarian must reach the corpus writer"
        )
    }

    @Test("the librarian reads what is already there")
    func theLibrarianReads() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(
            role.toolNames.contains("ReadFile"),
            "a curate run has to see the corpus before it can report on it"
        )
    }

    /// The librarian is the corpus's writer, = and that has to be true
    /// of the TOOLS and not only of the prompt.
    ///
    /// The `file` tool is the general one: = it reads, = it writes, =
    /// it patches, = and it lists. = Its read path has no sandbox
    /// guard at all, = and its write path writes anywhere the process
    /// can reach. = A role that holds it can put its hands on the
    /// user's disk, = which is not what "the librarian files
    /// documents" means, = and a prompt asking the model not to is a
    /// weaker guarantee than a tool that cannot do it.
    ///
    /// `ReadFile` is the read-only half, = with the sandbox
    /// deny-list, = and it reads what the import task names. = So the
    /// librarian reads through it and writes through the corpus.
    @Test("the librarian holds no general file-writing tool")
    func theLibrarianHoldsNoGeneralFileTool() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(
            !role.toolNames.contains("file"),
            "the corpus must be the only thing the librarian can write to"
        )
        #expect(
            !role.toolNames.contains("WriteFile"),
            "the corpus must be the only thing the librarian can write to"
        )
    }

    // MARK: - What the librarian may not do

    @Test("the librarian does not search the web")
    func theLibrarianDoesNotSearch() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(
            !role.toolNames.contains("web_search"),
            "the researcher gathers; = the librarian files"
        )
    }

    @Test("the librarian does not write prose")
    func theLibrarianDoesNotWriteProse() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(
            !role.toolNames.contains("book_chapter"),
            "a chapter is the writer's; = the librarian does not write prose"
        )
        #expect(
            !role.toolNames.contains("book_edit_chapter"),
            "a confirmed chapter is the user's"
        )
    }

    @Test("the librarian does not manage the board or the todos")
    func theLibrarianDoesNotManageTheBoard() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        #expect(!role.toolNames.contains("kanban"))
        #expect(!role.toolNames.contains("todo"))
    }

    /// The corpus has one keeper.
    ///
    /// Two roles can reach the corpus writer, = the librarian and the
    /// researcher. That is deliberate: = the researcher reads the
    /// corpus to know what is already there (= a summary that repeats
    /// a document the user already has is a worse answer than one
    /// that adds to it). What must not happen is BOTH writing, = so
    /// the researcher's prompt says it reports and the librarian's
    /// says it files.
    ///
    /// The rule the corpus depends on is the one the librarian
    /// enforces when it writes: = one document per title. A second
    /// writer with a second rule is how the corpus grew a copy of
    /// everything the user mentioned twice.
    @Test("the librarian's prompt is the one that says it files")
    func theLibrarianIsTheOneThatFiles() throws {
        let librarian = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        let researcher = try #require(SubAgentRoleRegistry.role(forSlug: "researcher"))
        #expect(
            librarian.prompt.contains("reference_library"),
            "the librarian must reach the corpus writer"
        )
        #expect(
            researcher.prompt.contains("reference_library"),
            "the researcher reads the corpus to know what is already there"
        )
    }

    // MARK: - The tools are real

    @Test("every tool the librarian names is a tool the production registry carries")
    func theToolsAreReal() throws {
        let role = try #require(SubAgentRoleRegistry.role(forSlug: "librarian"))
        let production = Set(ToolCatalogue.names)
        for tool in role.toolNames {
            #expect(
                production.contains(tool),
                "the librarian names '\(tool)', which the production registry does not carry"
            )
        }
    }
}
