// WenshuChromeOverlay.swift · Wenshu (文枢) · v0.28 followup post-TKT-026
//
// Boss 2026-08-29 OOB '顶栏 + 底栏 + 模型选择 + 上下文用量 看不到' =
// AppTitlebar + AppStatusbar + features were built (= TKT-015/023) but
// NOT wired into AppRoot (= UX not delivered). This file wires them.
//
// Architecture (= matches hermes pane-shell):
// - Titlebar at top (= 34 PT custom, OUTSIDE layout tree)
// - Layout (= 6区 builtinDefault in WorkspaceView, OR legacy
//   LayoutShellView)
// - Statusbar at bottom (= 24 PT custom, OUTSIDE layout tree)
//
// Features bundled (= boss listed):
// - Model selector (= top right cluster titlebar tool)
// - Context usage (= statusbar item)
// - Workspace mode pill (= statusbar item)
// - Sidebar toggle / preview toggle / tools toggle (= top left cluster)

import SwiftUI
import AppKit

/// Chrome overlay (= top titlebar + bottom statusbar wrapping the
/// main content). Apply to any main content (= WorkspaceView or
/// LayoutShellView).
@MainActor
public struct WenshuChromeOverlay<Content: View>: View {
    let titlebarLeftTools: [TitlebarTool]
    let titlebarRightTools: [TitlebarTool]
    let statusbarLeftItems: [StatusbarItem]
    let statusbarRightItems: [StatusbarItem]
    let content: () -> Content

    public init(
        titlebarLeftTools: [TitlebarTool] = [],
        titlebarRightTools: [TitlebarTool] = [],
        statusbarLeftItems: [StatusbarItem] = [],
        statusbarRightItems: [StatusbarItem] = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titlebarLeftTools = titlebarLeftTools
        self.titlebarRightTools = titlebarRightTools
        self.statusbarLeftItems = statusbarLeftItems
        self.statusbarRightItems = statusbarRightItems
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // v0.28 followup Boss UX round 8: Restore AppTitlebar
            // (= custom 32 PT titlebar). Per Boss 2026-08-29 OOB
            // '也不对, 胶囊还在, 只是尺寸调到了最小' = macOS native
            // .toolbar { ... } always wraps icons in 1 unified pill
            // (AppKit NSToolbar behavior, can't be disabled via SwiftUI).
            // The only way to get a flat titlebar with bare icons
            // (= hermes style) is to draw the titlebar manually in
            // SwiftUI (= AppTitlebar = no AppKit container). This
            // bypasses NSToolbar entirely and renders the icons in a
            // custom HStack with no group background.
            //
            // AppTitlebar size = 32 PT (= slightly slimmer than the
            // old 34 PT, matches macOS native titlebar visual height
            // when combined with the 28 PT minimal native titlebar
            // above it). Total titlebar chrome = 28 + 32 = 60 PT
            // (= close to the old 52 PT unified chrome).
            AppTitlebar(
                registry: ContributionRegistry(),
                leftTools: titlebarLeftTools,
                rightTools: titlebarRightTools,
                title: nil
            )
            // Main content (layout).
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Statusbar (bottom, 24 PT) — kept (= not in macOS native
            // titlebar range, separate concern).
            AppStatusbar(
                leftItems: statusbarLeftItems,
                rightItems: statusbarRightItems
            )
        }
        // v0.28 followup: force minimum size so SwiftUI WindowGroup
        // doesn't collapse the window to intrinsic content size.
        .frame(minWidth: 1280, minHeight: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Default chrome (= boss's required features)

/// Default titlebar left tools (= sidebar/preview/tools toggles).
@MainActor
public func defaultWenshuTitlebarLeft(
    sidebarVisible: Bool = true,
    previewVisible: Bool = true,
    toolsVisible: Bool = true,
    onToggleSidebar: @escaping @Sendable () -> Void = {},
    onTogglePreview: @escaping @Sendable () -> Void = {},
    onToggleTools: @escaping @Sendable () -> Void = {}
) -> [TitlebarTool] {
    return defaultTitlebarLeftTools(
        sidebarVisible: sidebarVisible,
        previewVisible: previewVisible,
        onToggleSidebar: onToggleSidebar,
        onTogglePreview: onTogglePreview,
        onToggleTools: onToggleTools
    )
}

/// Default titlebar right tools (= model selector + status).
@MainActor
public func defaultWenshuTitlebarRight(
    modelName: String = "MiniMax-M3",
    contextUsagePercent: Int = 0,
    onSelectModel: @escaping @Sendable () -> Void = {},
    onToggleStatus: @escaping @Sendable () -> Void = {}
) -> [TitlebarTool] {
    var tools = defaultTitlebarRightTools(
        modelName: modelName,
        onSelectModel: onSelectModel
    )
    // Add context usage as a titlebar tool (= "% used" pill).
    let contextBadge = TitlebarTool(
        id: "context-usage",
        label: "Context \(contextUsagePercent)%",
        active: contextUsagePercent > 80,
        iconName: "chart.bar.fill",
        onSelect: onToggleStatus,
        badge: contextUsagePercent > 80 ? 1 : nil,
        actionId: "view.contextUsage"
    )
    tools.append(contextBadge)
    return tools
}

/// Default statusbar left items (= model + status + workspace mode).
@MainActor
public func defaultWenshuStatusbarLeft(
    modelName: String = "MiniMax-M3",
    llmStatus: String = "Idle",
    contextUsagePercent: Int = 0,
    workspaceMode: String = "Sessions"
) -> [StatusbarItem] {
    var items = defaultStatusbarLeftItems(
        modelName: modelName,
        llmStatus: llmStatus
    )
    // Add context usage as a statusbar item.
    if contextUsagePercent > 0 {
        items.append(StatusbarItem(
            id: "context-usage",
            detail: "\(contextUsagePercent)%",
            iconName: "chart.bar.fill",
            title: "Context usage",
            toggleLabel: "Context"
        ))
    }
    return items
}

/// Default statusbar right items (= version + workspace mode).
@MainActor
public func defaultWenshuStatusbarRight(
    version: String = "v0.28",
    workspaceMode: String = "Sessions"
) -> [StatusbarItem] {
    var items = defaultStatusbarRightItems(version: version)
    items.append(StatusbarItem(
        id: "workspace-mode",
        label: workspaceMode,
        iconName: "rectangle.3.group",
        title: "Workspace mode",
        toggleLabel: "Workspace Mode"
    ))
    return items
}