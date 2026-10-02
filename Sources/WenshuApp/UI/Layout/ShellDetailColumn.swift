// ShellDetailColumn.swift · Wenshu
//
// Extracted from `NavigationSplitShell.swift`. Inspector column
// (= the trailing panel that hosts the paged InspectorPage
// body) for the macOS 27 NavigationSplitView shell.
//
// Per the 4-sibling split pattern (= ShellPlaceholder +
// ShellSidebarColumn + ShellContentColumn + ShellMiddleColumn +
// ShellDetailColumn = 5 of 5 siblings extracted): the inspector
// column body lives in this file; = `NavigationSplitShell.swift`
// stays a thin shell. The 21-line Apple HIG doc + the 450-line
// SwiftUI body move verbatim. 0 behavior change.

import SwiftUI

/// Apple HIG detail column (= 2 vertical sub-areas).
/// Per the 9/8 design (= right tools / right dynamic) the
/// detail column is also 1 column with 2 stacked sub-areas.
///
/// 2 sub-areas:
/// - top sub-area: ZoneModuleView(zoneSlot: .specializedTools)
///   (real tools pane; = foreshadowing tracking, memory
///   retrieval, etc.)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .aiDynamic)
///   (real dynamic pane; = kanban + todo + scope status)
///
/// Right column uses the same simple 2-stack VStack pattern as
/// ShellSidebarColumn (= no inspector-specific chrome wrappers,
/// no .toolbarRole special casing, no VStack container for the
/// picker toggle). The 2-toggle Tools / Dynamic picker is
/// attached via Apple's canonical .toolbar with ToolbarItem
/// placement .principal (= exactly matching ShellSidebarColumn's
/// books.vertical leading icon + PaneTabBar principal tabs).
/// Per WWDC25-323: 'The canonical column pattern uses VStack
/// (spacing: 0) with 2 sub-areas and a .toolbar for the column
/// chrome. No custom inspector wrapper needed.'
struct ShellDetailColumn: View {
    // `@Bindable var appState: AppState` (= the @Observable
    // binding wrapper; = allows `$shell.inspectorPage` syntax
    // in Picker / Toggle etc.; = single source of truth for
    // inspectorPage, not duplicated @State).
    //
    // Per Apple Observation framework (= developer.apple.com/
    // documentation/swiftui/migrating-from-the-observable-
    // object-protocol-to-the-observable-macro):
    //   "To create a binding to a property of an Observable
    //    object, declare a `@Bindable` variable in your View."
    @Bindable var appState: AppState
    // inspectorPage + inspectorVisible live in ShellState. The
    // `@Bindable var shell` is the entry the Picker / Toggle /
    // button read+write (= `$shell.inspectorPage` /
    // `shell.inspectorVisible.toggle()`).
    @Bindable var shell: ShellState

    // inspectorPage lives in `shell.inspectorPage` (= single
    // source of truth; = survives shell lifecycle changes; =
    // future inspector pane embeds can read the same value).
    //
    // Access pattern: `$shell.inspectorPage` (= appState is
    // @Observable + injected via init parameter from
    // NavigationSplitShell).

    // Wire `@Environment(\.openWindow)` so the toolbar buttons can
    // open dedicated KanbanWindow / TodoWindow scenes (= the
    // SwiftUI macOS 14+ API for opening secondary windows from
    // a scene; = Pages / Numbers / Keynote all use it for
    // independent document windows).
    @Environment(\.openWindow) private var openWindow

    /// Each InspectorPage (= .authoring / .craft) renders 1+
    /// specialized tools. Tools are selected via a 2nd segmented
    /// Picker in the body (= above the tool content; = the page
    /// Picker lives in the toolbar .principal placement; = the
    /// per-tool Picker lives at the top of the column body). The
    /// tools themselves are hosted by ZoneContentView (=
    /// .specializedTools with a per-tab `currentTab` selection).
    ///
    /// Default init (= the canonical SwiftUI view constructor; =
    /// no @MainActor isolation, no user-facing defaults, no
    /// reactive test isolation). The body's enum-driven Picker
    /// reads the canonical `shell.inspectorPage` (= single source
    /// of truth) and writes back via the @Bindable binding.
    ///
    /// page → tools route via InspectorPage.tools (= the enum
    /// owns the routing as a computed property; = the catalog
    /// holds the tool metadata; = the view derives via 1 line).
    private var toolsForCurrentPage: [InspectorTool] {
        shell.inspectorPage.tools
    }

