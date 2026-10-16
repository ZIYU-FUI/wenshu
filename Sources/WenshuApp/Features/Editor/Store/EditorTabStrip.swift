// Sources/WenshuApp/Editor/EditorTabStrip.swift
// … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
// SwiftUI diffing).
import SwiftUI

/// Safari-style multi-tab strip for the editor zone.
@MainActor
struct EditorTabStrip: View {

    // / The tabs to render, in display order (= `openTabs` array order in
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / surfaces the new order back to the caller via `onReorder`.
    let tabs: [EditorTab]

    // / Currently active tab id (= drives the accent-tinted + bottom- border
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / hide the entire strip in that case).
    let selectedTabId: UUID?

    /// Fired when the user picks a different tab. Caller writes this back to
    /// `AppState.activeTabId`.
    let onSelect: (UUID) -> Void

    // / Fired when the user clicks the close X. Caller routes through
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / confirmation alert in one place).
    let onClose: (UUID) -> Void

    // / Fired after the user drag-reorders tabs. The argument is the new tab id
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / re-persist).
    let onReorder: ([UUID]) -> Void

    // / SwiftUI namespace for the matchedGeometryEffect underline (= Apple's HIG
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pattern as PaneTabBar).
    @Namespace private var tabBarNamespace

    /// Tab id currently being dragged (= E2E drag-reorder source of truth
    /// during the gesture lifetime). = nil on idle.
    @State private var draggingTabId: UUID?

    /// Tab id currently the drop target (= E2E drag-reorder destination
    /// highlight). = nil on idle.
    @State private var dropTargetTabId: UUID?

    // / Tab ids in display order (= tracked separately from `tabs` parameter for
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / across re-renders). Initialized from `tabs` on each render.
    @State private var displayOrder: [UUID] = []

    /// Last seen `tabs` array (= detects when the caller added / removed tabs
    /// externally so we can prune displayOrder).
    @State private var lastSeenTabIds: [UUID] = []
    // / live column width (= the editor column's current width; = updated by
    // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / behavior).
    @State private var columnWidth: CGFloat = 0

    var body: some View {
        // RATIONALE: per Apple HIG SwiftUI macOS 27 + the Safari
        // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // shift; = the caller's responsibility, not this view's.
        stripContent
    }

    // / The actual tab strip (= ScrollView of tabs + empty-state + button).
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / tabs would).
    @ViewBuilder
    private var stripContent: some View {
        // RATIONALE: the strip body is a VStack (= tab-pill
        // … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // strip's bottom 1 PT).
        VStack(spacing: 0) {
            // Sync displayOrder with the caller's `tabs` parameter.
            // … (= 208 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // VStack).
            let control = LabelSegmentedControl(
                selection: Binding(
                    get: { selectedTabId ?? UUID() },
                    set: { newId in onSelect(newId) }
                ),
                labels: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId })
                        .map { $0.id }
                },
                displayStrings: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId }).map {
                        EditorTab.displayTitle($0)
                    }
                },
                iconStyle: .paneTab,
                onDoubleClickSegment: { segmentIndex in
                    guard segmentIndex >= 0 && segmentIndex < displayOrder.count else { return }
                    onClose(displayOrder[segmentIndex])
                },
                // 
                // … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // column).
                fixedSegmentWidth: 0
            )
            // 2026-10-14 v3: wrap the
            // … (= 84 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // layout.
            control
            // RATIONALE: the tab strip's
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // top inset).
            .padding(.top, DesignTokens.spacingHero - 10)
            .padding(.bottom, 0)
            // RATIONALE: the manual
            // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // hairlines).
        }
        // RATIONALE: the tab pills
        // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // right).
        .frame(maxWidth: .infinity, alignment: .leading)
        // capture
        // … (= 30 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // `columnWidth`).
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        // RATIONALE: the strip background is `Color.clear` (= a
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // anchor, not the Liquid Glass material).
        .background(Color.clear)
        // RATIONALE: the strip's frame height = `paneTabHotArea`
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // Apple-canonical inset).
        .frame(height: DesignTokens.paneTabHotArea)
        // RATIONALE: boss visual diff 2026-10-13 — add 2 PT
        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the named token).
        .padding(.top, DesignTokens.spacingCaption)
        .onChange(of: tabs.map(\.id), initial: true) { _, incomingIds in
            // Sync is a no-op if the id list already matches the
            // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // without the initial empty-array glitch).
            if incomingIds != lastSeenTabIds {
                var newOrder: [UUID] = []
                for id in incomingIds {
                    if let existing = displayOrder.first(where: { $0 == id }) {
                        newOrder.append(existing)
                    } else {
                        newOrder.append(id)
                    }
                }
                displayOrder = newOrder
                lastSeenTabIds = incomingIds
            }
        }
    }

    // / Render a single tab (= title label + close X). RATIONALE: the close X is
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / used by Safari / Finder / Mail for list-row close buttons.
    @ViewBuilder
    private func tabButton(for tab: EditorTab) -> some View {
        let isActive = tab.id == selectedTabId
        let isDropTarget = tab.id == dropTargetTabId && draggingTabId != nil

        TabHoverShell { isHovered in
            // RATIONALE: the title is
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // vertical rhythm is preserved).
            HStack(spacing: DesignTokens.spacingCaption) {
                // Leading 18 PT spacer (= matches the trailing
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // layout space without rendering any pixel.
                Color.clear
                    .frame(width: DesignTokens.tabCloseFrameSize,
                           height: DesignTokens.tabCloseFrameSize)

                Text(EditorTab.displayTitle(tab))
                    .font(isActive ? .body.weight(.medium) : .body)
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isHovered {
                    // RATIONALE 2026-10-13: the X is only rendered
                    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // smaller than the tab title's body font).
                    Button(action: { onClose(tab.id) }) {
                        SFIcon(
                            "xmark",
                            style: .inlineSmall,
                            color: IconColor.secondary,
                            pointSizeOverride: DesignTokens.tabCloseIconPointSize
                        )
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // RATIONALE 2026-10-13: the `hoverWash()`
                    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // hover state).
                    .hoverWash()
                    .help(String(localized: "workspace.editor.close_tab_tooltip"))
                } else {
                    // RATIONALE: the X-slot is a transparent
                    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // layout reflow on hover).
                    Color.clear
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingModerate)
        .frame(height: DesignTokens.paneTabHotArea)
        .background {
            // Active tab background (= Safari's accent-tinted
            // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // background).
            if isActive {
                UnevenRoundedRectangle(
                    topLeadingRadius: DesignTokens.surfaceCornerRadiusSmallButton,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: DesignTokens.surfaceCornerRadiusSmallButton
                )
                .fill(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle))
            }
        }
        .overlay(alignment: .bottom) {
            // Active-state underline (= matchedGeometryEffect for the
            // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // underline now has zero inset on both sides).
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: DesignTokens.tabUnderlineHeight)
                    .matchedGeometryEffect(id: "editorTabUnderline", in: tabBarNamespace, properties: .frame)
                    .clipShape(Capsule())
                    .padding(.horizontal, 0)
            }
        }
        .background {
            // Drop-target highlight (= the user is hovering a tab
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // land.
            if isDropTarget {
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                    .strokeBorder(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle), lineWidth: DesignTokens.surfaceShadowRadiusButton)
            }
        }
        .contentShape(Rectangle())
        // Tab selection = left-click anywhere on the title row
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // child control).
        .onTapGesture { onSelect(tab.id) }
        // Drag source (= the entire tab row is draggable; = the
        // user grabs the title or any empty space inside).
        .onDrag {
            draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        // Drop target (= any tab can be a drop target during a drag
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // before the drop target in step 2 of handleDrop).
        .onDrop(of: [.text], delegate: TabDropDelegate(
            tabId: tab.id,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId,
            displayOrder: $displayOrder,
            onReorder: onReorder
        ))
    }

    // / Sync `displayOrder` with the caller's `tabs` array when the array's id
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / it.
    private func syncDisplayOrderIfNeeded() {
        let incomingIds = tabs.map(\.id)

        // 1. Add new ids (= caller added a tab externally; = append
        // in the position they specified).
        if incomingIds != displayOrder {
            // Filter out stale ids (= displayOrder might contain ids
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // position, not just append).
            var newOrder: [UUID] = []
            for id in incomingIds {
                if let existing = displayOrder.first(where: { $0 == id }) {
                    newOrder.append(existing)
                } else {
                    // New id (= not in previous displayOrder) = add
                    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // caller's `openTabs` ordering exactly.
                    newOrder.append(id)
                }
            }
            // If the caller removed tabs (= ids in displayOrder but
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // above loop already does this (= only iterates incoming).
            displayOrder = newOrder
        }

        lastSeenTabIds = incomingIds
    }
}

// / Drag-and-drop delegate for tab reorder. SwiftUI's `.onDrop(of:delegate:)`
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / binding setters).
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

// / Per-tab hover shell. RATIONALE 2026-10-13: the wenshu tab close-X is the
// … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / = the X is rendered iff the cursor is inside the tab's bounds.
private struct TabHoverShell<Content: View>: View {
    @State private var isHovered: Bool = false
    private let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
