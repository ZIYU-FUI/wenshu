// ShellSidebarColumn.swift · Wenshu · v1.38 ticket 001
//
// Extracted from NavigationSplitShell.swift (= v0.40 boss OOB).
//
// Per boss OOB 2026-09-16 '按优先级推' + '拆了一半' concern.
// v1.34 extracted ShellPlaceholder (= 22 NLOC). v1.38 continues
// the NavigationSplitShell split (= repowise top #2 hotspot, 1567 NLOC).
// ShellSidebarColumn (= 29 NLOC) is the SAFE first sibling extract
// because:
//   1. No dependencies beyond AppState (= already in scope)
//   2. Single-line body (= NewLibraryOutlineView())
//   3. Public consumer (= NavigationSplitShell instantiates it)
//   4. No other structs in NavigationSplitShell reference it
//      in a complex way (= leaf component)
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// ShellSidebarColumn to its own file. The 9-line body + the
// boss OOB rationale comments (= preserved verbatim) move with
// the struct. 0 behavior change.
//
// Out of scope (= explicit, future tickets):
// - ShellMiddleColumn (= 446 NLOC; = repowise directive: extract next)
// - ShellContentColumn (= 102 NLOC)
// - ShellDetailColumn (= ~590 NLOC)

import SwiftUI

// MARK: - Sidebar column (= 2 vertical sub-areas)

/// Apple HIG sidebar column (= 1 vertical sub-area: directory tree).
/// Per boss 2026-09-10 second OOB 'NAV default 3 columns + each
/// column's sub-areas = visual 5 columns' = the card grid migrates
/// out of the sidebar bottom into the middle column bottom
/// (= ticket 001 of 2026-09-10-six-zone-ui-rewrite). The sidebar
/// is left as a single-area column (= no VSplitView) so the
/// directory tree owns the whole column.
///
/// Boss 2026-09-10 'Apple default' = no custom chrome wrappers;
/// Plan A pass-through ZonePerRegionChrome stub stays as-is
/// (per boss 9/8 OOB).
struct ShellSidebarColumn: View {
    let appState: AppState

    var body: some View {
        // Sidebar = 1 zone (directory tree). The previous 9/9
        // v0.49 sidebar card-zone pattern is reverted per the
        // 8/30 boss red-line drawing (= cards in the middle
        // column, not the sidebar).
        //
        // v0.79 boss 2026-09-10 OOB 'tree view — no search box needed, remove it':
        // the sidebar's `.searchable` field (= the macOS 13+
        // Apple HIG sidebar search widget = the search field at
        // the top of the sidebar column = ticket 004 of the
        // 2026-09-10-six-zone-ui-rewrite batch) is removed.
        // All sidebar rows render unconditionally (= no
        // case-insensitive substring match on title; = the
        // directory tree is its own document = the user sees
        // the whole tree and navigates by clicking rows =
        // standard macOS Finder behavior when the search field is
        // hidden). The previous commit's `sidebarSearchText`
        // @State + the `.searchable(text:placement:prompt:)`
        // modifier (= Apple HIG Inventory 2026-09-06 §
        // 'add HIG APIs that are currently absent') are both
        // dropped; NewLibraryOutlineView never read this
        // binding directly (= its filter reads SidebarState, not
        // sidebarSearchText; = the binding is fully removable).
        NewLibraryOutlineView()
    }
}
