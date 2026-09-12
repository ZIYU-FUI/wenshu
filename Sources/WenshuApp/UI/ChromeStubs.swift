// ChromeStubs.swift
//
// v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': stub file
// for the deleted chrome types (= ZonePerRegionChrome, RegionTabBar,
// PaneStatusBar, RegionContentBackground, chromeBottomBarStyle,
// chromeZoneBackgroundStyle, regionContentBackground) so the
// legacy PaneSplitHost path (= default flag `wenshu.useThreeColumnSplit = false`)
// keeps compiling (= the old path is dead at runtime, but the
// code is preserved in the tree per project baseline). Each
// stub is a no-op pass-through (= no chrome wrapping = old path
// renders bare content = matches Plan A = Apple-native chrome
// only).
//
// The 3-column M1 NavigationSplitShell is the active path; = the
// stubs here are ONLY consumed by legacy path code. When the old path
// is fully removed (= future ticket = cleanup of
// WorkspaceView + TabContentDispatcher + EditorContentPlaceholder
// + PreviewTabBackground + ChatZoneTabBar + ZoneContentView +
// NewLibraryOutlineView), this stub file can be deleted.
//
// Per boss 2026-09-08 OOB 'Plan A: full Apple native': the entire
// wenshu UI layer must rely on Apple's built-in NavigationSplitView
// Liquid Glass material (= WWDC25-219 'Liquid Glass is composed
// of a number of layers that work together' = no custom chrome
// wrappers). These stubs preserve compile-only compatibility
// (= no chrome behavior) until the old path is deleted.

import SwiftUI

// MARK: - ZonePerRegionChrome stub

/// Stub of the deleted `ZonePerRegionChrome` wrapper.
/// Old path renders the content directly (= no chrome wrapper).
struct ZonePerRegionChrome<Content: View>: View {
    let zone: ZoneType
    let topActions: [ZoneAction]
    let bottomStatus: ZoneBottomStatus
    let topSkip: Bool
    let bottomSkip: Bool
    let content: () -> Content

    init(
        topActions: [ZoneAction] = [],
        bottomStatus: ZoneBottomStatus = ZoneBottomStatus(left: "", right: ""),
        topSkip: Bool = false,
        zone: ZoneType = .projectSidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.zone = zone
        self.topActions = topActions
        self.bottomStatus = bottomStatus
        self.topSkip = topSkip
        self.bottomSkip = false
        self.content = content
    }

    init(
        zone: ZoneType = .projectSidebar,
        topActions: [ZoneAction] = [],
        bottomStatus: ZoneBottomStatus = ZoneBottomStatus(left: "", right: ""),
        topSkip: Bool = false,
        bottomSkip: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.zone = zone
        self.topActions = topActions
        self.bottomStatus = bottomStatus
        self.topSkip = topSkip
        self.bottomSkip = bottomSkip
        self.content = content
    }

    init(
        topActions: [ZoneAction] = [],
        bottomStatus: ZoneBottomStatus = ZoneBottomStatus(left: "", right: ""),
        topSkip: Bool = false,
        bottomSkip: Bool = false,
        zone: ZoneType = .projectSidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.zone = zone
        self.topActions = topActions
        self.bottomStatus = bottomStatus
        self.topSkip = topSkip
        self.bottomSkip = bottomSkip
        self.content = content
    }

    var body: some View {
        // Plan A: pass-through. No chrome wrapper (= Apple-native = no custom layer).
        content()
    }
}

// MARK: - RegionTabBar stub

/// Stub of the deleted `RegionTabBar` wrapper (= Plan A pass-through).
struct RegionTabBar<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}

// MARK: - PaneStatusBar stub

/// Stub of the deleted `PaneStatusBar` (= Plan A pass-through).
struct PaneStatusBar: View {
    let left: String
    let right: String

    init(left: String = "", right: String = "") {
        self.left = left
        self.right = right
    }

    var body: some View {
        // Plan A: pass-through. No status bar (= Apple-native = no custom layer).
        EmptyView()
    }
}

// MARK: - ZoneType stub

/// Stub of the deleted `ZoneType` enum (= referenced by old-path callers).
enum ZoneType: String {
    case projectSidebar
    case projectPreview
    case editor
    case aiChat
    case aiDynamic
    case kanban
    case memory
    case specializedTools
}

// MARK: - ZoneAction stub

/// Stub of the deleted `ZoneAction` type (= referenced by old-path callers).
struct ZoneAction: Equatable {
    let id: String
    let label: String
    let icon: String
}

// MARK: - ZoneBottomStatus stub

/// Stub of the deleted `ZoneBottomStatus` type (= referenced by old-path callers).
struct ZoneBottomStatus: Equatable {
    let left: String
    let right: String
    let rightOnTap: (() -> Void)?

    init(left: String, right: String, rightOnTap: (() -> Void)? = nil) {
        self.left = left
        self.right = right
        self.rightOnTap = rightOnTap
    }

    // Equatable: ignore rightOnTap (= function reference).
    static func == (lhs: ZoneBottomStatus, rhs: ZoneBottomStatus) -> Bool {
        lhs.left == rhs.left && lhs.right == rhs.right
    }
}

// MARK: - Old-path chrome helper stubs (Plan A pass-through)

/// Stub of the deleted `projectSidebarChrome` helper (= Plan A = returns empty bottom status).
func projectSidebarChrome(shelfCount: Int, bookCount: Int) -> (bottom: ZoneBottomStatus, top: [ZoneAction]) {
    (ZoneBottomStatus(left: "", right: ""), [])
}

/// Stub of the deleted `projectPreviewChrome` helper (= Plan A = returns empty bottom status).
func projectPreviewChrome(chapterCount: Int) -> (bottom: ZoneBottomStatus, top: [ZoneAction]) {
    (ZoneBottomStatus(left: "", right: ""), [])
}

/// Stub of the deleted `specializedToolsChrome` helper (= Plan A = returns empty bottom status).
func specializedToolsChrome() -> (bottom: ZoneBottomStatus, top: [ZoneAction]) {
    (ZoneBottomStatus(left: "", right: ""), [])
}

/// Stub of the deleted `aiChatChrome` helper (= Plan A = returns empty bottom status).
func aiChatChrome() -> (bottom: ZoneBottomStatus, top: [ZoneAction]) {
    (ZoneBottomStatus(left: "", right: ""), [])
}

/// Stub of the deleted `aiDynamicChrome` helper (= Plan A = returns empty bottom status).
func aiDynamicChrome() -> (bottom: ZoneBottomStatus, top: [ZoneAction]) {
    (ZoneBottomStatus(left: "", right: ""), [])
}

// MARK: - View extension stubs (Plan A pass-through)

extension View {
    /// Stub of the deleted `chromeBottomBarStyle` modifier (= Plan A pass-through).
    func chromeBottomBarStyle(zone: ZoneType) -> some View {
        self
    }

    /// Stub of the deleted `chromeZoneBackgroundStyle` modifier (= Plan A pass-through).
    func chromeZoneBackgroundStyle(zone: ZoneType) -> some View {
        self
    }

    /// Stub of the deleted `regionContentBackground` modifier (= Plan A pass-through).
    func regionContentBackground() -> some View {
        self
    }

    /// Stub of the deleted `chromeTopBarStyle` modifier (= Plan A pass-through).
    func chromeTopBarStyle() -> some View {
        self
    }
}
