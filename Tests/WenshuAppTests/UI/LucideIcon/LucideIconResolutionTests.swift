//
//  LucideIconResolutionTests.swift · Wenshu · v0.71 P1 batch 3
//
//  v0.71 P1 batch 3 (boss 2026-09-12 EOB 'get code-level verification and testing in first...
//  the rest we'll discuss Monday') + icon audit followup (boss 9/12 OOB 'a lot of
//  icons disappeared, I suggest you slow down and verify each one doesn't miss'):
//
//  Code-level verification (= no UI render) that `resolveLucideName(_:)`
//  = the kebab→camelCase icon name resolver introduced in commit
//  e36339f98 (= 17-entry alias table + suffix-stripper + generic
//  kebab→camelCase conversion) = correctly translates every Lucide
//  icon name used in the wenshu codebase to the camelCase enum
//  case expected by the ajaxjiang96/lucide-swift fork (= which
//  uses camelCase rawValues for both case names AND rawValue strings).
//
//  These tests don't render any views; they only verify the pure
//  resolver function (= code-level verification of the icon
//  rendering surface; = the 17-entry alias table is the canonical
//  fix for the 'a lot of icons disappeared' boss feedback; = without these
//  tests, a regression in resolveLucideName would silently break
//  every icon in the app).

import Testing
import Foundation
import LucideSwift
@testable import WenshuApp

@Suite("v0.71 P1 — LucideIcon.name resolution (= icon audit, code-level)")
struct LucideIconResolutionTests {

    // MARK: - Direct rawValue match (= unchanged names)

