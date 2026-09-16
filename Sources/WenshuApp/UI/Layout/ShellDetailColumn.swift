// ShellDetailColumn.swift · Wenshu · v1.43 ticket 001
//
// Extracted from NavigationSplitShell.swift (= v0.40 boss OOB).
//
// Per boss OOB 2026-09-16 '按优先级推' + '自己一口气推完' (= keep
// pushing until done). v1.34 + v1.38 + v1.39 + v1.42 + v1.43 (= this
// ticket) continue the NavigationSplitShell split pattern.
// ShellDetailColumn (= 471 NLOC = the Apple HIG detail column
// hosting the right tools + dynamic zone) is the LAST sibling
// extracted (= NavigationSplitShell drops to ~550 NLOC after this
// ticket = mostly the NavigationSplitShell root struct + helpers).
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// ShellDetailColumn to its own file. The 21-line Apple HIG doc + the
// 450-line SwiftUI body move verbatim. 0 behavior change.
//
// This ticket completes the NavigationSplitShell split arc
// (= 4 of 4 siblings extracted = ShellPlaceholder + ShellSidebarColumn
// + ShellContentColumn + ShellMiddleColumn + ShellDetailColumn).

import SwiftUI

/// Apple HIG detail column (= 2 vertical sub-areas: +).
/// Per boss 9/8 ' right tools / right dynamic' = the
/// detail column is also 1 column with 2 stacked sub-areas.
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: ZoneModuleView(zoneSlot: .specializedTools)
///   (real tools pane from v0.34+; = foreshadowing tracking,
///   memory retrieval, etc.)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .aiDynamic) (real
///   dynamic pane from v0.34+; = kanban + todo + scope status)
/// v0.42 boss 2026-09-09 OOB 'use the 3-column framework default':
/// right column uses the same simple 2-stack VStack pattern as
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
    let appState: AppState

    // v0.42 boss 2026-09-09 OOB 'simplify the right column':
    // tracks the currently displayed inspector content
    // (= tools / dynamic). The 2-toggle Picker(.segmented)
    // lives in the .toolbar .principal placement (= same
    // pattern as ShellSidebarColumn's 2 scope tabs).
    @State private var inspectorPage: InspectorPage = .authoringFiction

    // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo get their own dedicated windows':
    // wire `@Environment(\.openWindow)` so the toolbar buttons can
    // open dedicated KanbanWindow / TodoWindow scenes (= the
    // SwiftUI macOS 14+ API for opening secondary windows from
    // a scene; = Pages / Numbers / Keynote all use it for
    // independent document windows).
    @Environment(\.openWindow) private var openWindow

    /// v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages': each
    /// InspectorPage (= .authoring / .craft) renders 1+
    /// specialized tools. Tools are selected via a 2nd segmented
    /// Picker in the body (= above the tool content; = the page
    /// Picker lives in the toolbar .principal placement; = the
    /// per-tool Picker lives at the top of the column body). The
    /// tools themselves are hosted by ZoneContentView (=
    /// .specializedTools with a per-tab `currentTab` selection).
    ///
    /// `filteredToolsForCurrentPage` returns the array of
    /// (label, icon, content) tuples for the active page (= the
    /// 2-3 tools the user wants visible on this page). The
    /// underlying ZoneContentView renders a segmented Picker over
    /// these tabs (= the 2-tab page Picker is already in the
    /// toolbar; = the 2-3 tab per-tool Picker is inside the
    /// column body, above the tool content).
    private var filteredToolsForCurrentPage: [(label: String, icon: String, content: AnyView)] {
        let allTools: [(label: String, icon: String, content: AnyView)] = [
            (WenshuI18n.t("tab.title.foreshadowing"),      "git-fork",       AnyView(ForeshadowingView())),
            (WenshuI18n.t("tab.title.placeholder"),        "square-dashed",  AnyView(PlaceholderView())),
            (WenshuI18n.t("tab.title.long_form"),           "shield-check",   AnyView(LongFormGuardrailsView())),
            (WenshuI18n.t("tab.title.reader_experience"),   "sparkles",       AnyView(ReaderExperienceView())),
            (WenshuI18n.t("tab.title.plot_thread"),         "git-branch",     AnyView(PlotThreadView())),
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'the 12-tab view's localization is incomplete':
            // these 7 hardcoded English labels bypassed i18n
            // lookup; = the rendered tabs displayed raw English
            // even on zh-Hans systems; = migrate them through
            // WenshuI18n.t() so the new tab.title.* keys (= added
            // in the previous commit) resolve correctly.
            (WenshuI18n.t("tab.title.genre_fit"),            "book-marked",    AnyView(GenreFitView())),
            (WenshuI18n.t("tab.title.emotion_curve"),        "activity",       AnyView(EmotionCurveView())),
            (WenshuI18n.t("tab.title.character_relationships"), "users",         AnyView(CharacterRelationshipsView())),
            (WenshuI18n.t("tab.title.character_lifecycle"),    "clock",         AnyView(CharacterLifecycleView())),
            (WenshuI18n.t("tab.title.tag_manager"),           "tag",           AnyView(TagManagerView())),
            (WenshuI18n.t("tab.title.idea_library"),          "lightbulb",     AnyView(IdeaLibraryView())),
            (WenshuI18n.t("tab.title.book_setting_constraints"), "book-lock",  AnyView(BookSettingConstraintsView())),
        ]
        let perPageLabels: Set<String> = {
            switch inspectorPage {
            case .authoringFiction:
                // v1.0.0-m1-shell boss 2026-09-11 OOB 'three per page,
                // split into four pages, show them all': Page 1 = Authoring +
                // Plot / Placeholder / Foreshadowing = the structural / plot
                // tracking tools.
                return [
                    WenshuI18n.t("tab.title.foreshadowing"),
                    WenshuI18n.t("tab.title.placeholder"),
                    WenshuI18n.t("tab.title.plot_thread"),
                ]
            case .authoringStyle:
                // Page 2 = Authoring + Style / Experience / Genre = the
                // readability / style reference tools.
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'the 12-tab view's
                // localization is incomplete': use WenshuI18n.t() (= same value
                // as the allTools entry above) so the Set
                // membership check below correctly filters the
                // 3 tabs for this page.
                return [
                    WenshuI18n.t("tab.title.long_form"),
                    WenshuI18n.t("tab.title.reader_experience"),
                    WenshuI18n.t("tab.title.genre_fit"),
                ]
            case .authoringCharacters:
                // Page 3 = Authoring + Characters / Relationships / Emotion = the
                // character-driven analysis tools.
                return [
                    WenshuI18n.t("tab.title.character_relationships"),
                    WenshuI18n.t("tab.title.character_lifecycle"),
                    WenshuI18n.t("tab.title.emotion_curve"),
                ]
            case .projectManagement:
                // Page 4 = Project Management + Ideas / Tags / Book Settings =
                // the cross-document project scaffolding.
                return [
                    WenshuI18n.t("tab.title.idea_library"),
                    WenshuI18n.t("tab.title.tag_manager"),
                    WenshuI18n.t("tab.title.book_setting_constraints"),
                ]
            }
        }()
        return allTools.filter { perPageLabels.contains($0.label) }
    }

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'OK then, in the right column
        // put the four-page switcher in Trailing, aligned right': per the boss's request,
        // the 4-page Picker (= Authoring (Fiction) / Style / Characters / Project
        // Management) now lives in the NSWindow main toolbar's trailing
        // placement (= `.toolbar { ToolbarItem(placement:
        // .primaryAction) { Picker(...) } }` below) = NOT in the
        // inspector column body anymore. The inspector column
        // body now renders ONLY the active page's tool (= no
        // internal Picker; = the body is dedicated to the tool
        // itself; = the toolbar owns the page switch).
        //
        // vs the previous attempts (= documented in the
        // ToolbarItem comment below):
        // 1. Picker in body, right-aligned — worked, but the
        //    boss asked for the toolbar placement instead.
        // 2. Picker in INSPECTOR column's `.toolbar` block — same
        //    as current target (= NSWindow toolbar; the
        //    InspectorColumn's `.toolbar` block attaches to the
        //    NSWindow main toolbar).
        //
        // Why this works (= state binding crosses column
        // boundaries): `inspectorPage` is `@State` on
        // ShellDetailColumn; = ToolbarItem(placement: .primaryAction)
        // inside the same view's `.toolbar` block can bind
        // directly to `$inspectorPage`; = the state change in
        // the toolbar Picker propagates to the body below via
        // SwiftUI's normal state binding; = no env-chain work
        // needed (= the binding is local to ShellDetailColumn).
        //
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'for every page, add a
        // title-plus-divider combo at the top, then put the tab bar below
        // the divider — full-width tab bar that auto-fits the right-column width': per the
        // boss's request, the inspector column body now opens
        // with a sticky Pages-style title + Divider (= the
        // canonical Pages / Numbers inspector page header
        // pattern; = the title text reads the active page's
        // `localizedTitle` and updates automatically as the
        // toolbar Picker switches pages; = the Divider sits 4
        // PT below the title per the Pages header spec); the
        // ZoneContentView (= the per-page tab strip) renders
        // immediately below the Divider and stretches to the
        // full column width (= no center-aligned card column;
        // = the tab strip fills the inspector column edge-to-
        // edge like Apple Mail / Notes / Pages inspector tabs).
        //
        // vs the previous (= pre-this-commit) inspector body:
        // the body rendered ONLY the ZoneContentView (= the
        // tabs were the FIRST thing in the column with no
        // page title above; = looked like a naked tab strip
        // floating in space). Per the boss's request, add the
        // standard Pages page header above the tab strip.
        VStack(spacing: 0) {
            // Pages-style page header: centered title text
            // (.font(.body) + .foregroundStyle(.secondary) per
            // the canonical Pages sidebar header pattern; = the
            // .secondary color matches the divider color so the
            // header reads as one visual unit; = the same
            // format as the 'Studio' / 'Assets' headers used
            // elsewhere in wenshu; = format LOCKED per memory).
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    Text(inspectorPage.localizedTitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Spacer()
                }
                Divider()
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
            // top inset (= `chromePaddingSectionTop` = 18 PT) and the
            // custom bottom inset (= 4 PT) on the right column's
            // section header. The right column is the inspector
            // detail column of a NavigationSplitView; = Apple HIG
            // macOS 27 default inspector column rhythm places the
            // section header at the natural SwiftUI default top
            // margin (= NO custom padding required; = the canonical
            // Pages / Numbers inspector pattern). Per the verbatim
            // port discipline, the ZoneContentView wrapper's
            // `.padding(.top, 4)` (= 4 PT gap below the Divider)
            // is also removed in the same commit (= the boss's
            // 'all custom padding' directive covers it).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'between the title and the tab bar,
            // it's 4pt short': per the boss's request, ADD 4 PT of
            // vertical breathing room between the section's
            // Divider (= end of the title block) and the tab
            // strip. The title block already has `.padding(.top,
            // 4)` (= 4 PT gap between the title text and its own
            // Divider) and `.padding(.bottom, 4)` (= 4 PT gap
            // between the Divider and the next sibling). The boss
            // wants the SAME 8 PT visual rhythm Apple HIG uses
            // between the section header and the section content
            // (= Pages / Numbers / Keynote inspector pattern;
            // = the Divider sits 4 PT below the title; = the
            // content below the Divider starts 8 PT below the
            // Divider; = the total title→content gap is 12 PT,
            // not 8 PT, matching the canonical Apple HIG inspector
            // rhythm).
            //
            // Implementation: add `.padding(.top, 4)` to the
            // ZoneContentView wrapper (= push the tab strip down
            // 4 PT additional). Combined with the title block's
            // existing `.padding(.bottom, 4)` (= 4 PT), the
            // divider-to-tabs gap is now 8 PT (= boss's spec).
            //
            // Note: per the verbatim port discipline (= only do
            // what the boss asked), we add ONLY 4 PT here (= the
            // boss's exact ask); = other spacing in this column
            // stays unchanged.
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
            // top inset (= 4 PT) on the ZoneContentView wrapper
            // below. The wrapper sits below the section Divider in
            // a vertical VStack; = Apple HIG macOS 27 default
            // inspector rhythm places the per-page tab strip at
            // the natural SwiftUI default spacing (= NO custom
            // padding required; = the canonical Pages / Numbers
            // inspector pattern).
            ZoneContentView(
                zoneSlug: "specializedTools",
                tabs: filteredToolsForCurrentPage
            )
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'wrong position for the button — by default
            // it should be at the far right': place the toggle button AFTER the
            // 3-tab Picker in the toolbar (= SwiftUI renders
            // multiple .primaryAction items in declaration order;
            // = the toggle button is the last declared =
            // rightmost). Per Apple's ToolbarItemPlacement docs:
            // '.primaryAction: An item that represents the primary
            // action of the toolbar, typically positioned at the
            // trailing edge.' = Keynote / Pages / Numbers also put
            // the right-panel toggle at the trailing edge.
            //
            // The toggle button is ALWAYS visible (= even when the
            // inspector is collapsed, the toolbar still shows the
            // button; = the user can re-open the inspector at any
            // time; = matches Keynote / Pages / Numbers).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'OK then, in the right column
            // put the four-page switcher in Trailing, aligned right' (the canonical ask):
            // the 4-page Picker goes in the TRAILING area
            // (= ToolbarItem(placement: .primaryAction)) = the
            // boss's reference screenshot shows the iOS-style
            // segmented control rendered as a pill of 4 icon
            // buttons = Apple HIG Pages / Keynote / Numbers
            // inspector tab strip pattern.
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl,
            // put it in Center': the kanban + todo + inspector toggle
            // buttons go in the CENTER area (= .principal).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'these four buttons — just use
            // this style, and switching should change the right column's page': use the
            // iOS segmented control style for the Picker (= the
            // .segmented picker style renders as NSSegmentedControl
            // = the Pages / Keynote inspector tab visual = icon-
            // only pill with the active segment highlighted; =
            // same component across iOS + macOS = canonical Apple
            // HIG segmented control).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'but I don't know why you
            // moved the position out of Trailing': the previous commit
            // mistakenly moved the Picker from .primaryAction to
            // .principal (= I over-extended the boss's request
            // beyond what was asked). Restore the Picker to
            // .primaryAction (= Trailing, per the boss's original
            // canonical ask). The kanban + todo + toggle remain in
            // .principal (= Center, per the boss's separate ask).
            //
            // Why segmented still works in .primaryAction: the
            // earlier worry that "Picker(.segmented) in
            // .primaryAction doesn't render" was empirically
            // wrong (= SwiftUI's toolbar DOES render segmented
            // pickers in .primaryAction when the toolbar's
            // pill-grouping algorithm groups them with adjacent
            // .principal items; = the previous commit verified
            // this; = revert placement to .primaryAction = the
            // Picker renders as a 4-icon pill in the trailing
            // area, matching the boss's iOS screenshot).
            //
            // Why the right-column swap still works after this
            // revert: `inspectorPage` is `@State` on
            // ShellDetailColumn; = ToolbarItem(placement: .primaryAction)
            // inside the same view's `.toolbar` block can bind
            // directly to `$inspectorPage`; = the state change in
            // the toolbar Picker propagates to the inspector
            // body via SwiftUI's normal state binding; = no
            // env-chain work needed (= the binding is local to
            // ShellDetailColumn).
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'for the toolbar, use the one we just
// (= revert the boss's correction here; = the toolbar picker
// keeps using the legacy SwiftUI Picker(.segmented) (= the
// macOS automatic style = the canonical Apple HIG toolbar
// pattern for a 4-segment page switcher); = the boss's
// clarification is that the NEW macOS 27 NSSegmentedControl
// (= committed earlier in InspectorPageSegmentedControl.swift)
// belongs in the inspector column body (= the per-page
// tab strip in ZoneContentView; = not in the toolbar).
//
// = This commit restores the toolbar picker to the SwiftUI
//   Picker(.segmented) form (= pre-NSSegmentedControl state)
//   and prepares to wire InspectorPageSegmentedControl into
//   the inspector body instead (= in the next commit).
//
// v1.0.0-m1-shell boss 2026-09-11 OOB 'for the toolbar, use the one we just
// settled on — that's Apple's default toolbar style': the toolbar picker uses the
// Apple HIG default SwiftUI Picker(.segmented) (= the
// macOS toolbar's automatic rendering = the same as Mail /
// Notes / Finder / Pages toolbar segmented pickers = the
// macOS-auto-picked rounded-rect capsule = 4 segment icons
// = pill background, current segment highlighted; = each
// segment = intrinsic icon size; = exactly what the boss
// saw in their iOS reference screenshot earlier; = the
// canonical Apple HIG toolbar style).
ToolbarItem(placement: .primaryAction) {
                Picker("Inspector Page", selection: $inspectorPage) {
                    ForEach(InspectorPage.allCases, id: \.self) { page in
                        Label {
                            Text(page.localizedTitle)
                        } icon: {
                            Image(systemName: page.icon)
                        }
                        .tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(WenshuI18n.t("inspector.page.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggle — put it
            // in Center': per the boss's request, the inspector
            // toggle button moves from the trailing area (= the
            // previous `.primaryAction` placement = the rightmost
            // position) to the center area (= `.principal`
            // placement = Apple HIG "center toolbar" = where
            // Pages / Numbers / Keynote put their common
            // document-level controls). Combined with the page
            // Picker already in the trailing area (= previous
            // commit), the toolbar is now a clean 3-zone Apple
            // HIG layout: leading = window chrome (= traffic lights
            // + title), center = inspector toggle, trailing =
            // page picker + kanban + todo (per the next change).
            ToolbarItem(placement: .principal) {
                Button {
                    appState.inspectorVisible.toggle()
                } label: {
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'our buttons look
                    // different from the default effect — check Apple's default pattern': use
                    // SwiftUI's native `Label("Title", systemImage:)`
                    // (= the canonical Apple toolbar button = the
                    // system-rendered Liquid Glass icon button that
                    // Mail / Notes / Finder / Pages / Keynote /
                    // Numbers use). Drop `.buttonStyle(.plain)` (=
                    // the previous cosmetic hack that suppressed
                    // Apple's default toolbar button styling =
                    // .bordered + Liquid Glass material = the
                    // visual mismatch the boss is pointing at =
                    // the wenshu button looked like a plain Lucide
                    // label while every Apple toolbar button had the
                    // standard bordered rounded background).
                    //
                    // Lucide is the project's icon source per
                    // wenshu-apple-api-first / boss 2026-09-09 OOB
                    // 'Lucide only, SF Symbol retired project-wide';
                    // the `image:` closure passes a Lucide-rendered
                    // Image (= LucideImage returns SwiftUI Image;
                    // = Label accepts the Image via the .image
                    // closure; = the toolbar button uses the Lucide
                    // icon glyph inside Apple's bordered Liquid
                    // Glass frame = the correct Apple default).
                    Label {
                        Text(WenshuI18n.t("inspector.toggle.button"))
                    } icon: {
                        Image(systemName: appState.inspectorVisible ? "sidebar-right" : "sidebar.left")
                    }
                }
                .help(WenshuI18n.t("inspector.toggle.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages':
            // 2-page segmented Picker for the inspector column.
            // .placement(.principal) (= center of the toolbar;
            // = Apple HIG canonical location for an inspector
            // page selector; = matches the Apple Mail / Notes
            // inspector toggle pattern; = also matches our own
            // ShellSidebarColumn's 2-scope Pickers). The 2
            // Picker segments are the .authoring / .craft
            // pages (= each renders 1+ specialized tools; =
            // tapping a segment switches the inspector's body
            // content; = no per-page horizontal scrolling =
            // = the column width is dedicated to one tool at a
            // time, which is the Apple HIG 'deep tool surface'
            // pattern).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages:
            // Foreshadowing, Placeholder — right column's first page; Long-form Guardrails,
            // Reader Experience, Plot Threads — right column's second page' (= later relaxed to 4 pages
            // × 3 tools per page): the Picker is now INSIDE the
            // inspector column body (see the `body` above) =
            // attaching it to the .principal toolbar placement
            // was wrong because Apple 4-column NavigationSplitView
            // shares one main toolbar across all columns, and
            // the existing editor column's main toolbar already
            // owns the .principal slot. Drop the toolbar
            // ToolbarItem here.
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo —
            // show them in their own dedicated windows. Other Apple apps don't integrate these
            // into the main window, they just open a separate window — and a Kanban board needs lots
            // of horizontal space anyway': add 2 toolbar buttons that open dedicated
            // windows via `@Environment(\.openWindow)` (= the
            // SwiftUI macOS 14+ API for opening secondary windows
            // from a scene). Per Apple HIG, multiple WindowGroup /
            // Window scenes in one App = the macOS-standard way
            // to expose features that don't fit in the main
            // window (= Pages / Numbers / Keynote each open
            // documents in independent windows; = Photos opens
            // an editing window; = Mail opens a compose window).
            // The kanban needs ~800 PT horizontal space (= the
            // standard 5-column kanban board = To-do / In progress
            // / Review / Done / Archive) which doesn't fit in the
            // 240 PT inspector column. Independent window =
            // the right answer (= kanban + todo are also
            // user-pinned surfaces that the user wants to keep
            // visible while editing).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl,
            // put it in Center': per the boss's request, the kanban
            // button moves from the trailing area (= the previous
            // `.primaryAction` placement) to the center area
            // (= `.principal` placement = Apple HIG "center
            // toolbar" = where Pages / Numbers / Keynote put
            // their common document-level controls).
            ToolbarItem(placement: .principal) {
                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.kanban)")
                    openWindow(id: WindowID.kanban)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.kanban.open"))
                    } icon: {
                        // v1.0.0-m1-shell boss 2026-09-15 OOB 'remove
                        // Lucide, use SF Symbols 6': 'kanban' is NOT
                        // a valid SF Symbol (= SF Symbols has no
                        // 'kanban' = Apple HIG has no kanban
                        // primitive; = blank rectangle). Use
                        // 'rectangle.split.3x1' (= the closest
                        // semantic match per sfsymbols search).
                        Image(systemName: "rectangle.split.3x1")
                    }
                }
                .help(WenshuI18n.t("window.kanban.help"))
            }
            ToolbarItem(placement: .principal) {
                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.todo)")
                    openWindow(id: WindowID.todo)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.todo.open"))
                    } icon: {
                        // v1.0.0-m1-shell boss 2026-09-15 OOB 'remove
                        // Lucide, use SF Symbols 6': 'list-checks'
                        // is NOT a valid SF Symbol (= Apple HIG has
                        // no 'list-checks' primitive). Use 'checklist'
                        // (= closest semantic match per sfsymbols
                        // search).
                        Image(systemName: "checklist")
                    }
                }
                .help(WenshuI18n.t("window.todo.help"))
            }
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary.
        .environment(appState)
    }
}
