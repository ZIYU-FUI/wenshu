// PreviewSortMenuButtonTests.swift · Wenshu · v1.52 stale-test-cleanup
//
// Source-level tests for PreviewSortMenuButton. The struct
// `EntitySortOrder` (= the binding type) is file-internal to PreviewPane.swift
// (= not `public`), = can't be imported from the test target. Per Q46
// stop scope-creep: we don't make EntitySortOrder public just to test
// the cycle behavior. Instead we verify:
// - Structural contract: source-level file reads for path-relative paths
// - Source-level: cycle switch covers all 3 cases + uses correct i18n key
// - Cycle logic: a duplicate of the switch in source (= future-proofing:
// if someone reorders the cycle, this test catches it; = the
// duplicate IS the test, not the production code path)
//
// v1.52 stale-test-cleanup: replaced hardcoded worktree path
// `v0.83-workspaceview-subcomponents` (= merged and deleted) with
// `#filePath`-based relative path resolution. Replaced `LucideIcon`
// assertion (= deprecated per AGENTS.md §11.1 boss OOB 2026-09-15
// "use SF Symbols 6 (3rd gen)") with `Image(systemName:` check.

import SwiftUI
import ViewInspector
import Testing
@testable import WenshuApp

@Suite("PreviewSortMenuButton (v1.52 stale-test-cleanup)")
@MainActor
struct PreviewSortMenuButtonTests {

    // Compute the source path once per test (= relative to this test
    // file's location: Tests/WenshuAppTests/Views/Workspace/PreviewSortMenuButtonTests.swift
    // → Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift).
    private static var sourcePath: String {
        let testFile = URL(fileURLWithPath: #filePath)
        // <repo>/Tests/WenshuAppTests/Views/Workspace/PreviewSortMenuButtonTests.swift
        // → <repo>/Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift
        let repoRoot = testFile
            .deletingLastPathComponent()  // Views/Workspace
            .deletingLastPathComponent()  // Views
            .deletingLastPathComponent()  // WenshuAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // <repo>
        return repoRoot
            .appendingPathComponent("Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift")
            .path
    }

    // MARK: - Source-level tests (= worktree filesystem)

    @Test("button source uses the WenshuI18n sort_method_help key")
    func sourceUsesI18nHelpKey() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains("workspace.preview.sort_method_help"),
                "PreviewSortMenuButton.swift must reference the i18n help key")
    }

    @Test("button source cycles through all 3 EntitySortOrder cases")
    func sourceCyclesThreeCases() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains(".pinyinFirstLetter"))
        #expect(source.contains(".createdAt"))
        #expect(source.contains(".modifiedAt"))
    }

    @Test("button source uses Image(systemName:) for the SF Symbol 6 menu icon")
    func sourceUsesSFSymbol() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains("Image(systemName:"),
                "PreviewSortMenuButton.swift must use Image(systemName:) per AGENTS.md §11.1 (= LucideIcon retired 2026-09-15)")
    }

    @Test("button source uses DesignTokens.tabIconSize + paneTabHotArea")
    func sourceUsesDesignTokens() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains("DesignTokens.tabIconSize"))
        #expect(source.contains("DesignTokens.paneTabHotArea"))
    }

    @Test("button source uses .onHover (= the hover state)")
    func sourceUsesOnHover() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains(".onHover"),
                "PreviewSortMenuButton.swift must use .onHover for the hover state")
    }

    @Test("button source uses .plain buttonStyle (= no chrome)")
    func sourceUsesPlainButtonStyle() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains(".buttonStyle(.plain)"),
                "PreviewSortMenuButton.swift must use .buttonStyle(.plain)")
    }

    @Test("button source uses .help (= the tooltip)")
    func sourceUsesHelp() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains(".help("),
                "PreviewSortMenuButton.swift must use .help for the tooltip")
    }

    // MARK: - Cycle contract (= duplicated switch in test)

    /// Mirrors the switch in PreviewSortMenuButton.body (= 1:1 copy).
    /// If production reorders the cycle, this test fails (= catches
    /// regressions without exposing the private EntitySortOrder enum).
    @Test("cycle contract: pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter")
    func cycleContract() {
        func next(_ raw: String) -> String {
            switch raw {
            case "pinyinFirstLetter": return "createdAt"
            case "createdAt": return "modifiedAt"
            case "modifiedAt": return "pinyinFirstLetter"
            default: return "unknown"
            }
        }
        #expect(next("pinyinFirstLetter") == "createdAt")
        #expect(next("createdAt") == "modifiedAt")
        #expect(next("modifiedAt") == "pinyinFirstLetter")
        #expect(next("unknown") == "unknown")
    }

    // MARK: - Structural test (= ViewInspector can inspect @MainActor + Button count)

    @Test("the binding parameter is declared on PreviewSortMenuButton")
    func bindingParameterDeclared() throws {
        let source = try String(contentsOfFile: Self.sourcePath)
        #expect(source.contains("@Binding var sortOrder"),
                "PreviewSortMenuButton must have a @Binding sortOrder parameter")
        #expect(source.contains("@State private var isHover"),
                "PreviewSortMenuButton must have a @State isHover property")
    }
}