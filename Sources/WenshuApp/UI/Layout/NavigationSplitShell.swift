//
//  NavigationSplitShell.swift · Wenshu · M1-shell (2026-09-08)
//
//  Apple-native 3-column shell for the macOS 27 NavigationSplitView
//  migration (= the worktree = `.worktrees/m1-navigation-split-shell/`;
//  spec = `.scratch/2026-09-08-m1-shell/spec.md`).
//
//  Layout structure (= Apple HIG canonical 3-column per
//  developer.apple.com/documentation/swiftui/navigationsplitview):
//
//    Outer: VSplitView (Apple 2-column vertical split)
//    ├── NavigationSplitView #1 (upper band)
//    │   ├── sidebar:    目录树 + 卡片网格 (HSplit 内部 2 sub-panes)
//    │   ├── content:    编辑器
//    │   └── detail:     工具
//    └── NavigationSplitView #2 (lower band)
//        ├── sidebar:    空 (boss 9/8 placeholder)
//        ├── content:    聊天
//        └── detail:     动态
//
//  Two nested NavigationSplitView (each = 3 columns = Apple
//  first-class) instead of one NSSplitView with 4 columns (= NOT
//  Apple first-class; = the current bug pattern from ZONE-VIS-FIX-001..005).
//
//  M1 = build the shell SKELETON only (= placeholders, NO zone content).
//  M2-M5 = migrate existing zone content into the new panes
//  (= subsequent tickets; see spec §6).
//
//  Activation: LayoutTreeState.useThreeColumnSplit (= optional Bool
//  = default `nil`/off = 老 PaneSplitHost 路径 = ZERO regression).
//

import SwiftUI

// MARK: - Top-level shell

/// Apple-native 3-column shell (= outer VSplitView + two
/// NavigationSplitView). Activated by
/// `LayoutTreeState.useThreeColumnSplit`. Default `nil` (= 老
/// `PaneSplitHost` 路径完全保留 per M1 spec §2.3 = zero
/// regression risk).
///
/// Apple HIG rationale (= boss 9/8 'Apple framework 默认是 2-3 栏'
/// = the previous 4-column `NSSplitView` upper band was NOT
/// first-class supported = the ZONE-VIS-FIX bug series = time to
/// migrate to Apple's canonical API):
/// - `NavigationSplitView` per developer.apple.com/documentation/
///   swiftui/navigationsplitview = "A view that presents views in
///   two or three columns"
/// - `VSplitView` / `HSplitView` per developer.apple.com/documentation/
///   appkit/nssplitview = Apple's canonical 2-column splits
/// (= vertical and horizontal respectively)
struct NavigationSplitShell: View {
    /// Bindable app state (= owns the `useThreeColumnSplit` flag +
    /// any per-pane selection state; = same lifetime as the
    /// WorkspaceView's owner; = passed by reference via @Bindable
    /// in the body).
    var appState: AppState

    /// BookStore (= read-only access from this shell; = passed
    /// through to the placeholder views (= M2-M5 will replace
    /// placeholders with real zone views that actually consume the
    /// bookStore)).
    var bookStore: BookStore

    var body: some View {
        // Outer: VSplitView (= Apple 2-column vertical split per
        // developer.apple.com/documentation/appkit/nssplitview).
        // Apple HIG = upper/lower bands are vertical siblings.
        // Each band hosts its own NavigationSplitView (= 3 columns
        // = Apple first-class).
        //
        // Note: NavigationSplitView requires macOS 13+. Per wenshu
        // Package.swift minimum = macOS 27 (= much later than
        // 13); = no #available check needed.
        VSplitView {
            // Upper band: 3-column NavigationSplitView
            UpperSplitView(appState: appState, bookStore: bookStore)
            // Lower band: 3-column NavigationSplitView
            LowerSplitView(appState: appState, bookStore: bookStore)
        }
    }
}

// MARK: - Upper band (= 3-column NavigationSplitView)

/// Upper band shell (= NavigationSplitView with 3 columns).
/// Apple HIG:
/// - sidebar: 目录树 + 卡片网格 (HSplit 内部 2 sub-panes)
/// - content: 编辑器
/// - detail:  工具
///
/// M1 = placeholders only. M2 = migrate 目录树 (current sidebar
/// zone) to the sidebar column. M3 = migrate editor (current
/// editor zone) to the content column. M4 = migrate tools
/// (current tools zone) to the detail column (= popover?).
struct UpperSplitView: View {
    var appState: AppState
    var bookStore: BookStore

    var body: some View {
        // NavigationSplitView 2-column initializer (= sidebar +
        // detail) per Apple HIG; = the upper band needs 3
        // columns (= sidebar + content + detail) per boss 9/8 spec.
        //
        // The actual API chosen: NavigationSplitView's 3-column
        // initializer per developer.apple.com/documentation/swiftui/
        // navigationsplitview. Apple HIG = sidebar drives content
        // selection (= NavigationSplitView's @State selection
        // binding = automatic SwiftUI state).
        NavigationSplitView {
            // Apple HIG sidebar (= leftmost column; = the source
            // of truth for navigation in this band).
            //
            // M1 placeholder content = DirectoryTreePlaceholder +
            // CardGridPlaceholder inside an HSplit (= Apple 2-column
            // horizontal split). Boss 9/8 spec: '目录+卡片合并成一栏,
            // 但内部还是要分成两个区, 只不过两区写在一栏中'.
            UpperSplitSidebar(bookStore: bookStore)
        } content: {
            // Apple HIG content (= middle column; = context list
            // showing the items from the sidebar selection).
            //
            // M1 placeholder = EditorPlaceholder (= current
            // editor zone will move here in M3).
            ShellPlaceholder(
                name: "编辑器 (upper content)",
                icon: "square.and.pencil",
                hint: "M3 = editor zone migrates here"
            )
        } detail: {
            // Apple HIG detail (= rightmost column; = the
            // selected item's detail / inspector).
            //
            // M1 placeholder = ToolsPlaceholder (= current tools
            // zone will move here in M4).
            ShellPlaceholder(
                name: "工具 (upper detail)",
                icon: "wrench.and.screwdriver",
                hint: "M4 = tools zone migrates here"
            )
        }
        .navigationSplitViewStyle(.balanced)  // Apple HIG balanced
    }
}

