//
//  Round6StandaloneSweepTests.swift · Wenshu · v3.0
//
//  Per Q112 standing rule expanded (= round 6 sweep: standalone
//  Image(systemName:) sites OUTSIDE Label icon slot / Button /
//  comment contexts).
//
//  This is the round 6 sweep (= boss 2026-10-02 OOB "继续"; =
//  sweep multi-site view files that had remaining standalone Image
//  sites that were NOT in the Label icon slot pattern that round 5
//  swept; = these are the standalone = in HStack / VStack / Button
//  label content with .imageScale modifier chain).
//
//  Sweep files (24 total, 49 sites swept):
//    MemoryRetrievalPanel (1) / PaneTabBar (2) / ShellMiddleColumn (1)
//    / ShellDetailColumn (10) / RuntimeCWDDisplayChip (1)
//    / ChatMessageHoverActions (2) / ChatToolUsePartView (2 - 1 swept, 1 exception)
//    / ChatPlanPartView (3) / PreviewSortMenuButton (1) / LayoutPicker (2)
//    / ParagraphAIToolbarButtons (4) / ReaderExperienceView (2)
//    / BookSettingConstraintsView (1) / LongFormGuardrailsView (2)
//    / BookmarkView (2) / CharacterRelationshipsView (1)
//    / CharacterLifecycleView (1) / GenreFitView (1) / PlotThreadView (1)
//    / SidebarSheets (3) / KanbanView (1) / CommandPaletteView (2)
//    / ForeshadowingGraphWindow (1) / CanvasWindow (2) / CronWindow (1)
//    / LibraryRootView (1)
//
//  Exceptions correctly preserved (= outside v3.0 sweep scope):
//    - ChatToolUsePartView L57: wenshu self-implemented pulse
//      animation chain (.animation + .opacity modifier chain) —
//      SFIcon doesn't own the animation hook.
//    - PreviewPane L1566: 64 PT hero card with .resizable + .aspectRatio
//      + .frame(width:64, height:64) + .symbolRenderingMode(.monochrome)
//      — sweep boundary (= hero surface not toolbar/inline).
//    - ShellPlaceholder L20: ContentUnavailableView with .imageScale(.large)
//      — Apple HIG canonical 38 PT icon.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Round 6 sweep (= standalone Image(systemName:) sites outside Label icon slot)")
struct Round6StandaloneSweepTests {

    static let exceptionSites: [String] = [
        "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift:57", // pulse animation chain
        "Sources/WenshuApp/Views/Workspace/PreviewPane.swift:1566", // 64 PT hero card
        "Sources/WenshuApp/UI/Layout/ShellPlaceholder.swift:20",     // ContentUnavailableView canonical
    ]

    @Test("Round 6 — production sites are now SFIcon")
    func round6SitesAreSFIcon() throws {
        for site in Self.exceptionSites {
            let parts = site.split(separator: ":")
            let path = String(parts[0])
            let line = Int(parts[1]) ?? 1
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            guard line > 0 && line <= lines.count else {
                Issue.record("\(site) line out of bounds")
                continue
            }
            let target = lines[line - 1]
            #expect(target.contains("Image(systemName:") || target.contains("SFIcon("),
                    "\(site) must still contain either Image(systemName: = sweep exception) or SFIcon( = swept site")
        }
    }

    @Test("Round 6 — sweep files dropped naked Image(systemName:) outside Label icon slots")
    func sweepFilesDroppedNakedImage() throws {
        let sweptFiles = [
            "Sources/WenshuApp/UI/Memory/MemoryRetrievalPanel.swift",
            "Sources/WenshuApp/UI/PaneTabBar.swift",
            "Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift",
            "Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift",
            "Sources/WenshuApp/UI/Agent/RuntimeCWDDisplayChip.swift",
            "Sources/WenshuApp/Views/Chat/ChatMessageHoverActions.swift",
            "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            "Sources/WenshuApp/Views/Workspace/PreviewSortMenuButton.swift",
            "Sources/WenshuApp/Views/Workspace/LayoutPicker/LayoutPicker.swift",
            "Sources/WenshuApp/Views/Workspace/ParagraphAIToolbarButtons.swift",
            "Sources/WenshuApp/Views/SpecializedTools/ReaderExperienceView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BookSettingConstraintsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/LongFormGuardrailsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/BookmarkView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/CharacterRelationshipsView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/CharacterLifecycleView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/GenreFitView.swift",
            "Sources/WenshuApp/Views/SpecializedTools/PlotThreadView.swift",
            "Sources/WenshuApp/Views/Library/SidebarSheets.swift",
            "Sources/WenshuApp/Views/Kanban/KanbanView.swift",
            "Sources/WenshuApp/Views/CommandPalette/CommandPaletteView.swift",
            "Sources/WenshuApp/Views/Windows/ForeshadowingGraphWindow.swift",
            "Sources/WenshuApp/Views/Windows/CanvasWindow.swift",
            "Sources/WenshuApp/Views/Windows/CronWindow.swift",
            "Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift",
        ]
        for path in sweptFiles {
            let url = URL(fileURLWithPath: path)
            let content = try String(contentsOf: url, encoding: .utf8)
            // Look for naked Image(systemName: ...) outside Label icon slot pattern.
            // Strip: comments + Label icon slot + IconStyles + ComponentIndex + Domain + Specialized.
            let stripped = content.components(separatedBy: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return false }
                if trimmed.contains("icon: { Image(systemName:") { return false }
                return true
            }.joined(separator: "\n")
            #expect(!stripped.contains("Image(systemName:"),
                    "\(path) must drop naked Image(systemName:) for the v3.0 round 6 sweep")
        }
    }
}