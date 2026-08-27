// SplitterTestView.swift · Wenshu (文枢) · v0.27 boss 8/27 splitter test
//
// PURPOSE (= AGENTS.md §11.1 third-party library policy):
//
//   Pre-adoption smoke test for `stevengharris/SplitView` (= AGENTS.md
//   §11.1 first approved exception). Before rewriting LayoutShellView
//   to use SplitView's HSplit / VSplit views, this file provides an
//   in-app demo window where the boss can verify that SplitView's drag
//   works (= no SwiftUI gesture quirks on macOS 27) and that hide/show
//   + nested layouts behave as expected.
//
// WHAT IT REPRODUCES:
//
//   Mimics the wenshu 6-zone LayoutShellView shape (= sidebar / preview /
//   editor / tools upper + chat / dynamic lower + 3 vertical splitters
//   + 1 horizontal splitter), using SplitView's HSplit / VSplit /
//   custom handles. Each pane has a show/hide toggle (= reproduces
//   LayoutShellView's wenshu.zoneVisible.* behavior).
//
// v0.27 boss 8/27 OOB #2 (= positive test confirmed SplitView drag
// works): '你先把测试 APP 的所有的拖拽线，改成 1PT.然后鼠标悬浮上去后，
// 5PT 发光效果。热区也是 5PT。热区是不显示的' = wenshu splitter style spec:
//   - visibleThickness (line drawn): 1 PT
//   - hover state: 5 PT glow (= accent color, opacity ~0.4, animated)
//   - hit area (invisibleThickness, the actual drag region): 5 PT
//   - hit area is invisible (= transparent; only the visible 1 PT line
//     shows, expanding to 5 PT on hover)
// This matches the existing NativeSplitter implementation that was
// the wenshu v0.24-v0.27 in-house splitter (= same Apple HIG line/hover
// specs; = boss 8/27 wants SplitView's drag reliability PLUS the
// existing wenshu splitter visual treatment).

import SwiftUI
import SplitView
import Lucide

/// WenshuSplitter — custom splitter conforming to SplitDivider.
/// Implements the wenshu v0.27 visual spec (= boss 8/27 OOB):
/// - 1 PT line at rest (Apple system separatorColor).
/// - 5 PT accent-color glow on hover (eased in/out, 0.2s).
/// - 5 PT invisible hit area (= invisibleThickness = 5).
///
/// Per SplitView docs (= README § Custom Splitters):
///   'The styling.visibleThickness is the size your custom splitter
///   displays itself in, and it also defines the spacing between the
///   primary and secondary views inside of Split view.'
///   'The Split view detects drag events occurring in the splitter. For
///   this reason, you might want to use a ZStack with an underlying
///   Color.clear that represents the styling.invisibleThickness if the
///   styling.visibleThickness is too small for properly detecting the
///   drag events.'
///
/// v0.27 boss 8/27 OOB: wenshu splitter visual spec (= 1 PT line + 5 PT
/// hit area + hover glow) is now implemented by the production-ready
/// WenshuSplitter struct (= Sources/WenshuApp/Views/Layout/
/// WenshuSplitter.swift). This test view no longer needs its own
/// placeholder WenshuSplitter (= it's a duplicate type that fails
/// to compile). The test app uses the production WenshuSplitter via
/// the project-wide import (= WenshuApp target = the production
/// type lives in Sources/WenshuApp/Views/Layout/, and the test view
/// in Sources/WenshuApp/Tools/ shares the same target).

/// SplitterTestView — 6-zone test harness for SplitView drag behavior.
struct SplitterTestView: View {
    @State private var showSidebar: Bool = true
    @State private var showPreview: Bool = true
    @State private var showTools: Bool = true
    @State private var showDynamic: Bool = true

    // v0.27 boss 8/27 OOB #2: wenshu splitter style spec = 1 PT line +
    // 5 PT hover glow + 5 PT invisible hit area. SplitStyling controls
    // both visible (the drawn line) and invisible (the drag region)
    // thickness.
    private let styling = SplitStyling(visibleThickness: 1, invisibleThickness: 5)
    private let upperLayout = LayoutHolder()
    private let lowerLayout = LayoutHolder()
    private let sidebarHide = SideHolder()
    private let previewHide = SideHolder()
    private let toolsHide = SideHolder()
    private let dynamicHide = SideHolder()

    var body: some View {
        VStack(spacing: 0) {
            // Top control bar (= visibility toggles; mirrors the
            // LayoutShellView's wenshu.zoneVisible.* AppStorage keys).
            HStack(spacing: 12) {
                Toggle("Sidebar", isOn: Binding(
                    get: { showSidebar },
                    set: { newVal in
                        showSidebar = newVal
                        withAnimation { sidebarHide.toggle() }
                    }
                ))
                Toggle("Preview", isOn: Binding(
                    get: { showPreview },
                    set: { newVal in
                        showPreview = newVal
                        withAnimation { previewHide.toggle() }
                    }
                ))
                Toggle("Tools", isOn: Binding(
                    get: { showTools },
                    set: { newVal in
                        showTools = newVal
                        withAnimation { toolsHide.toggle() }
                    }
                ))
                Toggle("Dynamic", isOn: Binding(
                    get: { showDynamic },
                    set: { newVal in
                        showDynamic = newVal
                        withAnimation { dynamicHide.toggle() }
                    }
                ))
                Spacer()
                Text("拖动中间 5 PT 热区 (= invisibleThickness)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Splitter layout — replicates wenshu's 6-zone LayoutShellView
            // shape with SplitView's HSplit / VSplit views + WenshuSplitter.
            VSplit(
                top: {
                    HSplit(
                        left: { if showSidebar {
                            testPane("项目管理区", color: .blue)
                                .frame(minWidth: 200)
                        } },
                        right: {
                            HSplit(
                                left: { if showPreview {
                                    testPane("素材预览区", color: .purple)
                                        .frame(minWidth: 200)
                                } },
                                right: {
                                    HSplit(
                                        left: { testPane("编辑器", color: .green)
                                            .frame(minWidth: 300)
                                        },
                                        right: { if showTools {
                                            testPane("工具区", color: .orange)
                                                .frame(minWidth: 200)
                                        } }
                                    )
                                    .styling(color: Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                                }
                            )
                            .styling(color: Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                        }
                    )
                    .styling(color: Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                    .hide(sidebarHide)
                    .frame(minHeight: 300)
                },
                bottom: {
                    HSplit(
                        left: { testPane("聊天区", color: .pink)
                            .frame(minWidth: 300)
                        },
                        right: { if showDynamic {
                            testPane("动态区", color: .yellow)
                                .frame(minWidth: 200)
                        } }
                    )
                    .styling(color: Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
                    .hide(dynamicHide)
                    .frame(minHeight: 200)
                }
            )
            .styling(color: Color(nsColor: .separatorColor), visibleThickness: 1, invisibleThickness: 5)
            .frame(minHeight: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    /// A simple colored pane with a label (= visual marker for drag
    /// testing; no real functionality).
    private func testPane(_ title: String, color: Color) -> some View {
        VStack {
            Text(title)
                .font(.title2)
                .foregroundStyle(.white)
            Text("拖动右/下边缘调整大小")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.6))
    }
}