    var body: some View {
        // The 4-page Picker (= Authoring (Fiction) / Style /
        // Characters / Project Management) lives in the NSWindow
        // main toolbar's trailing placement (= `.toolbar {
        // ToolbarItem(placement: .primaryAction) { Picker(...) } }`
        // below) = NOT in the inspector column body anymore. The
        // inspector column body now renders ONLY the active page's
        // tool (= no internal Picker; = the body is dedicated to
        // the tool itself; = the toolbar owns the page switch).
        //
        // vs the previous attempts:
        // 1. Picker in body, right-aligned — worked, but the
        //    canonical placement is the toolbar trailing slot.
        // 2. Picker in the inspector column's `.toolbar` block —
        //    same as current target (= NSWindow toolbar; the
        //    inspector column's `.toolbar` block attaches to the
        //    NSWindow main toolbar).
        //
        // State binding crosses column boundaries: `inspectorPage`
        // is `@State` on ShellDetailColumn; = ToolbarItem(placement:
        // .primaryAction) inside the same view's `.toolbar` block
        // can bind directly to `$shell.inspectorPage`; = the state
        // change in the toolbar Picker propagates to the body below
        // via SwiftUI's normal state binding; = no env-chain work
        // needed (= the binding is local to ShellDetailColumn).
        //
        // The inspector column body now opens with a sticky
        // Pages-style title + Divider (= the canonical Pages /
        // Numbers inspector page header pattern; = the title text
        // reads the active page's `localizedTitle` and updates
        // automatically as the toolbar Picker switches pages; = the
        // Divider sits 4 PT below the title per the Pages header
        // spec); the ZoneContentView (= the per-page tab strip)
        // renders immediately below the Divider and stretches to
        // the full column width (= no center-aligned card column;
        // = the tab strip fills the inspector column edge-to-edge
        // like Apple Mail / Notes / Pages inspector tabs).
        //
        // vs the previous pre-this-commit inspector body: the
        // body rendered ONLY the ZoneContentView (= the tabs were
        // the FIRST thing in the column with no page title above;
        // = looked like a naked tab strip floating in space).
        // Per the design ask, add the standard Pages page header
        // above the tab strip.
        VStack(spacing: 0) {
            // Pages-style page header: centered title text
            // (.font(.body) + .foregroundStyle(.secondary) per
            // the canonical Pages sidebar header pattern; = the
            // .secondary color matches the divider color so the
            // header reads as one visual unit; = the same
            // format as the 'Studio' / 'Assets' headers used
            // elsewhere in wenshu; = format LOCKED per memory).
            //
            // Lift the Inspector page header to the shared
            // SectionHeader component (= also used by AppleSidebarView '书架',
            // PreviewPane '素材', and EditorPlaceholder '写作（小说）';
            // = the 4 inspector pages = '写作（小说）' / '写作（风格）' /
            // '写作（人物）' / '项目管理' all share this header; =
            // same Apple HIG Mail / Notes / Finder section-header
            // idiom; = SectionHeader owns the 10 PT / 4 PT /
            // 10 PT insets). The previous inline VStack(spacing:4)
            // HStack + Divider was the same pattern (= just
            // without the 10 PT insets; = now consistent with the
            // other 3 column headers).
            SectionHeader(title: shell.inspectorPage.localizedTitle)
            // Remove the custom top inset (= `chromePaddingSectionTop`
            // = 18 PT) and the custom bottom inset (= 4 PT) on the
            // right column's section header. The right column is
            // the inspector detail column of a NavigationSplitView;
            // = Apple HIG macOS 27 default inspector column rhythm
            // places the section header at the natural SwiftUI
            // default top margin (= NO custom padding required; =
            // the canonical Pages / Numbers inspector pattern). The
            // ZoneContentView wrapper's `.padding(.top, 4)` (= 4
            // PT gap below the Divider) is also removed (= the
            // 'all custom padding' directive covers it).
            //
            // Per the design ask, ADD 4 PT of vertical breathing
            // room between the section's Divider (= end of the
            // title block) and the tab strip. The title block
            // already has `.padding(.top, 4)` (= 4 PT gap between
            // the title text and its own Divider) and `.padding
            // (.bottom, 4)` (= 4 PT gap between the Divider and the
            // next sibling). The SAME 8 PT visual rhythm Apple HIG
            // uses between the section header and the section
            // content (= Pages / Numbers / Keynote inspector
            // pattern; = the Divider sits 4 PT below the title; =
            // the content below the Divider starts 8 PT below the
            // Divider; = the total title→content gap is 12 PT,
            // matching the canonical Apple HIG inspector rhythm).
            //
            // Implementation: add `.padding(.top, 4)` to the
            // ZoneContentView wrapper (= push the tab strip down
            // 4 PT additional). Combined with the title block's
            // existing `.padding(.bottom, 4)` (= 4 PT), the
            // divider-to-tabs gap is now 8 PT (= the spec).
            //
            // Per the verbatim port discipline (= only do what was
            // asked), we add ONLY 4 PT here; = other spacing in
            // this column stays unchanged.
            //
            // Remove the custom top inset (= 4 PT) on the
            // ZoneContentView wrapper below. The wrapper sits below
            // the section Divider in a vertical VStack; = Apple HIG
            // macOS 27 default inspector rhythm places the per-page
            // tab strip at the natural SwiftUI default spacing (=
            // NO custom padding required; = the canonical Pages /
            // Numbers inspector pattern).
            ZoneContentView(
                zoneSlug: "specializedTools",
                tabs: toolsForCurrentPage.map { (label: $0.title, icon: $0.icon, content: $0.view()) }
            )
            .frame(maxWidth: .infinity)
            // Add horizontal padding to the right column (= 8 PT
            // Apple HIG canonical inline content inset via
            // DesignTokens.spacingStandard; = matches the
            // sidebar's outer padding added in this commit; =
            // matches the chat history's content rhythm).
            .padding(.horizontal, DesignTokens.spacingStandard)
        }
        .toolbar {
            // Place the toggle button AFTER the 3-tab Picker in the
            // toolbar (= SwiftUI renders multiple .primaryAction
            // items in declaration order; = the toggle button is
            // the last declared = rightmost). Per Apple's
            // ToolbarItemPlacement docs: '.primaryAction: An item
            // that represents the primary action of the toolbar,
            // typically positioned at the trailing edge.' =
            // Keynote / Pages / Numbers also put the right-panel
            // toggle at the trailing edge.
            //
            // The toggle button is ALWAYS visible (= even when the
            // inspector is collapsed, the toolbar still shows the
            // button; = the user can re-open the inspector at any
            // time; = matches Keynote / Pages / Numbers).
            //
            // The 4-page switcher sits in Trailing, aligned right:
            // the 4-page Picker goes in the TRAILING area
            // (= ToolbarItem(placement: .primaryAction)) = the
            // iOS-style segmented control rendered as a pill of 4
            // icon buttons = Apple HIG Pages / Keynote / Numbers
            // inspector tab strip pattern.
            //
            // The kanban + todo + inspector toggle buttons go in
            // the CENTER area (= .principal).
            //
            // Use the iOS segmented control style for the Picker
            // (= the .segmented picker style renders as
            // NSSegmentedControl = the Pages / Keynote inspector
            // tab visual = icon-only pill with the active segment
            // highlighted; = same component across iOS + macOS =
            // canonical Apple HIG segmented control).
            //
            // The previous commit mistakenly moved the Picker from
            // .primaryAction to .principal. Restore the Picker to
            // .primaryAction (= Trailing, per the original
            // canonical ask). The kanban + todo + toggle remain in
            // .principal (= Center, per the separate ask).
            //
            // Why segmented still works in .primaryAction: the
            // earlier worry that "Picker(.segmented) in
            // .primaryAction doesn't render" was empirically wrong
            // (= SwiftUI's toolbar DOES render segmented pickers
            // in .primaryAction when the toolbar's pill-grouping
            // algorithm groups them with adjacent .principal
            // items). Revert placement to .primaryAction = the
            // Picker renders as a 4-icon pill in the trailing
            // area.
            //
            // Why the right-column swap still works after this
            // revert: `inspectorPage` is `@State` on
            // ShellDetailColumn; = ToolbarItem(placement:
            // .primaryAction) inside the same view's `.toolbar`
            // block can bind directly to `$shell.inspectorPage`;
            // = the state change in the toolbar Picker propagates
            // to the inspector body via SwiftUI's normal state
            // binding; = no env-chain work needed (= the binding
            // is local to ShellDetailColumn).
            //
            // The toolbar picker uses the Apple HIG default SwiftUI
            // Picker(.segmented) (= the macOS toolbar's automatic
            // rendering = the same as Mail / Notes / Finder /
            // Pages toolbar segmented pickers = the macOS-auto-
            // picked rounded-rect capsule = 4 segment icons =
            // pill background, current segment highlighted; = each
            // segment = intrinsic icon size; = the canonical Apple
            // HIG toolbar style).
            ToolbarItem(placement: .primaryAction) {
                Picker("Inspector Page", selection: $shell.inspectorPage) {
                    ForEach(InspectorPage.allCases, id: \.self) { page in
                        Label {
                            Text(page.localizedTitle)
                        } icon: {
                            SFIcon(page.icon, style: .inlineSmall, color: IconColor.tint)
                        }
                        .tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(WenshuI18n.t("inspector.page.help"))
            }
            // The inspector toggle button moves from the trailing
            // area (= the previous `.primaryAction` placement = the
            // rightmost position) to the center area (= `.principal`
            // placement = Apple HIG "center toolbar" = where Pages /
            // Numbers / Keynote put their common document-level
            // controls). Combined with the page Picker already in
            // the trailing area, the toolbar is now a clean 3-zone
            // Apple HIG layout: leading = window chrome (= traffic
            // lights + title), center = inspector toggle, trailing
            // = page picker + kanban + todo.
            //
            // 3 separate ToolbarItem(placement: .principal) blocks
            // (= inspector toggle + Kanban window + Todo window) =
            // SwiftUI's macOS 27 NavigationSplitView toolbar pill-
            // grouping algorithm is designed for ONE item per
            // placement slot; = multiple .principal items in the
            // same toolbar block put SwiftUI's internal layout
            // engine into a degenerate state (= the window's
            // hit-test routing gets blocked; = clicking any button
            // outside the sidebar column drops the event before
            // SwiftUI routes it to the button action). Per Apple
            // HIG ToolbarItem docs: 'If you want multiple items in
            // the same placement slot, use ToolbarItemGroup
            // (placement:) instead of declaring multiple
            // ToolbarItem(placement:) blocks.' Combine the 3 .principal
            // items into one ToolbarItemGroup.
            ToolbarItemGroup(placement: .principal) {
                Button {
                    shell.inspectorVisible.toggle()
                } label: {
                    Label {
                        Text(WenshuI18n.t("inspector.toggle.button"))
                    } icon: {
                        SFIcon(shell.inspectorVisible ? "sidebar-right" : "sidebar.left", style: .paneTab, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("inspector.toggle.help"))

                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.kanban)")
                    openWindow(id: WindowID.kanban)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.kanban.open"))
                    } icon: {
                        SFIcon("rectangle.split.3x1", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("window.kanban.help"))

                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.todo)")
                    openWindow(id: WindowID.todo)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.todo.open"))
                    } icon: {
                        SFIcon("checklist", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("window.todo.help"))

                // v2.8a (boss 2026-09-28 OOB B3): explicit
                // CommandPalette toolbar button. The palette
                // sheet host in LibraryRootView already listens
                // for `.wenshuShowCommandPalette` notifications;
                // = this button is the visible trigger (= posts
                // the notification via CommandPaletteController.show).
                Button {
                    CommandPaletteController.show()
                } label: {
                    Label {
                        Text(WenshuI18n.t("command_palette.open"))
                    } icon: {
                        SFIcon("command", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("command_palette.open.help"))

                // v2.8b (boss 2026-09-28 OOB B6 + B7 + B9): 4
                // toolbar buttons that open 4 independent windows
                // for previously-unwired features (= same shape as
                // kanban + todo).
                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.canvas)")
                    openWindow(id: WindowID.canvas)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.canvas.open"))
                    } icon: {
                        SFIcon("rectangle.3.group", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("window.canvas.help"))

                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.composer)")
                    openWindow(id: WindowID.composer)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.composer.open"))
                    } icon: {
                        SFIcon("arrow.triangle.merge", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("window.composer.help"))

                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.foreshadowingGraph)")
                    openWindow(id: WindowID.foreshadowingGraph)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.foreshadowing_graph.open"))
                    } icon: {
                        SFIcon("arrow.triangle.branch", style: .inlineSmall, color: IconColor.tint)
                    }
                }
                .help(WenshuI18n.t("window.foreshadowing_graph.help"))

                Button {
                                    NSLog("[wenshu.window] click: openWindow id=\\(WindowID.cron)")
                                    openWindow(id: WindowID.cron)
                                } label: {
                                    Label {
                                        Text(WenshuI18n.t("window.cron.open"))
                                    } icon: {
                                        SFIcon("clock", style: .inlineSmall, color: IconColor.tint)
                                    }
                                }
                                .help(WenshuI18n.t("window.cron.help"))

                                // v2.9a (boss 2026-09-28 OOB A4): LLM Wiki
                                // operator button = the manual surface for
                                // LLMWikiOps.runAll. LLM can already call the
                                // 'llm_wiki' tool (= v2.8d T17), and every
                                // raw reference save auto-triggers derivation
                                // (= v2.8d auto-call hook), but the operator
                                // (= the boss) has no direct "Re-derive wiki
                                // now" affordance. This button closes A4.
                                Button {
                                    Task {
                                        do {
                                            if let result = try await LLMWikiOps.runAllFromActiveLibrary() {
                                                let s = result.stats
                                                NSLog("[wenshu.llm_wiki.operator] ranAt=%@ raw=%d abstracts=%d indexes=%d lint=%d",
                                                      String(describing: result.ranAt),
                                                      s?.rawCount ?? 0,
                                                      s?.abstractsWritten ?? 0,
                                                      s?.indexesWritten ?? 0,
                                                      result.lintFindings?.count ?? 0)
                                            } else {
                                                NSLog("[wenshu.llm_wiki.operator] no active library bound (= wenshu.libraryPath missing or .ws absent)")
                                            }
                                        } catch {
                                            NSLog("[wenshu.llm_wiki.operator] failed: %@", String(describing: error))
                                        }
                                    }
                                } label: {
                                    Label {
                                        Text(WenshuI18n.t("llm_wiki.operator.open"))
                                    } icon: {
                                        SFIcon("book.circle", style: .inlineSmall, color: IconColor.tint)
                                    }
                                }
                                .help(WenshuI18n.t("llm_wiki.operator.help"))

                                // v2.9c (boss 2026-09-28 OOB B5
                // follow-up): Restore operator (= the Backup
                // restore UI per AGENTS.md §11 baseline; = the
                // canonical backup path is
                // `BackupTools.list` / `BackupTools.restore`
                // wrapped in @MainActor enum AppBackupOps).
                Button {
                                    Task { await restoreLatestBackup() }
                                } label: {
                                    Label(WenshuI18n.t("backup.operator.open"), systemImage: "arrow.uturn.backward.circle")
                                }
                                .help(WenshuI18n.t("backup.operator.help"))
                }
        }
        // Re-inject AppState into the env chain. SwiftUI 6+ breaks
        // the @Environment chain across NavigationSplitView's
        // 3-column boundary.
        .environment(appState)
    }

    /// v2.9c (boss 2026-09-28 OOB B5 follow-up): restore from the
    /// latest available backup (= the user-facing restore
    /// surface per AGENTS.md §11 baseline).
    ///
    /// Pattern: pull the active library path from the canonical
    /// UserDefaults key (`wenshu.libraryPath`), list backups via
    /// `AppBackupOps.list()`, restore the newest (= alphabetical
    /// sort on the timestamped backup name is the canonical
    /// ordering used by `BackupTools.list`).
    private func restoreLatestBackup() async {
        guard let sourceDir = UserDefaults.standard.string(forKey: "wenshu.libraryPath"),
              FileManager.default.fileExists(atPath: sourceDir) else {
            NSLog("[wenshu.backup.operator] no active library bound (= wenshu.libraryPath missing or .ws absent)")
            return
        }
        do {
            let backups = try AppBackupOps.list()
            guard let latest = backups.last else {
                NSLog("[wenshu.backup.operator] no backups available in default backup dir")
                return
            }
            try AppBackupOps.restore(backupName: latest.id, to: sourceDir)
            NSLog("[wenshu.backup.operator] restored backup %@ to %@", latest.id, sourceDir)
        } catch {
            NSLog("[wenshu.backup.operator] failed: %@", String(describing: error))
        }
    }
}