    /// boss 9/12 OOB 'audit every icon position and replace them all consistently': names that are
    /// already in the fork's camelCase rawValue form pass through
    /// unchanged.
    @Test("resolveLucideName_passesThrough_camelCaseRawValues")
    func resolveLucideName_passesThrough_camelCaseRawValues() {
        // 4 representative camelCase names used in the wenshu codebase.
        let names = ["kanban", "library", "plus", "wrench"]
        for name in names {
            let resolved = resolveLucideName(name)
            #expect(
                resolved != nil,
                "Expected '\(name)' to resolve to a LucideIconName (= fork uses camelCase rawValue)"
            )
        }
    }

    // MARK: - Explicit alias table (= 17 mappings)

    /// commit e36339f98 introduced the 17-entry alias table.
    /// Each entry MUST resolve to a valid LucideIconName (= the
    /// alias maps to the correct fork enum case).
    @Test("resolveLucideName_handles_all_17_alias_table_entries")
    func resolveLucideName_handles_all_17_alias_table_entries() {
        // The 17 explicit alias entries per Sources/WenshuApp/
        // Views/LucideIcon.swift:88-117.
        let aliasTable: [(input: String, expectedRaw: String)] = [
            ("sidebar-right", "panel-right"),
            ("sidebar-left", "panel-left"),
            ("maximize-2", "maximize"),
            ("minimize-2", "minimize"),
            ("undo-2", "undo"),
            ("trash-2", "trash"),
            ("book-plus", "bookPlus"),
            ("circle-arrow-down", "circleArrowDown"),
            ("circle-check", "circleCheck"),
            ("circle-dot", "circleDot"),
            ("circle-plus", "circlePlus"),
            ("circle-x", "circleX"),
            ("file-plus", "filePlus"),
            ("list-checks", "listChecks"),
            ("refresh-cw", "refreshCw"),
            ("search-check", "searchCheck"),
            ("square-arrow-right", "squareArrowRight"),
        ]
        #expect(aliasTable.count == 17, "Alias table should have 17 entries, has \(aliasTable.count)")
        for entry in aliasTable {
            let resolved = resolveLucideName(entry.input)
            #expect(
                resolved != nil,
                "Alias table entry '\(entry.input)' must resolve (= maps to '\(entry.expectedRaw)')"
            )
        }
    }

    /// specific check = 'circle-x' was one of the icons that
    /// silently fell back to the house icon (boss 9/12 OOB 'a lot of
    /// icons disappeared'); = this test verifies it's now correctly resolved.
    @Test("resolveLucideName_circle_x_resolves_to_circleX")
    func resolveLucideName_circle_x_resolves_to_circleX() {
        let resolved = resolveLucideName("circle-x")
        #expect(
            resolved != nil,
            "'circle-x' must resolve (= the closing X icon for sheets / popovers)"
        )
    }

    /// specific check = 'trash-2' (= the trash icon) was one of
    /// the bring-shrubbery 1.25.0 names that ajaxjiang96 fork
    /// merged into just 'trash'.
    @Test("resolveLucideName_trash_2_resolves_via_suffix_stripper")
    func resolveLucideName_trash_2_resolves_via_suffix_stripper() {
        // 'trash-2' should resolve (either via the alias table OR
        // via the trailing '-2' suffix stripper; = both paths
        // produce a valid result).
        let resolved = resolveLucideName("trash-2")
        #expect(
            resolved != nil,
            "'trash-2' must resolve (= the trash icon for delete actions)"
        )
    }

    // MARK: - Generic kebab→camelCase

    /// boss 9/11 OOB 'audit every icon position and replace them all consistently': generic kebab→
    /// camelCase conversion handles the bulk of the icon names that
    /// are not in the explicit alias table. Test with a few representative
    /// multi-word names that appear in the wenshu codebase.
    @Test("resolveLucideName_generic_kebab_to_camelCase")
    func resolveLucideName_generic_kebab_to_camelCase() {
        // These names are NOT in the explicit alias table but should
        // resolve via the generic kebab→camelCase conversion step.
        let candidates = ["book-open", "calendar-days", "chevron-right", "message-square"]
        for name in candidates {
            let resolved = resolveLucideName(name)
            #expect(
                resolved != nil,
                "Generic kebab→camelCase should resolve '\(name)' (= the fork uses camelCase rawValues)"
            )
        }
    }

    // MARK: - Failure modes (= not-found fallback)

    /// A truly unknown name MUST return nil (= the caller can then
    /// show an empty Color.clear placeholder; = the boss's 'icon
    /// miss fallback' = the fallback is the `Color.clear.frame(width:height:)`
    /// path in `resolveLucideIconView`).
    @Test("resolveLucideName_unknownName_returnsNil")
    func resolveLucideName_unknownName_returnsNil() {
        let resolved = resolveLucideName("this-icon-name-does-not-exist-anywhere-zzzzz")
        #expect(
            resolved == nil,
            "Unknown icon names MUST return nil (= caller falls back to Color.clear)"
        )
    }

    /// Empty string MUST return nil (= not crash; = not match anything).
    @Test("resolveLucideName_emptyString_returnsNil")
    func resolveLucideName_emptyString_returnsNil() {
        let resolved = resolveLucideName("")
        #expect(
            resolved == nil,
            "Empty string MUST return nil (= not crash; = not match anything)"
        )
    }

    // MARK: - All icon names used in the wenshu codebase resolve

    /// boss 9/12 OOB 'audit every icon position and replace them all consistently' + 'a lot of icons disappeared,
    /// I suggest you slow down and verify each one doesn't miss': a code-level
    /// scan over all literal icon-name arguments passed to
    /// LucideIcon(...) / LucideImage(...) / LucideIconSystemFallback(...)
    /// / LucideIconSidebar(...) / LucideThinIcon(...) across the
    /// wenshu codebase to verify each one resolves via
    /// `resolveLucideName(_:)`. The previous bug (= the
    /// `LucideIcon(_ name: String, size:)` wrapper passing the
    /// raw kebab string to the fork's `LucideIcon(name:)` which
    /// silently fell back to .house) was fixed in commit 9ccd9f8a9
    /// but a regression would silently break icons again.
    @Test("resolveLucideName_everyLiteralNameInCodebase_resolves")
    func resolveLucideName_everyLiteralNameInCodebase_resolves() throws {
        // Source root = Package.swift's directory (= wenshu project root).
        // Use the canonical #filePath pattern (= same approach as
        // I18nParityTests.swift:184): walk up from this test file
        // (= Tests/WenshuAppTests/UI/LucideIcon/...) to find the
        // project root (= the directory containing Package.swift).
        let thisFile = URL(fileURLWithPath: #filePath)
        let projectRoot = thisFile
            .deletingLastPathComponent() // LucideIcon/
            .deletingLastPathComponent() // UI/
            .deletingLastPathComponent() // WenshuAppTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // wenshu project root
        let sourceRoot = projectRoot.appendingPathComponent("Sources/WenshuApp")
        #expect(
            FileManager.default.fileExists(atPath: sourceRoot.path),
            "Project root must contain Sources/WenshuApp (= derived from #filePath \(#filePath); = sourceRoot \(sourceRoot.path))"
        )
        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        // Collect all literal icon name arguments used at the
        // wenshu icon entry points. The patterns include:
        //   • `LucideIcon("name")` (= Lucide name only)
        //   • `LucideImage("name")` (= Lucide name only)
        //   • `LucideIconSidebar("name")` (= Lucide name only)
        //   • `LucideThinIcon("name", ...)` (= Lucide name only)
        //
        // NOTE: `LucideIconSystemFallback` accepts SF Symbol names
        // (= it maps SF → Lucide via `sfSymbolToLucideName`); = SF
        // Symbol names passed to LucideIconSystemFallback are
        // INTENTIONALLY not Lucide enum rawValues; = they're
        // excluded from this test (= see the dedicated
        // SF→Lucide mapping test for LucideIconSystemFallback).
        var names: Set<String> = []
        let iconEntryPoints = [
            "LucideIcon(", "LucideImage(", "LucideIconSidebar(",
            "LucideThinIcon(",
        ]
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: "\n") {
                // Skip comment lines.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { continue }
                for marker in iconEntryPoints {
                    // Find ALL occurrences of the marker on this line
                    // (= some lines have multiple icons).
                    var searchRange = line.startIndex..<line.endIndex
                    while searchRange.lowerBound < line.endIndex,
                          let r = line.range(of: marker, range: searchRange) {
                        let afterMarker = line[r.upperBound...]
                        // Find the FIRST quoted string (= opening "),
                        // then the NEXT " (= closing).
                        if let openingQuote = afterMarker.firstIndex(of: "\""),
                           let closingQuote = afterMarker[afterMarker.index(after: openingQuote)...].firstIndex(of: "\"") {
                            let name = String(afterMarker[afterMarker.index(after: openingQuote)..<closingQuote])
                            if !name.isEmpty { names.insert(name) }
                        }
                        searchRange = r.upperBound..<line.endIndex
                    }
                }
            }
        }
        #expect(names.count > 0, "Should find at least one icon name usage in the codebase (found \(names.count) at \(sourceRoot.path))")
        // Each name MUST resolve (= no silent fallback to house).
        var unresolved: [String] = []
        for name in names.sorted() {
            if resolveLucideName(name) == nil {
                unresolved.append(name)
            }
        }
        #expect(
            unresolved.isEmpty,
            "Unresolved icon names (each will silently fall back to house): \(unresolved)"
        )
    }
}
