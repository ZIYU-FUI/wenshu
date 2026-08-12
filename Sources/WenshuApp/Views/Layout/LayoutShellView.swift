// LayoutShellView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → v0.05.0 B+ 拆主控 (t_1831ad61)
//
// 5-zone shell — macOS window root. Geometry: AGENTS.md §8.1 (5 区)。
//
// v0.05.0 B+ 拆主控 (DECISION-5ZONE-Bplus-Heavy §4.2 #4):
//   - LayoutShellTypes.swift    — PanelID / PanelVisibilityState / PanelStatesEnvelope / LayoutMetrics / VM extension
//   - LayoutShellToolbar.swift  — 7 toolbar 按钮 (FCP 范式)
//   - TopLeftHeaderBar.swift    — 5 tab ICON 跨全宽 header
//   - LayoutShellRoutes.swift   — AppRoute → destination View 映射
//   - LayoutShellView.swift (本文件) — NavigationStack 顶层 wrapper + 5-zone
//     geometry body (upperBand / lowerBand / panel slot) + 折叠态保留。

import SwiftUI

// V0-fix-11-1a retry-2: ⌘N / ⌘O 通知名扩展 (FileCommands menu 修真路径)。
extension Notification.Name {
    static let wenshuShowCreateProject = Notification.Name("wenshu.showCreateProject")
    static let wenshuOpenProjectURL = Notification.Name("wenshu.openProjectURL")
}

struct LayoutShellView: View {
    @State private var vm = LayoutShellViewModel.shared
    @State private var navPath: [AppRoute] = []
    @State private var projects: [ProjectSnapshot] = []
    @State private var activeTab: ProjectManagementTab = .projects
    @State private var selectedProjectID: UUID?
    @State private var selectedChapterID: String?
    @State private var showCreateProject: Bool = false

    var body: some View {
        NavigationStack(path: $navPath) {
            geometryBody
                .frame(minWidth: 900, minHeight: 600)
                .navigationTitle("")
                .navigationDestination(for: AppRoute.self) { route in
                    layoutShellDestination(for: route, selectedChapterID: $selectedChapterID)
                }
                .sheet(isPresented: $showCreateProject) {
                    ProjectCreateView(
                        onCreate: { newProject in
                            projects.append(newProject)
                            showCreateProject = false
                        },
                        onCancel: { showCreateProject = false }
                    )
                }
                .task { await vm.load() }
                .animation(.easeInOut(duration: 0.2), value: vm.snapshot.collapsed)
                .onChange(of: navPath) { _, newPath in
                    syncSelectedProjectID(from: newPath)
                }
                .toolbar { LayoutShellToolbar(vm: vm) }
                .onReceive(NotificationCenter.default.publisher(for: .wenshuShowCreateProject)) { _ in
                    showCreateProject = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .wenshuOpenProjectURL)) { _ in
                    // FileCommands 修真 NSOpenPanel — placeholder
                }
        }
    }

    // MARK: - 5-zone geometry body

    private var geometryBody: some View {
        GeometryReader { geo in
            let lowerHeight = LayoutMetrics.lowerBandHeight(
                totalHeight: geo.size.height,
                ratios: vm.snapshot.ratios,
                visibility: vm.visibility
            )
            let topHeaderHeight: CGFloat = 28
            let upperHeight = max(0, geo.size.height - lowerHeight - topHeaderHeight)
            VStack(spacing: 0) {
                if upperBandVisible || lowerBandVisible {
                    TopLeftHeaderBar(activeTab: $activeTab)
                }
                if upperBandVisible {
                    upperBand(in: geo.size.width).frame(height: upperHeight)
                }
                if upperBandVisible && lowerBandVisible {
                    NativeSplitter(orientation: .vertical) { delta in
                        vm.adjustBottomHeight(delta: delta, totalHeight: geo.size.height)
                    }
                }
                if lowerBandVisible {
                    lowerBand(in: geo.size.width).frame(height: lowerHeight)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.visibility)
        }
    }

    private var upperBandVisible: Bool {
        vm.isVisible(.topLeft) || vm.isVisible(.topCenter) || vm.isVisible(.topRight)
    }
    private var lowerBandVisible: Bool {
        vm.isVisible(.bottomLeft) || vm.isVisible(.bottomRight)
    }

    // MARK: - Upper row: 3 columns

    private func upperBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.upperWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.topLeft, width: split.0)
            if vm.isVisible(.topLeft) && vm.isVisible(.topCenter) {
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(splitterIndex: 0, delta: delta, totalWidth: totalWidth)
                }
            }
            panel(.topCenter, width: split.1)
            if vm.isVisible(.topCenter) && vm.isVisible(.topRight) {
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustUpperColumn(splitterIndex: 1, delta: delta, totalWidth: totalWidth)
                }
            }
            panel(.topRight, width: split.2)
        }
    }

    // MARK: - Lower row: 2 areas

    private func lowerBand(in totalWidth: CGFloat) -> some View {
        let split = LayoutMetrics.lowerWidths(
            totalWidth: totalWidth,
            ratios: vm.snapshot.ratios,
            collapsed: vm.snapshot.collapsed,
            visibility: vm.visibility
        )
        return HStack(spacing: 0) {
            panel(.bottomLeft, width: split.0)
            if vm.isVisible(.bottomLeft) && vm.isVisible(.bottomRight) {
                NativeSplitter(orientation: .horizontal) { delta in
                    vm.adjustLowerColumn(delta: delta, totalWidth: totalWidth)
                }
            }
            panel(.bottomRight, width: split.1)
        }
    }

    // MARK: - One panel slot

    @ViewBuilder
    private func panel(_ id: PanelID, width: CGFloat) -> some View {
        if !vm.isVisible(id) {
            EmptyView()
        } else if isCollapsed(id) {
            Group {
                if id == .bottomLeft || id == .bottomRight {
                    CollapsedHeader(panelID: id)
                } else {
                    CollapsedGutter(panelID: id)
                }
            }
            .frame(width: width)
        } else {
            let context = ZoneContext(
                panelID: id,
                selectedProjectID: $selectedProjectID,
                selectedChapterID: $selectedChapterID,
                navPath: $navPath,
                projects: $projects,
                activeTab: $activeTab
            )
            ZoneContainer(panelID: id, context: context).frame(width: width)
        }
    }

    private func isCollapsed(_ id: PanelID) -> Bool {
        switch id {
        case .topLeft: return vm.snapshot.collapsed.topLeft
        case .topCenter: return vm.snapshot.collapsed.topCenter
        case .topRight: return vm.snapshot.collapsed.topRight
        case .bottomLeft: return vm.snapshot.collapsed.bottomLeft
        case .bottomRight: return vm.snapshot.collapsed.bottomRight
        }
    }

    // MARK: - navPath sync (LT-N1-merge: 提取最近 .detail 同步到 selectedProjectID)

    private func syncSelectedProjectID(from path: [AppRoute]) {
        var lastDetail: UUID?
        for route in path {
            if case .detail(let id) = route { lastDetail = id }
        }
        if let id = lastDetail { selectedProjectID = id }
    }
}
