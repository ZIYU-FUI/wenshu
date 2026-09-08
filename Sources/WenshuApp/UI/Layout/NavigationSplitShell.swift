//
//  NavigationSplitShell.swift · Wenshu · M1-shell (2026-09-08)
//
//  Apple-native 3-column shell for the macOS 27 NavigationSplitView
//  migration (= the worktree = `.worktrees/m1-navigation-split-shell/`;
//  spec = `.scratch/2026-09-08-m1-shell/spec.md`).
//
//  Layout structure (per boss 9/8 red-line drawing = 1 continuous
//  vertical drag-resizable divider贯穿整个 window = NOT 2 separate
//  NavigationSplitView, but 1 outer NavigationSplitView with each
//  column containing 2 vertically-stacked sub-areas):
//
//    Outer: NavigationSplitView (3 columns, Apple HIG canonical)
//    ├── sidebar (1 column, 2 vertical sub-areas, no inner divider):
//    │   ├── top:    目录树 (M2 = directory tree migrates here)
//    │   └── bottom: 卡片   (M2 = card grid migrates here)
//    ├── content (1 column, 2 vertical sub-areas, no inner divider):
//    │   ├── top:    编辑器 (M3 = editor zone migrates here)
//    │   └── bottom: 聊天   (M3 = chat zone migrates here)
//    └── detail (1 column, 2 vertical sub-areas, no inner divider):
//        ├── top:    工具 (M4 = tools zone migrates here)
//        └── bottom: 动态 (M4 = dynamic zone migrates here)
//
//  Why 1 outer NavigationSplitView (not 2 + VSplitView): the boss's
//  red line is 1 continuous vertical line that runs the full
//  height of the window. That is only possible with 1 outer
//  NavigationSplitView whose 3 columns have vertical sub-areas
//  (VStack). Two stacked NavigationSplitView (upper + lower) would
//  produce 2 separate vertical dividers (= 4 dividers total = NOT
//  matching the boss's 2-dividers-only red-line).
//
//  M1 = build the shell SKELETON only (= placeholders, NO zone
//  content). M2-M5 = migrate existing zone content into the new
//  panes (= subsequent tickets; see spec §6).
//
//  Activation: LayoutTreeState.useThreeColumnSplit (= optional
//  Bool = default `nil`/off = 老 PaneSplitHost 路径 = ZERO
//  regression).
//

import SwiftUI

// MARK: - Top-level shell

/// Apple-native 3-column shell (= 1 outer `NavigationSplitView`
/// with 3 columns × 2 vertical sub-areas each). Activated by
/// `LayoutTreeState.useThreeColumnSplit`. Default `nil` (= 老
/// `PaneSplitHost` 路径完全保留 per M1 spec §2.3 = zero
/// regression risk).
///
/// Apple HIG rationale (= boss 9/8 '按我的红色放拖拽线' = the
/// 3 columns share 1 continuous vertical divider line that runs
/// the full window height; = 1 outer `NavigationSplitView` with
/// each column = 2 vertically-stacked sub-areas (= VStack)).
struct NavigationSplitShell: View {
    /// Bindable app state (= owns the `useThreeColumnSplit` flag +
    /// any per-pane selection state; = same lifetime as the
    /// WorkspaceView's owner; = passed by reference via @Bindable
    /// in the body).
    var appState: AppState

    var body: some View {
        // Outer: 1 NavigationSplitView (3 columns) per
        // developer.apple.com/documentation/swiftui/navigationsplitview.
        // The boss's red line drawing shows 2 continuous vertical
        // dividers (= 3 columns = sidebar | content | detail) that
        // run the full height of the window. This is only possible
        // with 1 outer NavigationSplitView; = each column is a
        // single SwiftUI view that internally stacks upper/lower
        // sub-areas (= VStack).
        //
        // NavigationSplitView requires macOS 13+. Per wenshu
        // Package.swift minimum = macOS 27 (= much later than
        // 13); = no #available check needed.
        NavigationSplitView {
            // Apple HIG sidebar (= leftmost column; = the source
            // of truth for navigation in this band). 2 vertical
            // sub-areas (= VStack; no inner divider; = Mail's
            // sidebar = inbox + sent + drafts side by side, =
            // Apple's standard "List with multiple sections"
            // pattern).
            ShellSidebarColumn()
        } content: {
            // Apple HIG content (= middle column; = context list
            // showing the items from the sidebar selection). 2
            // vertical sub-areas (= VStack).
            ShellContentColumn()
        } detail: {
            // Apple HIG detail (= rightmost column; = the
            // selected item's detail / inspector). 2 vertical
            // sub-areas (= VStack).
            ShellDetailColumn()
        }
        .navigationSplitViewStyle(.balanced)  // Apple HIG balanced
    }
}

// MARK: - Sidebar column (= 2 vertical sub-areas)

/// Apple HIG sidebar column (= 2 vertical sub-areas: 目录树 +
/// 卡片网格). Per boss 9/8 '目录+卡片合并成一栏, 但内部还是
/// 要分成两个区, 只不过两区写在一栏中' = the 2 sub-areas share
/// one column without a drag-resizable divider between them
/// (= Apple HIG's standard "List with multiple sections" pattern
/// = Mail's sidebar = inbox + sent + drafts stacked vertically
/// inside one column).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: NewLibraryOutlineView (real sidebar tree
///   from v0.34+; = the source of truth for the library
///   shelf/book/folder hierarchy)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .projectPreview)
///   (real card grid from v0.34+; = displays the documents
///   for the current sidebar selection)
struct ShellSidebarColumn: View {

