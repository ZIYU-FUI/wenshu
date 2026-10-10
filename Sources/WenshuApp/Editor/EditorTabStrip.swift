// Sources/WenshuApp/Editor/EditorTabStrip.swift
//
// Safari-style multi-tab strip for the editor zone. Self-written
// in SwiftUI (= Apple has no 1:1 equivalent for Safari modern
// pill tab; = Safari's tab strip is private to Safari.app). This
// component replaces the ad-hoc HStack in EditorView.swift:140-171
// (= previously showed only the active tab; = no drag reorder /
// close X / overflow scroll / visible inactive tabs).
//
// Scope (= per boss OOB 2026-10-10): editor zone ONLY. The 9
// single-instance Window(id:) panels (= kanban / todo / canvas /
// composer / ...) and the main WindowGroup are not touched.
//
// Design references:
//   - Sources/WenshuApp/UI/PaneTabBar.swift (= the existing
//     Apple HIG per-pane icon tab bar = 28 PT hot area, SF Symbols 6,
//     matchedGeometryEffect selected-state underline). This component
//     extends the same patterns into a per-document tab bar (= title
//     label + close X + overflow scroll + drag reorder).
//   - Apple's Safari.app (= the visual reference: round-pill
//     inactive tabs, accent-tinted active tab with bottom
//     border, small × close button on hover, horizontal scroll
//     when tabs overflow).
//
// API shape: the SwiftUI View exposes 3 state-binding callbacks
// (= onSelect / onClose / onReorder). EditorView stays in charge
// of AppState (= openTabs + activeTabId) so the strip stays a
// pure render surface (= zero internal state mutation outside
// SwiftUI diffing).

import SwiftUI

/// Safari-style multi-tab strip for the editor zone.
@MainActor
struct EditorTabStrip: View {

    /// The tabs to render, in display order (= `openTabs` array
    /// order in AppState). Drag-reorder reorders this view's
    /// internal display, then surfaces the new order back to the
    /// caller via `onReorder`.
    let tabs: [EditorTab]

    /// Currently active tab id (= drives the accent-tinted + bottom-
    /// border render on the matching tab). Nil = no tab selected
    /// (= the caller should hide the entire strip in that case).
    let selectedTabId: UUID?

    /// Fired when the user picks a different tab. Caller writes
    /// this back to `AppState.activeTabId`.
    let onSelect: (UUID) -> Void

    /// Fired when the user clicks the close X. Caller routes
    /// through `AppState.closeTab(id:bookStore:)` (= which handles
    /// dirty-flush + confirmation alert in one place).
    let onClose: (UUID) -> Void

    /// Fired after the user drag-reorders tabs. The argument is
    /// the new tab id order (= the caller's job to rewrite
    /// `AppState.openTabs` to match and re-persist).
    let onReorder: ([UUID]) -> Void

    /// SwiftUI namespace for the matchedGeometryEffect underline
    /// (= Apple's HIG convention for the slide animation between
    /// tab selected states; = same pattern as PaneTabBar).
    @Namespace private var tabBarNamespace

    /// Tab id currently being dragged (= E2E drag-reorder source of
    /// truth during the gesture lifetime). = nil on idle.
    @State private var draggingTabId: UUID?

    /// Tab id currently the drop target (= E2E drag-reorder
    /// destination highlight). = nil on idle.
    @State private var dropTargetTabId: UUID?

    /// Tab ids in display order (= tracked separately from
    /// `tabs` parameter for two reasons: (1) drag-reorder mutates
    /// the local order before the caller persists it; (2) SwiftUI
    /// ForEach uses this id list for stable identity across
    /// re-renders). Initialized from `tabs` on each render.
    @State private var displayOrder: [UUID] = []

    /// Last seen `tabs` array (= detects when the caller added /
    /// removed tabs externally so we can prune displayOrder).
    @State private var lastSeenTabIds: [UUID] = []

    var body: some View {
        // Boss 2026-10-10 G2 verdict = "0 个 tab 打开时不显示条",
        // = the editor zone's empty-state hint takes the full body.
        // Hide the entire strip when there are no tabs.
        if tabs.isEmpty {
            EmptyView()
        } else {
            stripContent
        }
    }

    /// The actual tab strip (= ScrollView of tabs). Extracted from
    /// `body` to keep the empty-state guard at the top level
    /// (= no ScrollView rendered when the array is empty = zero
    /// hit-area even though it's empty).
    @ViewBuilder
    private var stripContent: some View {
        // Sync displayOrder with the caller's `tabs` parameter (= an
        // external add/remove that doesn't go through drag-reorder
        // must still propagate). The order is preserved when both
        // arrays contain the same ids in the same positions (= no
        // drag-reorder in flight).
        let _ = syncDisplayOrderIfNeeded()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingCaption) {
                ForEach(displayOrder, id: \.self) { tabId in
                    if let tab = tabs.first(where: { $0.id == tabId }) {
                        tabButton(for: tab)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.spacingStandard)
            .padding(.vertical, DesignTokens.spacingCaption)
        }
        .background(.regularMaterial)
        .frame(height: DesignTokens.paneTabHotArea + DesignTokens.spacingCaption * 2)
    }

