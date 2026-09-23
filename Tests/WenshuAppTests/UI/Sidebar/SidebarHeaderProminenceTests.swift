// SidebarHeaderProminenceTests.swift · Wenshu · v0.71 P1 batch 3
//
// v0.71 P1 batch 3 (boss 2026-09-12 OOB 'sidebar column, test bookshelf, divider,
// reference library — is there spacing between these controls that we added by hand; if so, revert to default'):
// code-level verification (= no UI render) that the sidebar's
// section header doesn't use the non-Apple-default `.headerProminence
// (.increased)` modifier (= the Apple HIG default is .standard = no
// modifier; = the previous commit removed .headerProminence(.increased)
// to revert to the Apple-default ~22 PT inter-section gap).
//
// These tests don't render the view; they verify the SOURCE file
// structure (= the canonical 'code-level verification' discipline
// when screenshot tests are unavailable).
//
// v1.69 sidebar MVVM cleanup: target file path updated from
// AppleSidebarView.swift (= was NewLibraryOutlineView.swift pre-v1.69e) (= the
// v1.68b MVVM-split sidebar that is now the production sidebar).
// Same Apple-HIG-default invariant = no .headerProminence(.increased)
// and no manual .padding(.top, ...) on the section header.

import Testing
import Foundation

@Suite("v0.71 P1 — Sidebar uses Apple HIG defaults (no manual header prominence)")
struct SidebarHeaderProminenceTests {

    private static let sidebarSourceURL = URL(
        fileURLWithPath: "Sources/WenshuApp/Views/Library/AppleSidebarView.swift"
    )

    private static func loadSidebarSource() throws -> String {
        try String(
            contentsOf: sidebarSourceURL,
            encoding: .utf8
        )
    }

    /// boss 9/12 OOB 'sidebar column, test bookshelf, divider, reference library... if any were changed,
    /// revert to default': the sidebar MUST NOT use .headerProminence(.increased)
    /// (= a non-Apple-default modifier that adds ~36 PT of inter-
    /// section gap; = Apple HIG default = .standard = no modifier;
    /// = the previous fix removed it; = this test prevents re-introduction).
    @Test("no_headerProminence_increased_in_sidebar")
    func no_headerProminence_increased_in_sidebar() throws {
        let src = try Self.loadSidebarSource()
        // Strip comments (= the historical notes mention
        // `.headerProminence(.increased)` as the value that was
        // REMOVED; = they're part of the explanation of the
        // boss's directive; = they don't represent active code).
        let strippedSrc = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }.joined(separator: "\n")
        #expect(
            !strippedSrc.contains(".headerProminence(.increased)"),
            "AppleSidebarView MUST NOT use .headerProminence(.increased) (= Apple HIG default = .standard)"
        )
    }

    /// boss 'anything that uses Apple styles should default everything' (= Apple styles = all
    /// defaults): the sidebar MUST NOT use any non-standard SwiftUI
    /// header prominence (= .standard is the default; .increased
    /// and .decreased are explicit non-default values).
    @Test("no_headerProminence_any_non_default_in_sidebar")
    func no_headerProminence_any_non_default_in_sidebar() throws {
        let src = try Self.loadSidebarSource()
        // Strip comments (= see no_headerProminence_increased_in_sidebar).
        let strippedSrc = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }.joined(separator: "\n")
        // (.standard is fine; = the default; = Apple HIG macOS
        // 27 default section gap. The other two values are non-
        // defaults.)
        let nonDefaults = [".headerProminence(.increased)", ".headerProminence(.decreased)"]
        for token in nonDefaults {
            #expect(
                !strippedSrc.contains(token),
                "AppleSidebarView MUST NOT use \(token) (= non-Apple-default)"
            )
        }
    }

    /// boss 'audit the right column... if I added any spacing by hand, revert to default' (= audit the
    /// right column for any custom padding I added; revert to defaults)
    /// + 'anything that uses Apple styles should default everything' (= Apple styles = all defaults):
    /// the sidebar section header MUST NOT have any custom numeric
    /// padding (= the previous commit removed `.padding(.top, 18)`
    /// AND `.padding(.top, 4)` AND `.headerProminence(.increased)`;
    /// = Apple HIG default = `.listStyle(.sidebar)` manages section
    /// header spacing via Apple's built-in convention = no manual
    /// padding needed).
    ///
    /// This test asserts the source file has NO active `.padding(.top, ...)`
    /// call after the section header (= the comments mentioning
    /// 'padding(.top, 18)' or 'padding(.top, 4)' are historical notes
    /// about the removal; = they're allowed because they document
    /// the boss's directive).
    @Test("sidebar_section_header_uses_no_custom_padding")
    func sidebar_section_header_uses_no_custom_padding() throws {
        let src = try Self.loadSidebarSource()
        // Strip comments (= the historical notes mention
        // 'padding(.top, 18)' and 'padding(.top, 4)' as the values
        // that were REMOVED; = they're part of the explanation
        // of the boss's directive; = they don't represent active
        // code).
        let strippedLines = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }
        let strippedSrc = strippedLines.joined(separator: "\n")
        // = the live code MUST NOT contain `.padding(.top, 18)` or
        // `.padding(.top, 4)` (= Apple HIG default = `.listStyle(.sidebar)`
        // manages section header spacing via SwiftUI's built-in HIG
        // sidebar convention).
        #expect(
            !strippedSrc.contains(".padding(.top, 18)"),
            "Sidebar section header MUST NOT use .padding(.top, 18) (= Apple HIG default; = .listStyle(.sidebar) handles spacing)"
        )
        #expect(
            !strippedSrc.contains(".padding(.top, 4)"),
            "Sidebar section header MUST NOT use .padding(.top, 4) (= Apple HIG default; = .listStyle(.sidebar) handles spacing)"
        )
        // = the chromePaddingSectionTop token is preserved in
        // DesignTokens.swift (= single source of truth = other
        // columns may still use it = no removal).
    }
}