/// Upper band's sidebar (= 目录树 + 卡片网格 = two sub-panes
/// inside one NavigationSplitView sidebar column).
///
/// Apple HIG implementation = HSplitView (= Apple 2-column
/// horizontal split per developer.apple.com/documentation/appkit/
/// nssplitview). The sidebar (= outer NavigationSplitView's
/// leftmost column) is internally divided into:
/// - left sub-pane: 目录树 (= current sidebar zone content from
///   NewLibraryOutlineView)
/// - right sub-pane: 卡片网格 (= current preview pane cards)
///
/// Boss 9/8 spec: '目录+卡片合并成一栏, 但内部还是要分成两个区'.
/// HSplitView is the canonical Apple API for two sub-areas
/// inside one column (= matches Mail's folder/message-list split
/// inside the sidebar column on iPad).
struct UpperSplitSidebar: View {
    var bookStore: BookStore

    var body: some View {
        // HSplitView (= Apple 2-column horizontal split). Per
        // developer.apple.com/documentation/appkit/nssplitview:
        // "By default, a split view arranges its child views
        // vertically from top to bottom. To specify a horizontal
        // (side-by-side) arrangement, implement the `isVertical`
        // property of the `splitView` object to return doc://...
        // Swift/true."
        //
        // SwiftUI doesn't expose HSplitView directly; = HSplitView
        // is an AppKit view (= wrapped via NSViewControllerRepresentable
        // if needed). For M1 placeholder simplicity, use SwiftUI
        // HStack (= native SwiftUI 2-column horizontal layout =
        // Apple-canonical via SwiftUI). M2 will replace with
        // HSplitView (= AppKit) if user needs drag-resizable
        // sub-panes.
        //
        // Per Apple HIG for sidebar sub-panes (= Xcode's
        // navigator + inspector stacked vertically; = Mail's
        // mailbox + folder list stacked vertically; = the standard
        // pattern is HORIZONTAL = the 2 sub-panes are side by side
        // inside the sidebar column).
        HStack(spacing: 0) {
            // Left sub-pane: 目录树 (= current sidebar zone)
            ShellPlaceholder(
                name: "目录树 (sidebar left)",
                icon: "folder",
                hint: "M2 = directory tree migrates here"
            )
            // Right sub-pane: 卡片网格 (= current preview pane)
            ShellPlaceholder(
                name: "卡片 (sidebar right)",
                icon: "rectangle.stack",
                hint: "M2 = card grid migrates here"
            )
        }
    }
}

// MARK: - Lower band (= 3-column NavigationSplitView)

/// Lower band shell (= NavigationSplitView with 3 columns).
/// Apple HIG:
/// - sidebar: 空 (boss 9/8 '在聊天加一个区, 先加出来, 先不用管放什么')
/// - content: 聊天 (current chat zone)
/// - detail:  动态 (current dynamic zone)
///
/// M1 = placeholders only. M3 = migrate chat to the content
/// column. M4 = migrate dynamic to the detail column. Boss to
/// decide what goes in the sidebar (= M5 ticket).
struct LowerSplitView: View {
    var appState: AppState
    var bookStore: BookStore

    var body: some View {
        NavigationSplitView {
            // Apple HIG sidebar (= leftmost). Boss 9/8 placeholder
            // (= '先加出来, 先不用管放什么' = the empty column
            // shows Apple recognizes the 3-column structure; = the
            // empty sidebar is a valid NavigationSplitView
            // configuration per Apple HIG = many production apps
            // have empty sidebars for navigation discovery).
            ShellPlaceholder(
                name: "下栏 sidebar (空)",
                icon: "rectangle.dashed",
                hint: "boss 9/8 '先加出来, 先不用管放什么'"
            )
        } content: {
            // Apple HIG content (= middle column; = chat). M1
            // placeholder; = M3 = chat zone migrates here.
            ShellPlaceholder(
                name: "聊天 (lower content)",
                icon: "bubble.left.and.bubble.right",
                hint: "M3 = chat zone migrates here"
            )
        } detail: {
            // Apple HIG detail (= rightmost; = dynamic zone). M1
            // placeholder; = M4 = dynamic zone migrates here.
            ShellPlaceholder(
                name: "动态 (lower detail)",
                icon: "chart.bar.doc.horizontal",
                hint: "M4 = dynamic zone migrates here"
            )
        }
        .navigationSplitViewStyle(.balanced)  // Apple HIG balanced
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
        // Boss 9/7 'use apple api unless apple api cannot implement the requirement' (= prefer Apple HIG primitives over custom styling).
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