    /// Render a single tab (= title label + close X).
    @ViewBuilder
    private func tabButton(for tab: EditorTab) -> some View {
        let isActive = tab.id == selectedTabId
        let isDropTarget = tab.id == dropTargetTabId && draggingTabId != nil

        HStack(spacing: DesignTokens.spacingCaption) {
            Text(EditorTab.displayTitle(tab))
                .font(isActive ? .body.weight(.medium) : .body)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Button(action: { onClose(tab.id) }) {
                SFIcon("xmark", style: .inlineSmall, color: IconColor.secondary)
                    .frame(width: DesignTokens.tabCloseFrameSize,
                           height: DesignTokens.tabCloseFrameSize)
            }
            .buttonStyle(.plain)
            .help(String(localized: "workspace.editor.close_tab_tooltip"))
        }
        .padding(.horizontal, DesignTokens.spacingModerate)
        .frame(height: DesignTokens.paneTabHotArea)
        .background {
            // Active tab background (= Safari's accent-tinted active
            // tab). Non-active tabs render transparent.
            if isActive {
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                    .fill(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle))
            }
        }
        .overlay(alignment: .bottom) {
            // Active-state underline (= matchedGeometryEffect for the
            // slide animation when the user picks another tab).
            // Matches the PaneTabBar.paneTabHotArea underline height.
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: DesignTokens.tabUnderlineHeight)
                    .matchedGeometryEffect(id: "editorTabUnderline", in: tabBarNamespace, properties: .frame)
                    .clipShape(Capsule())
                    .padding(.horizontal, DesignTokens.spacingCaption)
            }
        }
        .background {
            // Drop-target highlight (= the user is hovering a tab
            // during a drag-reorder gesture). Renders a hairline
            // outline so the user sees where the dragged tab will
            // land.
            if isDropTarget {
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                    .strokeBorder(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle), lineWidth: DesignTokens.surfaceShadowRadiusButton)
            }
        }
        .contentShape(Rectangle())
        // Tab selection = left-click anywhere on the title row
        // (= excluding the close X; = SwiftUI's gesture system
        // dispatches the close-X Button click first because it's a
        // child control).
        .onTapGesture { onSelect(tab.id) }
        // Drag source (= the entire tab row is draggable; = the
        // user grabs the title or any empty space inside).
        .onDrag {
            draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        // Drop target (= any tab can be a drop target during a drag
        // gesture). Apple HIG multi-tab pattern: dropping a tab ON a
        // tab reorders to land adjacent to that target (= we insert
        // before the drop target in step 2 of handleDrop).
        .onDrop(of: [.text], delegate: TabDropDelegate(
            tabId: tab.id,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId,
            displayOrder: $displayOrder,
            onReorder: onReorder
        ))
    }

    /// Sync `displayOrder` with the caller's `tabs` array when the
    /// array's id list changes (= external add / remove / reorder
    /// from AppState). Drag-reorder mutates `displayOrder` directly,
    /// so this sync must not undo it.
    private func syncDisplayOrderIfNeeded() {
        let incomingIds = tabs.map(\.id)

        // 1. Add new ids (= caller added a tab externally; = append
        // in the position they specified).
        if incomingIds != displayOrder {
            // Filter out stale ids (= displayOrder might contain ids
            // the caller removed; = drop them). Add new ids in their
            // caller-specified position (= covers add-new at any
            // position, not just append).
            var newOrder: [UUID] = []
            for id in incomingIds {
                if let existing = displayOrder.first(where: { $0 == id }) {
                    newOrder.append(existing)
                } else {
                    // New id (= not in previous displayOrder) = add
                    // at the caller's position. This preserves the
                    // caller's `openTabs` ordering exactly.
                    newOrder.append(id)
                }
            }
            // If the caller removed tabs (= ids in displayOrder but
            // not in incomingIds), drop them from newOrder. The
            // above loop already does this (= only iterates incoming).
            displayOrder = newOrder
        }

        lastSeenTabIds = incomingIds
    }
}

/// Drag-and-drop delegate for tab reorder. SwiftUI's `.onDrop(of:delegate:)`
/// pattern requires a delegate (= a NSObject + protocol witness). We
/// use a per-tab delegate (= the closure captures the destination tab
/// id + the binding setters).
@MainActor
private struct TabDropDelegate: DropDelegate {
    let tabId: UUID
    @Binding var draggingTabId: UUID?
    @Binding var dropTargetTabId: UUID?
    @Binding var displayOrder: [UUID]
    let onReorder: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        // Highlight the drop target while the drag is over it.
        if draggingTabId != nil && draggingTabId != tabId {
            dropTargetTabId = tabId
        }
    }

    func dropExited(info: DropInfo) {
        // Clear the drop-target highlight when the drag leaves.
        if dropTargetTabId == tabId {
            dropTargetTabId = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            // Reset drag state on drop complete (= success or
            // failure).
            draggingTabId = nil
            dropTargetTabId = nil
        }

        guard let draggingId = draggingTabId else { return false }
        guard draggingId != tabId else { return false }

        // Reorder displayOrder: insert `draggingId` immediately
        // before `tabId` (= the drop target). If `draggingId` is
        // already before `tabId`, no-op.
        guard let draggingIdx = displayOrder.firstIndex(of: draggingId),
              let targetIdx = displayOrder.firstIndex(of: tabId) else {
            return false
        }

        // Remove the dragged tab from its old position.
        let movingId = displayOrder.remove(at: draggingIdx)
        // Recompute the target index (= it may have shifted if the
        // dragged tab was before it).
        let newTargetIdx = displayOrder.firstIndex(of: tabId) ?? displayOrder.count
        displayOrder.insert(movingId, at: newTargetIdx)

        // Surface the new order to the caller (= AppState rewrites
        // openTabs + persists).
        onReorder(displayOrder)
        return true
    }
}