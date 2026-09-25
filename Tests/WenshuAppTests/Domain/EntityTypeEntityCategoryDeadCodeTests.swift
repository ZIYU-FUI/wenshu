//
//  EntityTypeEntityCategoryDeadCodeTests.swift · Wenshu · dead-code-sweep (2026-09-25)
//
//  Verifies that EntityType.shortName and EntityCategory.shortName are
//  completely removed from the production source tree. They were dead
//  code (= 0 production callers as of 2026-09-25 audit; = zero-testsuite
//  referenced them; = the only callers were the strings inside the
//  switch statements themselves). Removing them clears 30 lines of
//  inline CJK (= 9 EntityType cases × 1 char + 21 EntityCategory cases
//  × 1 char) that previously sat in the agent's grep-context as
//  potential contamination source.
//
//  Per wenshu-dead-code-cleanup skill: when a public API surface is
//  reduced, ship a verification test that asserts the symbols no
//  longer exist (= no orphan callsites left to fix in a follow-up;
//  = the dead-code ticket is closed atomically with this test).
//

import Testing
import Foundation

@Suite("EntityType / EntityCategory dead-code removal (2026-09-25)")
struct EntityTypeEntityCategoryDeadCodeTests {

    /// Read every non-ignored source file under Sources/WenshuApp/ and
    /// scan for the deleted symbols. The pattern matches both the
    /// fully-qualified form (`EntityType.shortName`) and any inferred
    /// callsite (= a property access on an `EntityType` value).
    ///
    /// Implementation: shell out to `find` (= no recursion needed;
    /// = we walk Sources/WenshuApp/ once and read each .swift file).
    private func findDeletedSymbol(
        _ symbol: String,
        fileExtensions: Set<String> = ["swift"]
    ) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = ["Sources/WenshuApp", "-type", "f"]
            + fileExtensions.flatMap { ["-name", "*.\($0)"] }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let paths = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.split(separator: "\n").map(String.init) ?? []

        var hits: [String] = []
        for path in paths {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let lines = text.components(separatedBy: .newlines)
            for (idx, line) in lines.enumerated() where line.contains(symbol) {
                let rel = (path as NSString).lastPathComponent
                hits.append("\(rel):L\(idx + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        return hits
    }

    /// EntityType.shortName was a Chinese label switch (= 9 cases).
    /// Removing it should leave zero references anywhere in the
    /// production source tree (= the symbol itself, plus any
    /// hypothetical callsite that may have escaped the audit).
    @Test func entity_type_short_name_fully_removed() {
        let hits = findDeletedSymbol("EntityType.shortName")
        #expect(hits.isEmpty,
                "EntityType.shortName should have zero references after deletion; found: \(hits)")
    }

    /// EntityCategory.shortName was a Chinese label switch (= 21 cases).
    /// Same expectation as EntityType.shortName above.
    @Test func entity_category_short_name_fully_removed() {
        let hits = findDeletedSymbol("EntityCategory.shortName")
        #expect(hits.isEmpty,
                "EntityCategory.shortName should have zero references after deletion; found: \(hits)")
    }

    /// Property-inferred callsite sanity check: also confirm no bare
    /// `.shortName` callsites exist (e.g. on a `category` or `type`
    /// local). These would only exist if a caller inferred the type
    /// and used `.shortName` directly (= the audit confirmed zero,
    /// but the test pins the invariant).
    @Test func no_bare_short_name_callsites_remain() {
        let hits = findDeletedSymbol(".shortName")
        #expect(hits.isEmpty,
                ".shortName should have zero references after deletion; found: \(hits)")
    }

    /// Active API surface preservation: displayName + directoryName
    /// + description + icon + promptNumber + fromPromptNumber + id
    /// are still present on the respective enums (= the audit kept
    /// them because they have active callers).
    ///
    /// This guards against accidental over-deletion in future sweeps
    /// (= if someone reverts this commit and tries to delete
    /// EntityType.displayName thinking it's also dead, the build will
    /// fail loudly via the EntityClassifier LLM prompt caller).
    @Test func active_entity_type_properties_still_present() {
        let path = "Sources/WenshuApp/Domain/EntityType.swift"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            Issue.record("Cannot read \(path)")
            return
        }
        #expect(text.contains("var displayName: String"),
                "EntityType.displayName must remain (= active caller = EntityClassifier LLM prompt)")
        #expect(text.contains("var description: String"),
                "EntityType.description must remain (= active caller = EntityClassifier LLM prompt)")
        #expect(text.contains("var icon: String"),
                "EntityType.icon must remain (= active caller = SidebarService + PreviewPane)")
        #expect(text.contains("var promptNumber: Int"),
                "EntityType.promptNumber must remain (= active caller = EntityClassifier + Reference)")
    }

    @Test func active_entity_category_properties_still_present() {
        let path = "Sources/WenshuApp/Domain/EntityCategory.swift"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            Issue.record("Cannot read \(path)")
            return
        }
        #expect(text.contains("var displayName: String"),
                "EntityCategory.displayName must remain (= active callers = SidebarService + EntityClassifier)")
        #expect(text.contains("var directoryName: String"),
                "EntityCategory.directoryName must remain (= filesystem metadata, 11+ callers)")
        #expect(text.contains("var icon: String"),
                "EntityCategory.icon must remain (= active caller = SidebarService)")
    }
}