// RegisteredPanes.swift · Wenshu (文枢) · v0.28 followup TKT-028-016
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// pane registration pattern from Hermes Desktop verbatim. New pane
// type = 1 registry.register() call (= no edit to PaneRenderer).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/app/contrib/panes.tsx
// = FilesPane + PreviewPane + ReviewPane + LogsPane registered via
//   registry.register({ area: 'panes', id, render, ... })
//
// This file provides:
// 1. `registerBuiltinPanes(_:)` registers all 6 default wenshu panes
//    with the registry (= projectSidebar + projectPreview + editor +
//    specializedTools + aiChat + aiDynamic).
// 2. `renderTabByKind(_:in:)` replaces the PaneRenderer switch with
//    a registry lookup (= new pane = 1 register call, no renderer edit).

import Foundation
import SwiftUI

/// Register all builtin wenshu panes with the registry. Idempotent
/// (= safe to call multiple times; re-registering same id replaces).
@MainActor
func registerBuiltinPanes(_ registry: ContributionRegistry) {
    // 1. Project sidebar (= left zone).
    registry.register(Contribution(
        id: TabKind.projectSidebar.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Sidebar",
        order: 10,
        render: {
            // v0.30: NewLibraryOutlineView has default dummy binding init.
            AnyView(NewLibraryOutlineView())
        }
    ))
    // 2. Project preview (= top-center-left zone).
    registry.register(Contribution(
        id: TabKind.projectPreview.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Preview",
        order: 20,
        render: {
            // v0.30: ZoneModuleView has default dummy binding initializer,
            // so the call site can omit the binding args.
            AnyView(ZoneModuleView(zoneSlot: .projectPreview))
        }
    ))
    // 3. Editor (= top-center-right zone).
    registry.register(Contribution(
        id: TabKind.editor.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Editor",
        order: 30,
        render: {
            AnyView(EditorPlaceholder())
        }
    ))
    // 4. Specialized tools (= top-right zone).
    registry.register(Contribution(
        id: TabKind.specializedTools.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Tools",
        order: 40,
        render: {
            // v0.30: default-init available.
            AnyView(ZoneModuleView(zoneSlot: .specializedTools))
        }
    ))
    // 5. AI chat (= lower-left zone).
    registry.register(Contribution(
        id: TabKind.aiChat.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Chat",
        order: 50,
        render: {
            AnyView(ChatView())
        }
    ))
    // 6. AI dynamic (= lower-right zone).
    registry.register(Contribution(
        id: TabKind.aiDynamic.rawValue,
        area: ContributionArea.panes,
        source: "core",
        title: "Dynamic",
        order: 60,
        render: {
            // v0.30: default-init available.
            AnyView(ZoneModuleView(zoneSlot: .aiDynamic))
        }
    ))
}

/// Resolve a TabKind to its registered pane contribution (= lookup
/// via ContributionRegistry). Returns nil if not registered (= caller
/// falls back to legacy switch dispatch).
@MainActor
func contributionForTabKind(
    _ kind: TabKind,
    in registry: ContributionRegistry
) -> Contribution? {
    return registry.getArea(ContributionArea.panes).first { $0.id == kind.rawValue }
}

/// Render a tab via the registry lookup (= replaces the legacy switch
/// in PaneRenderer). Falls back to legacy switch if not registered.
@MainActor
@ViewBuilder
func renderTabByRegistry(
    _ kind: TabKind,
    registry: ContributionRegistry
) -> some View {
    if let c = contributionForTabKind(kind, in: registry), let render = c.render {
        render()
    } else {
        // Fallback = legacy switch (= always works for builtin panes).
        renderTabByKindFallback(kind)
    }
}

/// Legacy switch (= kept for backward compat + fallback). This is the
/// EXACT body from `WorkspaceView.renderTabByKind` + `TabContentDispatcher`.
@MainActor
@ViewBuilder
private func renderTabByKindFallback(_ kind: TabKind) -> some View {
    switch kind {
    case .projectSidebar:
        // v0.30: NewLibraryOutlineView has default dummy binding initializer.
        NewLibraryOutlineView()
    case .projectPreview:
        // v0.30: ZoneModuleView has default dummy binding initializer.
        ZoneModuleView(zoneSlot: .projectPreview)
    case .editor:
        EditorPlaceholder()
    case .specializedTools:
        // v0.30: default-init available.
        ZoneModuleView(zoneSlot: .specializedTools)
    case .aiChat:
        ChatView()
    case .aiDynamic:
        // v0.30: default-init available.
        ZoneModuleView(zoneSlot: .aiDynamic)
    }
}