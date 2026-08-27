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
// HOW TO LAUNCH:
//
//   The App.swift wiring in commit 3 (= the next commit) adds a hidden
//   menu item 'Tools → 拖拽测试' (= Cmd+Shift+T) that opens this window
//   via SwiftUI's @Environment(\.openWindow). For now (= this commit),
//   the file is only compiled (= no menu wiring yet); the boss can
//   verify via `swift run` + manual Xcode preview, or wait for commit
//   3 to land the in-app launcher.

import SwiftUI
import SplitView

/// SplitterTestView — 6-zone test harness for SplitView drag behavior.
struct SplitterTestView: View {
    @State private var showSidebar: Bool = true
    @State private var showPreview: Bool = true
    @State private var showTools: Bool = true
    @State private var showDynamic: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Top control bar (= visibility toggles; mirrors the
            // LayoutShellView's wenshu.zoneVisible.* AppStorage keys).
            HStack(spacing: 12) {
                Toggle("Sidebar", isOn: $showSidebar)
                Toggle("Preview", isOn: $showPreview)
                Toggle("Tools", isOn: $showTools)
                Toggle("Dynamic", isOn: $showDynamic)
                Spacer()
                Text("拖动中间的线，看能不能拖")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Splitter layout — replicates wenshu's 6-zone LayoutShellView
            // shape with SplitView's HSplit / VSplit views.
            // Per SplitView v3.5 API: HSplit(left:right:), VSplit(top:bottom:).
            VSplit(top: {
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
                            }
                        )
                    }
                )
                .frame(minHeight: 300)
            }, bottom: {
                HSplit(
                    left: { testPane("聊天区", color: .pink)
                        .frame(minWidth: 300)
                    },
                    right: { if showDynamic {
                        testPane("动态区", color: .yellow)
                            .frame(minWidth: 200)
                    } }
                )
                .frame(minHeight: 200)
            })
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