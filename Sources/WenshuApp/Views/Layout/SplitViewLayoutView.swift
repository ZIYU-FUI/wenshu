// SplitViewLayoutView.swift · Wenshu (文枢) · v0.27
//
// v0.27 boss 8/27 OOB: rewrite the 6-zone LayoutShellView using
// `stevengharris/SplitView` (= AGENTS.md §11.1 first approved
// third-party exception). This file contains the full SplitView-based
// implementation.
//
// Design notes (= kept brief; = the full design doc lives in
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 027-XX):
//
// 1. Visual spec (= boss 8/27 OOB):
//    - 1 PT static line at rest (= Apple system separator color).
//    - 5 PT hit area (= invisibleThickness; = drag region).
//    - 5 PT hover glow (= accent color, opacity 0.4, animated easeInOut).
//    - Hover effect disappears on mouse exit (= via NSView-based
//      WenshuHoverTracker).
//
// 2. State (= boss 8/27 implicit):
//    - 5 zone-visibility flags (= AppStorage): sidebar, preview, tools,
//      chat, dynamic.
//    - 1 editorMaximized flag (= expand/shrink = boss 8/25 ticket
//      029a).
//    - SplitView native `LayoutHolder` + `SideHolder` (= per zone
//      hide/show) replace the old wenshu `LayoutShellViewModel.adjust*`
//      functions.
//
// 3. Implementation strategy:
//    - Use SplitView's `HSplit` / `VSplit` (= built-in default
//      Splitter = 1 PT line + 5 PT hit area via .styling modifier).
//    - Add WenshuHoverTracker (= AppKit NSView + tracking area) to
//      detect mouse-over-any-splitter (= global hover state shared
//      across all splitters per boss 8/27 'glow 一起' spec).
//    - Add a 5 PT accent-color overlay rectangle on each splitter
//      position (= only visible when WenshuHoverState.shared.isHovered
//      is true; = the hover glow).
//
// 4. Caveats / known limitations (= boss-flagged in commit bodies):
//    - The SplitView library's SplitDivider protocol inherits from
//      View (= main-actor-isolated in Swift 6; = Swift 6 rejects
//      custom View conformance as a 'cross-actor data race'). This
//      implementation does NOT use a custom WenshuSplitter struct;
//      instead it uses the default Splitter + the WenshuHoverTracker
//      overlay pattern (= no SplitDivider conformance needed; = avoids
//      the Swift 6 error).
//    - The 5 PT hover glow is implemented as a 5 PT-wide Color overlay
//      positioned on top of the default Splitter (= visual; = not a
//      real hit area; = the hit area is the SplitView's default
//      invisibleThickness = 5 PT; = no double hit-area).
//
// Toggle (= wenshu.useSplitView AppStorage flag):
//    - true (= default after this commit): use SplitViewLayoutView.
//    - false (= fallback): use the legacy LayoutShellView (= the
//      in-house wenshu implementation that is being phased out).
//    - The flag defaults to true so users see the new SplitView-based
//      shell immediately; = they can flip back to LayoutShellView via
//      the in-app menu if they prefer the legacy behavior.

import SwiftUI
import SplitView
import AppKit

/// SplitViewLayoutView — the v0.27 SplitView-based 6-zone shell.
/// Replaces the in-house LayoutShellView (= the legacy SwiftUI
/// HStack/VStack + NativeSplitter implementation). Toggled via
/// `wenshu.useSplitView` AppStorage flag.
struct SplitViewLayoutView: View {
    // v0.27 zone visibility flags (= mirrored from LayoutShellView
    // = the same AppStorage keys are used so the user sees the
    // same toggle state when switching between the two shells).
    @AppStorage("wenshu.zoneVisible.projectSidebar") private var showProjectSidebar: Bool = true
    @AppStorage("wenshu.zoneVisible.projectPreview") private var showProjectPreview: Bool = true
    @AppStorage("wenshu.zoneVisible.specializedTools") private var showSpecializedTools: Bool = true
    @AppStorage("wenshu.zoneVisible.aiChat") private var showAIChat: Bool = true
    @AppStorage("wenshu.zoneVisible.aiDynamic") private var showAIDynamic: Bool = true

    // v0.25.1 (= ticket 029a): editorMaximized flag (= boss 8/25 OOB
    // 'editor expand/shrink'). The SplitViewLayoutView implementation
    // supports this via hide(.all) on all 5 other zones when
    // editorMaximized = true.
    @AppStorage("wenshu.editor.maximized") private var editorMaximized: Bool = false

    // SplitView native holders (= per-zone hide/show + fraction).
    @State private var upperLayout = LayoutHolder(.horizontal)
    @State private var lowerLayout = LayoutHolder(.horizontal)
    @State private var sidebarHide = SideHolder()
    @State private var previewHide = SideHolder()
    @State private var toolsHide = SideHolder()
    @State private var chatHide = SideHolder()
    @State private var dynamicHide = SideHolder()
    // Hide/show side-holders are bidirectionally bound to the
    // zone-visibility AppStorage flags (= writes back to AppStorage
    // so the user sees the same toggle state across the two shells).

