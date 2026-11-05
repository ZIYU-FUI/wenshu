//
//  InspectorViewShellTests.swift · Wenshu
//
//  Structural tests for the trailing inspector column (= the right
//  rail).
//
//  The column's specialized tools were removed, and the three pages
//  that had no tool went with them. What is left is a column with TWO
//  major sections: = the dynamic series (= Todos, Sub-Agents, Tasks)
//  and the format inspector. The dynamic section keeps its three pages
//  and its own segmented switcher; = the format section carries the
//  document's format commands. These tests pin the facts that keep the
//  parts apart: = the column has two sections and three pages, = the
//  pages' order is fixed, = each section reads its own catalog key, =
//  the switcher is the native segmented control, = each page renders
//  from its own file, and = the column references none of the removed
//  tools.
//
//  swift test --filter InspectorViewShellTests
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Inspector column shell")
struct InspectorViewShellTests {
    private var inspectorPath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorView.swift")
        return url.path
    }

    private var workspaceUIStatePath: String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent("Sources/WenshuApp/Shared/State/WorkspaceUIState.swift")
        return url.path
    }

    /// The catalog key each page case's title reads, in source order.
    ///
    /// The order is the segment order: the segmented control reads
    /// `allCases`, and each case's title reads one key. So the cases'
    /// order in the source IS the order the user reads the segments
    /// in.
    private func pageTitleKeys() throws -> [(caseName: String, key: String)] {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        // The scan is scoped to the page enum ALONE, = because the file
        // holds other enums whose cases read catalog keys too (= the
        // section enum sits right after it, = and its cases read their
        // own keys).
        guard let enumStart = source.range(of: "enum InspectorPage"),
              let enumEnd = source.range(of: "enum InspectorSection",
                                         range: enumStart.upperBound ..< source.endIndex)
        else { return [] }
        let scoped = String(source[enumStart.upperBound ..< enumEnd.lowerBound])
        let pattern = "case \\.(\\w+):\\s*return String\\(localized: \"([^\"]+)\"\\)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(scoped.startIndex..., in: scoped)
        return regex.matches(in: scoped, range: range).compactMap { match in
            guard let nameRange = Range(match.range(at: 1), in: scoped),
                  let keyRange = Range(match.range(at: 2), in: scoped)
            else { return nil }
            return (caseName: String(scoped[nameRange]), key: String(scoped[keyRange]))
        }
    }

    @Test("the column has two major sections")
    func theColumnHasTwoMajorSections() {
        #expect(InspectorSection.allCases.count == 2,
                "the column carries two major sections (= the dynamic series and the format inspector)")
        #expect(InspectorSection.allCases == [.dynamic, .format],
                "the section order is the band order: the dynamic series first, the format inspector second")
    }

    @Test("the dynamic section keeps three pages")
    func theDynamicSectionKeepsThreePages() {
        #expect(InspectorPage.allCases.count == 3,
                "the dynamic section keeps its three pages (= Todos, Sub-Agents, Tasks)")
        #expect(InspectorPage.allCases == [.todo, .status, .task],
                "the page order is the segment order: todo, sub-agent, task")
    }

    @Test("the format page is a section, not a page")
    func theFormatPageIsASectionNotAPage() {
        // The format commands describe the DOCUMENT, = not the runtime's
        // state, = so they are a major section of their own and not a
        // fourth tab in the dynamic series.
        #expect(InspectorPage.allCases.count == 3,
                "the dynamic series carries three pages, = and the format inspector is not one of them")
        #expect(InspectorSection.allCases.contains(.format),
                "the format inspector is one of the column's two major sections")
    }

    @Test("the segments read todos, sub-agents and tasks, in that order")
    func theSegmentsReadInOrder() throws {
        let pairs = try pageTitleKeys()
        #expect(pairs.map(\.caseName) == ["todo", "status", "task"],
                "the segment order is todo, sub-agent, task")
        #expect(pairs.map(\.key) == ["inspector.page.todo", "inspector.page.status", "inspector.page.task"],
                "each page reads its own catalog key")
        // The Chinese labels are written as escapes, because a test
        // file carries no literal CJK (= rule 1.1).
        let catalog = StringCatalogReader.strings(language: "zh-Hans")
        let labels = pairs.compactMap { catalog[$0.key] }
        #expect(labels == ["\u{5F85}\u{529E}", "\u{5B50}\u{4EE3}\u{7406}", "\u{4EFB}\u{52A1}"],
                "the three segments read the todos, the sub-agents and the tasks")
    }

    @Test("the two sections read their own catalog keys")
    func theSectionsReadTheirOwnKeys() throws {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        guard let enumStart = source.range(of: "enum InspectorSection") else { return }
        let scoped = String(source[enumStart.upperBound...])
        let pattern = "case \\.(\\w+):\\s*return String\\(localized: \"([^\"]+)\"\\)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(scoped.startIndex..., in: scoped)
        let pairs = regex.matches(in: scoped, range: range).compactMap { match -> (String, String)? in
            guard let nameRange = Range(match.range(at: 1), in: scoped),
                  let keyRange = Range(match.range(at: 2), in: scoped)
            else { return nil }
            return (String(scoped[nameRange]), String(scoped[keyRange]))
        }
        #expect(pairs.map(\.0) == ["dynamic", "format"],
                "the section order is the dynamic series first, the format inspector second")
        #expect(pairs.map(\.1) == ["inspector.section.dynamic", "inspector.section.format"],
                "each section reads its own catalog key")
        let catalog = StringCatalogReader.strings(language: "zh-Hans")
        let labels = pairs.compactMap { catalog[$0.1] }
        #expect(labels == ["\u{52A8}\u{6001}", "\u{683C}\u{5F0F}"],
                "the two sections read the dynamic series and the format inspector")
    }

    @Test("the fiction page is gone")
    func theFictionPageIsGone() throws {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        #expect(!source.contains("case authoringFiction"),
                "the fiction page was replaced by the status page and must not come back")
    }

    @Test("the pages without a tool are gone")
    func thePagesWithoutAToolAreGone() throws {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        for caseName in ["authoringStyle", "authoringCharacters", "projectManagement"] {
            #expect(!source.contains("case \(caseName)"),
                    "the \(caseName) page had no tool and must not come back")
        }
    }

    @Test("every page carries a localized title and an icon")
    func everyPageCarriesATitleAndAnIcon() {
        for page in InspectorPage.allCases {
            #expect(!page.localizedTitle.isEmpty, "\(page) must carry a title")
            #expect(!page.icon.isEmpty, "\(page) must carry an icon")
        }
    }

    @Test("the column renders the status page")
    func theColumnRendersTheStatusPage() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("InspectorStatusView("),
                "the column body renders the status page (= the focused chat session's sub-agent tasks)")
    }

    @Test("the column carries the switcher and both new pages")
    func theColumnCarriesTheSwitcherAndBothPages() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("LabelSegmentedControl("),
                "the column's chrome band carries the shared segmented control")
        #expect(source.contains("InspectorTodoPageView("),
                "the todos page renders from its own file")
        #expect(source.contains("InspectorTaskPageView("),
                "the tasks page renders from its own file")
    }

    @Test("the column's two sections each carry their own switcher and body")
    func theColumnCarriesBothSections() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The major-section switcher reads the SECTION enum; = the
        // dynamic section's switcher reads the PAGE enum; = and the
        // format section carries the format page.
        #expect(source.contains("ForEach(InspectorSection.allCases"),
                "the window toolbar's button group offers the major sections")
        #expect(source.contains("labels: InspectorPage.allCases"),
                "the dynamic section's band switches its three pages")
        #expect(source.contains("InspectorFormatPageView()"),
                "the format section carries the format inspector")
        #expect(source.contains("case .format:"),
                "the column routes the format section")
    }

    @Test("the column mounts the visibility toggle and no SwiftUI picker")
    func theColumnMountsItsToolbarControls() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("inspectorVisibleBinding.toggle()"),
                "the column owns its own visibility toggle")
        #expect(source.contains("ToolbarItemGroup(placement: .principal)"),
                "the toggle sits in the center toolbar slot")
        // The page switcher is the native segmented control: a SwiftUI
        // `Picker(.segmented)` does not expose the macOS 27 role, so a
        // text-labelled strip cannot paint its selected label through it.
        // The SECTION switch is the other way round: = its segments
        // carry SYMBOLS and no text, = so there is no label to paint, =
        // and a SwiftUI `Picker(.segmented)` in a toolbar item is the
        // form SwiftUI registers as a REAL toolbar item (= the only way
        // to get the toolbar's OWN segmented shape, = which is what
        // Apple's own right-column switch is).
        #expect(source.contains("LabelSegmentedControl("),
                "the dynamic section's page switcher must be the native segmented control")
        #expect(source.contains(".pickerStyle(.segmented)"),
                "the section switch is a segmented picker in a toolbar item")
    }

    @Test("the column references none of the removed tools")
    func theColumnReferencesNoRemovedTool() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        let removedTypes = [
            "ForeshadowingView", "PlaceholderView", "PlotThreadView",
            "LongFormGuardrailsView", "ReaderExperienceView", "GenreFitView",
            "CharacterRelationshipsView", "CharacterLifecycleView",
            "EmotionCurveView", "IdeaLibraryView", "TagManagerView",
            "BookSettingConstraintsView", "BookmarkView", "BackgroundReviewView",
            "EditorDocumentToolsView", "ZoneContentView",
        ]
        for type in removedTypes {
            #expect(!source.contains(type),
                    "\(type) was removed from the column and must not come back")
        }
    }

    @Test("the shared state owns the page selection")
    func theSharedStateOwnsThePageSelection() throws {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        #expect(source.contains("var inspectorPage: InspectorPage"),
                "the page selection lives in the shared column-local state")
        #expect(source.contains("var inspectorSection: InspectorSection"),
                "the major-section selection lives in the shared column-local state too")
        #expect(!source.contains("case documentTools"),
                "the document-tools page was a removed feature and stays gone")
    }
}
