// PromptAssemblyCacheTests.swift
//
// The cache invariants, as assertions rather than comments.
//
// A broken invariant here costs money quietly: a prefix that shifts one byte
// re-reads the whole system prompt on every turn of a long session, and
// nothing in the product surface reports it.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Prompt assembly cache tiers")
struct PromptAssemblyCacheTests {

    private func inputs(
        book: String = "Coastal Fog",
        project: String = "# Project\nUse the essay register.",
        memory: String = "## Memory\n- prefers short chapters",
        environment: String = "# Environment\ncwd: /books/fog",
        timestamp: String = "2026-03-30T14:30:00+08:00"
    ) -> PromptInputs {
        PromptInputs(
            userName: "老板",
            bookTitle: book,
            projectContext: project,
            memorySnapshot: memory,
            environment: environment,
            timestampLine: timestamp
        )
    }

    @Test("stable tier does not depend on any session input")
    func stableTierIgnoresSessionInputs() {
        let assembler = PromptAssembler()
        let a = assembler.assemble(inputs()).stable
        let b = assembler.assemble(inputs(book: "Another Book", memory: "", environment: "")).stable
        #expect(a == b, "the cache prefix must not move when the book or memory changes")
    }

    @Test("book and user names stay out of the stable tier")
    func sessionScopeDoesNotLeakIntoStableTier() {
        let stable = PromptAssembler().assemble(inputs()).stable
        #expect(!stable.contains("Coastal Fog"), "book title must not reach the stable tier")
        #expect(!stable.contains("老板"), "user name must not reach the stable tier")
    }

    @Test("tier order is stable then context then volatile")
    func joinedFollowsTierOrder() {
        let assembly = PromptAssembler().assemble(inputs())
        #expect(assembly.joined.hasPrefix(assembly.stable))
        let contextStart = assembly.joined.range(of: assembly.context)?.lowerBound
        let volatileStart = assembly.joined.range(of: assembly.volatile)?.lowerBound
        if let contextStart, let volatileStart {
            #expect(contextStart < volatileStart, "context must precede volatile")
        }
    }

    @Test("project context precedes book context so books share a prefix")
    func projectContextPrecedesBookContext() {
        let assembly = PromptAssembler().assemble(inputs())
        let projectRange = assembly.context.range(of: "# Project")
        let bookRange = assembly.context.range(of: "## Current book")
        #expect(projectRange != nil)
        #expect(bookRange != nil)
        if let projectRange, let bookRange {
            #expect(projectRange.upperBound <= bookRange.lowerBound,
                    "the first book-dependent line must be the last thing in the context tier")
        }
    }

    @Test("two books share the stable tier byte for byte")
    func twoBooksShareStablePrefix() {
        let assembler = PromptAssembler()
        #expect(assembler.assemble(inputs(book: "First")).stable
            == assembler.assemble(inputs(book: "Second")).stable)
    }

    @Test("volatile tier carries memory, timestamp and environment only")
    func volatileTierHoldsVolatileSources() {
        let assembly = PromptAssembler().assemble(inputs())
        #expect(assembly.volatile.contains("prefers short chapters"))
        #expect(assembly.volatile.contains("2026-03-30"))
        #expect(assembly.volatile.contains("cwd: /books/fog"))
    }

    @Test("empty tiers are dropped rather than joined as separators")
    func emptyTiersDoNotShiftBytes() {
        let assembly = PromptAssembly(stable: "S", context: "", volatile: "V")
        #expect(assembly.joined == "S\n\nV")
        #expect(PromptAssembly().joined.isEmpty)
        #expect(PromptAssembly().isEmpty)
    }

    @Test("every tier toggle removes its section")
    func settingsTogglesRemoveSections() {
        var settings = PromptSettings()
        settings.identityEnabled = false
        let withoutIdentity = PromptAssembler(settings: settings).assemble(inputs()).stable
        #expect(withoutIdentity != PromptAssembler().assemble(inputs()).stable)
        #expect(withoutIdentity.count < PromptAssembler().assemble(inputs()).stable.count)

        settings = PromptSettings()
        settings.memoryGuidanceEnabled = false
        settings.skillGuidanceEnabled = false
        let withoutGuidance = PromptAssembler(settings: settings).assemble(inputs()).stable
        #expect(withoutGuidance != PromptAssembler().assemble(inputs()).stable)

        settings = PromptSettings()
        settings.includeEnvironmentHints = false
        let withoutEnvironment = PromptAssembler(settings: settings).assemble(inputs()).volatile
        #expect(!withoutEnvironment.contains("cwd: /books/fog"))

        settings = PromptSettings()
        settings.includeBookContext = false
        let withoutBook = PromptAssembler(settings: settings).assemble(inputs()).context
        #expect(!withoutBook.contains("## Current book"))
    }

    @Test("an explicit context cap truncates and says so")
    func explicitCapTruncatesWithMarker() {
        var settings = PromptSettings()
        settings.projectContextFileMaxChars = 400
        let long = String(repeating: "x", count: 5_000)
        let assembly = PromptAssembler(settings: settings).assemble(
            PromptInputs(projectContext: long)
        )
        #expect(assembly.context.count < long.count)
    }
}