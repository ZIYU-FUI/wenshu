// SidebarHeaderProminenceTests.swift · Wenshu
//
// section header doesn't use the non-Apple-default `.headerProminence
// (.increased)` modifier (= the Apple HIG default is .standard = no
// modifier; = the previous commit removed .headerProminence(.increased)
// to revert to the Apple-default ~22 PT inter-section gap).
//
// These tests don't render the view; they verify the SOURCE file
// structure (= the canonical 'code-level verification' discipline
// when screenshot tests are unavailable).
//
import Testing
import Foundation

@Suite("v0.71 P1 — Sidebar uses Apple HIG defaults (no manual header prominence)")
struct SidebarHeaderProminenceTests {

    private static let sidebarSourceURL = SourceLocator.url(
        "Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift"
    )

    private static func loadSidebarSource() throws -> String {
        try String(
            contentsOf: sidebarSourceURL,
            encoding: .utf8
        )
    }

    /// The sidebar MUST NOT use .headerProminence(.increased)
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

    /// The sidebar MUST NOT use any non-standard SwiftUI
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

    /// The sidebar section header MUST NOT have any custom numeric
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

    /// The left column's top band: the switcher is the content of the
    /// shared chrome band, the header above it drops its trailing inset
    /// (= the band starts at the divider), and the band carries the
    /// tree's 10 PT inset so the switcher lines up with the tree rows.
    ///
    /// The three facts are one shape, so they are one test.
    @Test("the_sidebar_switcher_is_the_column_chrome_band")
    func the_sidebar_switcher_is_the_column_chrome_band() throws {
        let src = try Self.loadSidebarSource()
        // Strip comments (= the historical notes mention values that
        // were REMOVED; = they are part of the explanation, = not
        // active code).
        let strippedSrc = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }.joined(separator: "\n")

        // The switcher is the chrome band's content.
        #expect(
            strippedSrc.contains("ChromeTopBar("),
            "The sidebar's switcher must be rendered inside the shared ChromeTopBar band"
        )
        #expect(
            strippedSrc.contains("LabelSegmentedControl("),
            "The sidebar's switcher must stay the LabelSegmentedControl"
        )
        // The band starts at the header's divider.
        #expect(
            strippedSrc.contains("trailingInset: false"),
            "The sidebar's section header must pass trailingInset: false (= the band follows the divider)"
        )
        // The band's inset is the tree's 10 PT, not the shared 8 PT.
        #expect(
            strippedSrc.contains("horizontalPadding: DesignTokens.spacingRelaxed"),
            "The sidebar's chrome band must use the tree's 10 PT inset (= DesignTokens.spacingRelaxed)"
        )
    }

    /// The switcher is a column-top chrome control, so it takes
    /// AppKit's `.small` control size (= a 20 PT drawn capsule) and
    /// the band's 28 PT row keeps its height around it. The control
    /// size is the shared control's per-call-site knob; the shared
    /// default stays `.large` for the other two call sites.
    @Test("the_sidebar_switcher_uses_the_small_control_size")
    func the_sidebar_switcher_uses_the_small_control_size() throws {
        let src = try Self.loadSidebarSource()
        let strippedSrc = src.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*")
        }.joined(separator: "\n")

        #expect(
            strippedSrc.contains("controlSize: .small"),
            "The sidebar's switcher must ask for the .small control size (= a shorter drawn capsule)"
        )
        // The band's row height stays the shared 28 PT token, so the
        // band still matches the assets column's search band.
        #expect(
            strippedSrc.contains(".frame(height: DesignTokens.paneTabHotArea)"),
            "The sidebar's chrome band must keep the 28 PT row height (= DesignTokens.paneTabHotArea)"
        )
    }
}
