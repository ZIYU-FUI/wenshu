//
//  InspectorViewShellTests.swift · Wenshu
//
//  Structural tests for the trailing inspector column (= the right
//  rail).
//
//  The column's specialized tools were removed, and the three pages
//  that had no tool went with them. What is left is the status page
//  and the column's visibility toggle. These tests pin the two facts
//  that keep the two apart: the column has one page, and the column
//  references none of the removed tools.
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

    @Test("the column has exactly one page")
    func theColumnHasOnePage() {
        #expect(InspectorPage.allCases.count == 1,
                "the column keeps one page (= Status)")
        #expect(InspectorPage.allCases.contains(.status))
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

    @Test("the column mounts the visibility toggle and no page picker")
    func theColumnMountsItsToolbarControls() throws {
        let source = try String(contentsOfFile: inspectorPath, encoding: .utf8)
        #expect(source.contains("inspectorVisibleBinding.toggle()"),
                "the column owns its own visibility toggle")
        #expect(source.contains("ToolbarItemGroup(placement: .principal)"),
                "the toggle sits in the center toolbar slot")
        // One page = nothing to switch between, so the picker is gone.
        #expect(!source.contains("Picker("),
                "the page picker had one option left and must not come back")
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