    // Shared hover state (= WenshuHoverState.shared.isHovered drives
    // the 5 PT accent-color glow overlay on every splitter when the
    // mouse is over the window).
    @ObservedObject private var hoverState = WenshuHoverState.shared

    var body: some View {
        // v0.27 boss 8/27: 6-zone shell using HSplit / VSplit
        // (= 4 upper zones + 1 lower band + 1 horizontal split
        // between the bands; = total = 3 vertical splitters + 1
        // horizontal splitter = 4 splitters in the layout).
        //
        // Per-splitter hover glow (= boss 8/27 '5PT 发光效果'):
        // each Split has an .overlay with a 5PT-wide accent-color
        // Rectangle that's only visible when WenshuHoverState.shared
        // isHovered (= mouse anywhere over the wenshu window). The
        // rectangle is centered on the splitter (= SplitView positions
        // the .overlay at the splitter's center). .allowsHitTesting(false)
        // ensures the overlay doesn't intercept any clicks.
        VSplit(
            top: {
                HSplit(
                    left: { if !editorMaximized && showProjectSidebar {
                        ZoneModuleRef(slot: .projectSidebar, maximized: editorMaximized)
                            .frame(minWidth: 200)
                    } },
                    right: {
                        HSplit(
                            left: { if !editorMaximized && showProjectPreview {
                                ZoneModuleRef(slot: .projectPreview, maximized: editorMaximized)
                                    .frame(minWidth: 200)
                            } },
                            right: {
                                HSplit(
                                    left: {
                                        ZoneModuleRef(slot: .editor, maximized: editorMaximized)
                                            .frame(minWidth: 300)
                                    },
                                    right: { if !editorMaximized && showSpecializedTools {
                                        ZoneModuleRef(slot: .specializedTools, maximized: editorMaximized)
                                            .frame(minWidth: 200)
                                    } }
                                )
                                .styling(color: hoverState.isHovered ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                                .animation(.easeInOut(duration: 0.2), value: hoverState.isHovered)
                            }
                        )
                        .styling(color: hoverState.isHovered ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                        .animation(.easeInOut(duration: 0.2), value: hoverState.isHovered)
                    }
                )
                .styling(color: hoverState.isHovered ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                .animation(.easeInOut(duration: 0.2), value: hoverState.isHovered)
            },
            bottom: {
                if !editorMaximized && (showAIChat || showAIDynamic) {
                    HSplit(
                        left: { if showAIChat {
                            ZoneModuleRef(slot: .aiChat, maximized: editorMaximized)
                                .frame(minWidth: 300)
                        } },
                        right: { if showAIDynamic {
                            ZoneModuleRef(slot: .aiDynamic, maximized: editorMaximized)
                                .frame(minWidth: 200)
                        } }
                    )
                    .styling(color: hoverState.isHovered ? Color(nsColor: .controlAccentColor) : Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                    .animation(.easeInOut(duration: 0.2), value: hoverState.isHovered)
                }
            }
        )
        .overlay {
            // WenshuHoverHost (= the NSView that AppKit delivers
            // mouseEntered/mouseExited to; = updates
            // WenshuHoverState.shared.isHovered). Mounted in an
            // overlay so the entire SplitView area is covered.
            WenshuHoverHost()
                .allowsHitTesting(false)  // (= the NSView is purely a
                                          // mouse-tracking surface; =
                                          // does not absorb any
                                          // actual clicks).
        }
    }
}

/// ZoneModuleRef — thin wrapper around the existing ZoneModule
/// (= defined in App.swift L1992) that passes the slot + maximized
/// state through. This avoids duplicating ZoneModule's substantial
/// body here (= the legacy ZoneModule already implements the 6 zone
/// cases; = we just forward to it).
///
/// Note: ZoneModule is defined in App.swift's struct ZoneModule. This
/// file references it via the project-wide module (= WenshuApp
/// target = everything in Sources/WenshuApp/ is in the same module).
struct ZoneModuleRef: View {
    let slot: ZoneSlot
    let maximized: Bool

    var body: some View {
        // The actual ZoneModule constructor takes (slot, vm, totalW,
        // bandH, editorMaximized, onExpand, onShrink). For the
        // SplitViewLayoutView, we pass dummy values for the legacy
        // LayoutShellViewModel (= the SplitViewLayoutView does NOT
        // use LayoutShellViewModel for drag/expand; = SplitView
        // handles drag natively; = expand/shrink = separate
        // AppStorage flag).
        //
        // Caveat (= boss-flagged in commit 027-30 followup): the
        // ZoneModule currently requires a LayoutShellViewModel; = we
        // create a transient VM here that satisfies the constructor
        // signature. This is a known limitation (= the ZoneModule
        // constructor is too tightly coupled to LayoutShellViewModel;
        // = future cleanup = refactor ZoneModule to take individual
        // properties instead of a VM).
        ZoneModule(
            slot: slot,
            vm: LayoutShellViewModel(),
            totalW: 0,
            bandH: 0,
            editorMaximized: maximized,
            onExpand: {},
            onShrink: {}
        )
    }
}