    var body: some View {
        // VStack (vertical stack) of 2 sub-areas inside one
        // column. Apple HIG standard pattern: multiple sections
        // stacked inside one column, no drag-resizable divider
        // between sections (= the column's width is fixed; =
        // users resize the entire column, not the individual
        // sections inside it).
        VStack(spacing: 0) {
            // Top sub-area: real directory tree (= the
            // wenshu-app's existing NewLibraryOutlineView;
            // = manages the library outline + sidebar selection
            // state via @AppStorage shared with WorkspaceView).
            NewLibraryOutlineView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Divider (visual separator between the 2 sub-areas).
            // Apple HIG: a subtle hairline between sidebar sections
            // = `.divider` modifier (system default tint).
            Divider()
            // Bottom sub-area: real card grid (= the
            // wenshu-app's existing ZoneModuleView with the
            // .projectPreview slot; = PreviewPane's content
            // driven by the sidebar selection).
            ZoneModuleView(zoneSlot: .projectPreview)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Content column (= 2 vertical sub-areas)

/// Apple HIG content column (= 2 vertical sub-areas: 编辑器 +
/// 聊天). Per boss 9/8 '上半 sidebar / content / detail' +
/// '下半 sidebar / content / detail' but the columns are
/// CONTINUOUS (1 outer NavigationSplitView, NOT 2 stacked).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: EditorPlaceholder (real editor from v0.34+;
///   = routes to EditorEditContent internally with the markdown
///   engine + word count + auto-save)
/// - bottom sub-area: ChatView (real chat from v0.34+; = the
///   LLM conversation surface with attachment upload)
struct ShellContentColumn: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top sub-area: real editor (= the wenshu-app's
            // existing EditorPlaceholder; = the v0.34+
            // markdown editor that routes to EditorEditContent
            // internally, with the markdown engine + word
            // count + auto-save).
            EditorPlaceholder()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real chat (= the wenshu-app's
            // existing ChatView; = the LLM conversation
            // surface with attachment upload + message history).
            ChatView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Detail column (= 2 vertical sub-areas)

/// Apple HIG detail column (= 2 vertical sub-areas: 工具 + 动态).
/// Per boss 9/8 '上半 right tools / 下半 right dynamic' = the
/// detail column is also 1 column with 2 stacked sub-areas.
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: ZoneModuleView(zoneSlot: .specializedTools)
///   (real tools pane from v0.34+; = foreshadowing tracking,
///   memory retrieval, etc.)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .aiDynamic) (real
///   dynamic pane from v0.34+; = kanban + todo + scope status)
struct ShellDetailColumn: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top sub-area: real tools (= the wenshu-app's
            // existing ZoneModuleView with the .specializedTools
            // slot; = foreshadowing tracking, memory retrieval,
            // and other writer-craft tools).
            ZoneModuleView(zoneSlot: .specializedTools)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real dynamic zone (= the
            // wenshu-app's existing ZoneModuleView with the
            // .aiDynamic slot; = kanban + todo + scope status
            // surface).
            ZoneModuleView(zoneSlot: .aiDynamic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Placeholder view (= reusable for M1)

/// M1 placeholder (= Apple HIG standard pattern for empty panes
/// = Xcode's "No Editor" / Mail's "No Message Selected" =
/// informational view showing what WILL go there in a future
/// ticket).
///
/// Per boss 9/3 '父组件不动, 在聊天区关联父组件, 生成子组件,
/// 在子组件做聊天区底栏实现功能. 替换占位文字' (= placeholders
/// are first-class Apple HIG pattern; = the shell renders the
/// structure; = future tickets replace each placeholder with a
/// real zone view).
///
/// Apple HIG implementation notes:
/// - Uses Apple's `ContentUnavailableView` (= macOS 14+; = Apple
///   HIG canonical "no content" view = Xcode / Mail / Notes
///   pattern) — but we want a NAMED placeholder (= showing what
///   WILL be there) not a "no content" view.
/// - Falls back to a custom VStack (= macOS 13 compatible = below
///   the `ContentUnavailableView` floor; = wenshu's minimum
///   target = macOS 27 but uses AppKit-compatible primitives for
///   maximum portability).
struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        // VStack with icon + name + hint (= Apple HIG
        // informational pane layout = centered vertically +
        // horizontally with subtle background tint).
        //
        // Boss 9/7 'use apple api unless apple api cannot implement
        // the requirement' (= prefer Apple HIG primitives over
        // custom styling).
        VStack(spacing: DesignTokens.chromePaddingLeading) {
            // SF Symbol (= Apple HIG icon system) + macOS 27
            // Liquid Glass material = the icon takes on the
            // standard tint automatically.
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            // Name (= the placeholder's canonical label).
            Text(name)
                .font(.title2)
                .foregroundStyle(.secondary)
            // Hint (= future-ticket reference; = Apple's
            // standard "this is where X will go" pattern).
            Text(hint)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background tint (= Apple HIG .background hierarchy
        // = .background for content area per zone tier).
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
