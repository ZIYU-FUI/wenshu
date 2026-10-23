//
//  InspectorViewShellTests.swift · Wenshu
//
//  Structural tests for the trailing inspector column (= the right
//  rail).
//
//  The column's specialized tools were removed; the column itself
//  stays. These tests pin the two facts that keep the two apart:
//  the column has its 4 pages, and the column references none of
//  the removed tools.
//
//  swift test --filter InspectorViewShellTests
//

import Testing
import Foundation
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

    @Test("the column has exactly the 4 pages")
    func theColumnHasFourPages() {
        #expect(InspectorPage.allCases.count == 4,
                "the column keeps 4 pages (= Status / Style / Characters / Project Management)")
        #expect(InspectorPage.allCases.contains(.status))
        #expect(InspectorPage.allCases.contains(.authoringStyle))
        #expect(InspectorPage.allCases.contains(.authoringCharacters))
        #expect(InspectorPage.allCases.contains(.projectManagement))
    }

    @Test("the fiction page is gone")
    func theFictionPageIsGone() throws {
        let source = try String(contentsOfFile: workspaceUIStatePath, encoding: .utf8)
        #expect(!source.contains("case authoringFiction"),
                "the fiction page was replaced by the status page and must not come back")
    }

    @Test("every page carries a localized title and an icon")
    func everyPageCarriesATitleAndAnIcon() {
        for page in InspectorPage.allCases {
            #expect(!page.localizedTitle.isEmpty, "\(page) must carry a title")
            #expect(!page.icon.isEmpty, "\(page) must carry an icon")
        }
    }

    @Test("the column renders the shared empty state")
    func theColumnRendersTheEmptyState() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("EmptyStateView("),
                "a page without a tool renders the shared empty state")
        #expect(source.contains("inspector.empty.title"),
                "the empty state title comes from the string catalog")
        #expect(source.contains("inspector.empty.body"),
                "the empty state body comes from the string catalog")
    }

    @Test("the column mounts the page picker and the visibility toggle")
    func theColumnMountsItsToolbarControls() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        // The picker binds through a custom Binding, so its selection
        // setter can also write the column's visibility (= a hidden
        // column comes back when a page tab is pressed). The shared
        // page state is still what the picker writes.
        #expect(source.contains("Picker(") && source.contains("\"Inspector Page\""),
                "the page picker selects the column's page")
        #expect(source.contains("workspaceUI.inspectorPage = newPage"),
                "the page picker writes the shared page state")
        #expect(source.contains("ToolbarItem(placement: .primaryAction)"),
                "the page picker sits in the trailing toolbar slot")
        #expect(source.contains("inspectorVisibleBinding.toggle()"),
                "the column owns its own visibility toggle")
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
        #expect(!source.contains("case documentTools"),
                "the document-tools page was a removed feature and stays gone")
    }
}
