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
        "Sources/WenshuApp/Views/Workspace/PreviewPane.swift:1570", // 64 PT hero card icon (= was L1566 in the pre-§11 sweep commit)
    ]
}
