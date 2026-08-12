// LayoutShellViewModel.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Owns the in-memory `LayoutSnapshot` for the 5-zone shell + bridges it to
// `WenshuStoreActor` for .ws persistence.
//
// Responsibilities:
// 1. On `.load()` (called from `.task` on first appear): read the saved
//    snapshot from disk and apply it (fall back to defaults if missing
//    or malformed).
// 2. On every user mutation (chevron click, splitter drag): update
//    `snapshot` immediately so SwiftUI re-renders, and debounce a write
//    to disk so the drag gesture doesn't slam CoreData on every pixel.
// 3. The reset button rewrites the canonical default to disk so the next
//    cold launch (装机 user 8/7 实机验) still restores to defaults.
//
// Threading: @MainActor — every published mutation originates here, and
// the View layer reads `snapshot` directly in `body`. Persistence is
// awaited on the actor; we don't block the main thread.

import Foundation
import SwiftUI

@MainActor
final class LayoutShellViewModel: ObservableObject {

    /// LT-01-fix3: the macOS menu bar (`App.swift` `.commands`) and the
    /// shell View both drive the same layout state, but they live in two
    /// disjoint SwiftUI scene graphs — a `@StateObject` inside
    /// `LayoutShellView` is not reachable from a `CommandMenu`. A
    /// MainActor-isolated shared instance is the smallest thing that
    /// makes both sides agree without threading the VM through
    /// `MainView` (which is outside this task's file boundary).
    static let shared = LayoutShellViewModel()

    // MARK: - Published state

    /// Single source of truth that the View layer reads. Always starts
    /// at `.default` so the first paint never reads from disk (cheap +
    /// deterministic; if the disk read returns the same default, no flash).
    @Published private(set) var snapshot: LayoutSnapshot = .default

    /// LT-01-fix3: per-panel show/hide, driven exclusively by the macOS
    /// menu bar's "View" menu (FCP 范式). Distinct from
    /// `snapshot.collapsed`: a *collapsed* panel keeps a gutter/header
    /// strip, a *hidden* panel gets no width at all and its neighbours
    /// absorb the space. Defaults to all-visible.
    @Published private(set) var visibility: PanelVisibilityState = PanelVisibilityState()

    /// `true` after the first `.load()` completes — drives whether the
    /// toolbar shows the "reset to defaults" affordance. We don't gate the
    /// View on this to keep the layout responsive during cold launch.
    @Published private(set) var isLoaded: Bool = false

    // MARK: - Init

    private let store: WenshuStoreActor
    private var saveTask: Task<Void, Never>?

    init(store: WenshuStoreActor = .shared) {
        self.store = store
    }

    // MARK: - Load (cold launch)

    /// Read the persisted snapshot from `.ws`. Caller invokes this from
    /// `.task` — runs once after the first render. Errors fall back to
    /// defaults so a corrupted row never bricks the shell.
    func load() async {
        do {
            if let raw = try await store.loadLayoutState() {
                let states = PanelStatesEnvelope.decode(raw.panelStatesJSON)
                snapshot = LayoutSnapshot(
                    collapsed: states.collapsed,
                    ratios: LayoutSnapshot.decodeRatios(raw.panelRatiosJSON)
                )
                visibility = states.visible
            }
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.load: \(error)\n".utf8
            ))
        }
        isLoaded = true
    }

    // MARK: - Panel collapse toggle
    //
    // LT-01-fix3 removed the chevron buttons that used to call this
    // (FCP 范式: collapse/expand is a menu-bar concern, not panel chrome).
    // The method + persisted flags stay so old .ws files keep round-
    // tripping and so LT-02/03/04 can re-expose collapse if 装机 user
    // asks for it.

    func toggle(_ panel: PanelID) {
        var snap = snapshot
        switch panel {
        case .topLeft:
            snap.collapsed.topLeft.toggle()
        case .topCenter:
            snap.collapsed.topCenter.toggle()
        case .topRight:
            snap.collapsed.topRight.toggle()
        case .bottomLeft:
            snap.collapsed.bottomLeft.toggle()
        case .bottomRight:
            snap.collapsed.bottomRight.toggle()
        }
        snapshot = snap
        scheduleSave()
    }

    // MARK: - Splitter drag handlers
    //
    // LT-01-fix4: every drag handler MUST reassign `snapshot` (not just
    // mutate `snapshot.ratios`) so `@Published` emits `objectWillChange`
    // and SwiftUI re-evaluates the shell body. Nested mutations on a
    // `@Published` value type silently no-op the UI — the drag still
    // updates the persisted state via scheduleSave(), but the live
    // window never repaints. 装机 user 8/7 实机验 hit this on the 下半屏
    // splitter: dragging the bar felt like a no-op.

    /// Splitter at `upperSplitterIndex` (0 or 1) in the upper row was
    /// dragged by `delta` pixels (positive = pulled right). We update
    /// ratios[index] and ratios[index+1] (the two panels left/right of
    /// the splitter) such that their sum is preserved and each stays
    /// within [5%, 95%].
    ///
    /// `totalWidth` is the upper row's full width in points (post-toolbar).
    /// Available width excludes the 2 splitter bars themselves.
    ///
    /// LT-01-fix13: 返回 `Bool` = "本次 delta 是否真改了 ratios"。
    /// 返回 `false` (= clamp 到边界) 时, NativeSplitterView 立即 reset
    /// `lastReported = 0` (= 干净 baseline, 修装机 user 实机拍"水平 splitter
    /// 拖到 90:10 后被锁住")。 `@discardableResult` 让旧调用点
    /// (`adjustXxx(delta:, ...)` 不接返回值的写法) 继续编译, 但**语义**
    /// 已变 — 闭包必须 `return vm.adjustXxx(...)` 把 Bool 传回
    /// NativeSplitterView 才能触发 reset。
    @discardableResult
    func adjustUpperColumn(splitterIndex: Int, delta: CGFloat, totalWidth: CGFloat) -> Bool {
        guard splitterIndex == 0 || splitterIndex == 1 else { return false }
        let left = splitterIndex
        let right = splitterIndex + 1
        let available = totalWidth - 2 * LayoutSnapshot.splitterPixels
        guard available > 0 else { return false }
        let deltaRatio = Double(delta / available)
        var snap = snapshot
        let sum = snap.ratios[left] + snap.ratios[right]
        guard sum > 0 else { return false }
        let proposedLeft = snap.ratios[left] + deltaRatio
        let clampedLeft = max(0.05, min(0.95, proposedLeft))
        let proposedRight = sum - clampedLeft
        let clampedRight = max(0.05, min(0.95, proposedRight))
        snap.ratios[left] = clampedLeft
        snap.ratios[right] = clampedRight
        // Applied = 两个 ratio 都等于 proposed (没被 clamp 截断)。
        // 任一被截断 = clamp boundary → false (= reset state in
        // NativeSplitterView)。
        let applied = abs(proposedLeft - clampedLeft) < 0.0001
            && abs(proposedRight - clampedRight) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    /// The horizontal splitter between upper and lower bands was dragged
    /// by `delta` pixels (positive = pulled down). Updates ratios[3]
    /// (lower band's fraction of total height).
    ///
    /// LT-01-fix6 BUG2 fix: 装机 user 8/7 实机验"中间的上下分割线位置
    /// 不对". 真根因 = **符号反了**. `ratios[3]` 是**下半**的高度占比,
    /// 而向下拖 (delta > 0) 意味着上半变大 / 下半变小, 所以必须
    /// **减去** deltaRatio. 之前写成 `+ deltaRatio`, 分割线朝着跟鼠标
    /// 相反的方向跑, 越拖偏得越远; 偏掉的比例还被 scheduleSave 落盘
    /// 到 .ws — 下次冷启动分割线就停在一个跟中点无关的位置
    /// (装机 user 截图里的 y≈540).
    ///
    /// 默认 50:50 由 `LayoutSnapshot.default.ratios[3] == 0.5` 保证.
    /// 这里保持 ratio-driven (而不是硬编码 0.5), 否则拖拽在标准 5 区
    /// 模式下会变成无效操作 — 跟"拖动实时变"的验收项直接冲突.
    ///
    /// LT-01-fix13: 返回 `Bool` = "applied" (= ratios 真变)。 clamp 到
    /// [0.10, 0.90] 边界时返回 `false` (= 装机 user 实机拍"水平 splitter
    /// 拖到 90:10 后被锁住" 的真根因修法: NativeSplitterView 收到 false
    /// reset lastReported = 0)。
    @discardableResult
    func adjustBottomHeight(delta: CGFloat, totalHeight: CGFloat) -> Bool {
        guard totalHeight > 0 else { return false }
        let deltaRatio = Double(delta / totalHeight)
        let proposed = snapshot.ratios[3] - deltaRatio
        let clamped = max(0.10, min(0.90, proposed))
        var snap = snapshot
        snap.ratios[3] = clamped
        let applied = abs(proposed - clamped) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    /// The single horizontal splitter in the lower band (between 下左 and
    /// 下右) was dragged by `delta` pixels (positive = pulled right).
    /// Updates ratios[4] (bottomLeft's fraction of lower-band width).
    ///
    /// LT-01-fix13: 返回 `Bool` (= applied)。 clamp 到 [0.05, 0.95]
    /// 边界时返回 `false`, NativeSplitterView reset lastReported = 0。
    @discardableResult
    func adjustLowerColumn(delta: CGFloat, totalWidth: CGFloat) -> Bool {
        let available = totalWidth - LayoutSnapshot.splitterPixels
        guard available > 0 else { return false }
        let deltaRatio = Double(delta / available)
        let proposed = snapshot.ratios[4] + deltaRatio
        let clamped = max(0.05, min(0.95, proposed))
        var snap = snapshot
        snap.ratios[4] = clamped
        let applied = abs(proposed - clamped) < 0.0001
        snapshot = snap
        scheduleSave()
        return applied
    }

    // MARK: - Menu title (LT-01-fix4)
    //
    // FCP 范式: View-menu toggles show their *next action* in the label.
    //   visible → "隐藏 X" (clicking will hide it)
    //   hidden  → "显示 X" (clicking will show it)
    // Centralised here so the menu View (which observes this VM) and any
    // future toolbar button pull the same string.

    /// Returns the dynamic menu-item title for a panel. Visible panels
    /// advertise the "hide" verb (because clicking will hide them); hidden
    /// panels advertise "show". Chinese copy per LT-01-fix4 拍板.
    func menuTitle(for panel: PanelID) -> String {
        let verb = isVisible(panel) ? "隐藏" : "显示"
        return "\(verb) \(panel.title)"
    }

    // MARK: - Menu title — collapse/expand (Q2 折叠态, t_c6f48f43)
    //
    // FCP 范式 (沿 menuTitle): 显示下一动作。 Visible + expanded → "折叠 X"
    // (clicking will collapse); visible + collapsed → "展开 X" (clicking
    // will expand). Hidden → disabled (panel 不在, 没 chrome 可折叠, 跟
    // DESIGN §1.3 触发器 A 范式一致). Chinese copy 沿 LT-01-fix4 拍板.

    /// Returns the dynamic menu-item title for a collapse/expand toggle.
    func menuCollapseTitle(for panel: PanelID) -> String {
        let verb = isCollapsed(panel) ? "展开" : "折叠"
        return "\(verb) \(panel.title)"
    }

    /// Q2 折叠态用的读取入口。 跟 panel() 内部 isCollapsed switch 镜像,
    /// 这里 public 给 App.swift menu (可见性 + 折叠态 都要在标题里反映).
    func isCollapsed(_ panel: PanelID) -> Bool {
        switch panel {
        case .topLeft: return snapshot.collapsed.topLeft
        case .topCenter: return snapshot.collapsed.topCenter
        case .topRight: return snapshot.collapsed.topRight
        case .bottomLeft: return snapshot.collapsed.bottomLeft
        case .bottomRight: return snapshot.collapsed.bottomRight
        }
    }

    // MARK: - Panel visibility (macOS "View" menu, LT-01-fix3)

    /// Show/hide one panel. Ratios are deliberately left untouched: the
    /// hidden panel's share is redistributed at render time by
    /// `LayoutMetrics`, so un-hiding restores the exact widths the user
    /// had dragged to. Persisted (debounced) to `.ws`.
    ///
    /// v0.04.0 FCP 3 toggle (沿 designer wenshu-fcp-fold-3buttons-2026-08-12
    /// 真值): isDismissible 全 true, `.topCenter` / `.bottomLeft` 也允许
    /// hide — FCP 范式 = 全 toggle, 区别于 v0.02.0 LT-01-fix5 装机 user
    /// 拍板的"核心创作区永驻"硬约束。
    func togglePanelVisibility(_ panel: PanelID) {
        guard panel.isDismissible else {
            // 不可隐藏 panel (本卡沿 designer 真值改 isDismissible 后
            // 已无 false case, 保留 guard 兜底未来 schema 调整)。
            // "View → 显示/隐藏 X" 菜单项变 disabled, 不调 handler。
            // 此 guard 兜底 direct-call 路径 (未来的快捷键、测试、自动化脚本)。
            return
        }
        var next = visibility
        switch panel {
        case .topLeft: next.topLeft.toggle()
        case .topCenter: next.topCenter.toggle()
        case .topRight: next.topRight.toggle()
        case .bottomLeft: next.bottomLeft.toggle()
        case .bottomRight: next.bottomRight.toggle()
        }
        visibility = next
        scheduleSave()
    }

    func isVisible(_ panel: PanelID) -> Bool {
        visibility.isVisible(panel)
    }

    /// FCP 按钮 2 范式: 整条下半栏 (聊天 + 状态) 一个 toggle 按钮,
    /// 同时翻 .bottomLeft + .bottomRight. FCP 范式 vs macOS View menu
    /// 的"分别 toggle 聊天/状态"是两套接口, 此方法提供给 toolbar 按钮
    /// 专用, View menu 仍走 `togglePanelVisibility`。
    func toggleBottomBand() {
        // ponytail: 沿 togglePanelVisibility 同一入口 — guard 已覆盖
        // isDismissible, .bottomLeft 改 true 后这里也自动 enable。
        togglePanelVisibility(.bottomLeft)
        togglePanelVisibility(.bottomRight)
    }

    /// 按钮 2 的视觉判断 + 测试断言共用. true = 下半栏两 panel 都可见。
    func isBottomBandVisible() -> Bool {
        visibility.bottomLeft && visibility.bottomRight
    }

    /// "全显示" (Cmd+Shift+1) — un-hides every panel without touching
    /// the dragged ratios.
    func showAllPanels() {
        visibility = PanelVisibilityState()
        scheduleSave()
    }

    // MARK: - Reset

    func resetToDefaults() async {
        snapshot = .default
        visibility = PanelVisibilityState()
        await saveImmediately()
    }

    // MARK: - Persistence (debounced)

    /// Debounce writes so a continuous drag gesture (60+ onChanged events
    /// per second) only triggers one CoreData `save()` at the gesture's
    /// tail. Cancels any pending write and starts a fresh 250ms timer.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            await self?.saveImmediately()
        }
    }

    private func saveImmediately() async {
        do {
            try await store.saveLayoutState(
                panelStatesJSON: PanelStatesEnvelope.encode(
                    collapsed: snapshot.collapsed,
                    visible: visibility
                ),
                panelRatiosJSON: LayoutSnapshot.encodeRatios(snapshot.ratios)
            )
        } catch {
            FileHandle.standardError.write(Data(
                "LayoutShellViewModel.saveImmediately: \(error)\n".utf8
            ))
        }
    }
}

// MARK: - Panel identity

/// Stable identifier for a panel slot in the 5-zone shell. Order matches
/// the `ratios` array index layout in `LayoutSnapshot`.
enum PanelID: Hashable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomRight

    /// Display title for the gutter / header bar.
    var title: String {
        switch self {
        case .topLeft: return "项目管理"
        case .topCenter: return "文档"
        case .topRight: return "检视"
        case .bottomLeft: return "聊天"
        case .bottomRight: return "状态"
        }
    }

    /// SF Symbol for the empty-state glyph (placeholder content).
    var symbolName: String {
        switch self {
        case .topLeft: return "folder"
        case .topCenter: return "doc.text"
        case .topRight: return "sidebar.right"
        case .bottomLeft: return "bubble.left.and.bubble.right"
        case .bottomRight: return "checklist"
        }
    }

    /// "View" menu keyboard equivalent (Cmd+1 … Cmd+5), FCP 范式.
    var menuShortcut: KeyEquivalent {
        switch self {
        case .topLeft: return "1"
        case .topCenter: return "2"
        case .topRight: return "3"
        case .bottomLeft: return "4"
        case .bottomRight: return "5"
        }
    }

    /// v0.04.0 FCP 3 toggle (沿 designer wenshu-fcp-fold-3buttons-2026-08-12
    /// 真值): 5 区全 dismissible, 区别于 v0.02.0 LT-01-fix5 装机 user 拍板的
    /// "核心创作区 (文档/聊天) 永驻" 硬约束。 FCP / Pages / Numbers 范式 =
    /// 全 toggle + 组合式 visibility, 不锁核心区。
    ///
    /// Compile-time constant (extensions can't be Codable, so these
    /// values don't enter the .ws JSON — they're invariant per panel
    /// identity). When we eventually lift this to a schema-driven
    /// config (e.g. user preferences in v0.09.x), the extension becomes
    /// a stored field on a new `PanelPrefs` struct.
    var isDismissible: Bool {
        switch self {
        case .topLeft: return true        // 项目管理 可隐藏
        case .topCenter: return true      // 文档 可隐藏 (v0.04.0 拍, 沿 FCP 范式)
        case .topRight: return true       // 检视 可隐藏
        case .bottomLeft: return true     // 聊天 可隐藏 (v0.04.0 拍, 沿 FCP 范式)
        case .bottomRight: return true    // 状态 可隐藏
        }
    }

    /// Q2 折叠态 (t_c6f48f43): 哪些 panel 可以折叠. 沿 isDismissible 同源
    /// 拍板 (老板 8/7 "文档/聊天 是核心创作区, 必须常驻") — 不可折叠
    /// panel (topCenter / bottomLeft) 在折叠菜单里直接不出现 (DESIGN
    /// §1.3 触发器 A 范式), 跟 disabled 不同. 3 可折叠 (topLeft / topRight /
    /// bottomRight) + 2 不可折叠 (topCenter / bottomLeft).
    var isCollapsible: Bool {
        switch self {
        case .topLeft: return true        // 项目管理 可折叠
        case .topCenter: return false     // 文档 不可折叠
        case .topRight: return true       // 检视 可折叠
        case .bottomLeft: return false    // 聊天 不可折叠
        case .bottomRight: return true    // 状态 可折叠
        }
    }
}

// MARK: - Panel visibility (LT-01-fix3)

/// One bool per panel. `true` = the panel participates in the layout;
/// `false` = it's hidden entirely (zero width, no splitter, no gutter).
///
/// Defaults to all-visible, which is also the fallback for any .ws file
/// written before LT-01-fix3 (see `PanelStatesEnvelope.decode`).
struct PanelVisibilityState: Codable, Sendable, Equatable {
    var topLeft: Bool
    var topCenter: Bool
    var topRight: Bool
    var bottomLeft: Bool
    var bottomRight: Bool

    init(
        topLeft: Bool = true,
        topCenter: Bool = true,
        topRight: Bool = true,
        bottomLeft: Bool = true,
        bottomRight: Bool = true
    ) {
        self.topLeft = topLeft
        self.topCenter = topCenter
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func isVisible(_ panel: PanelID) -> Bool {
        switch panel {
        case .topLeft: return topLeft
        case .topCenter: return topCenter
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        }
    }
}

// MARK: - panel_states JSON envelope

/// LT-01-fix3 widens the `CDLayoutState.panel_states` column payload from
/// a bare `PanelCollapsedState` object to
/// `{"collapsed": {...}, "visible": {...}}`.
///
/// The entity schema is untouched (still one `String` column) — only the
/// JSON *inside* it grew, so this stays on the CC side of AGENTS §5.
///
/// Backwards compatibility: `decode` sniffs for the `"collapsed"` key. A
/// pre-fix3 .ws holds the legacy flat shape and is routed through
/// `LayoutSnapshot.decodeCollapsed`, with visibility defaulting to
/// all-visible. Anything unparseable degrades to defaults rather than
/// throwing (same contract as the rest of LayoutState).
enum PanelStatesEnvelope {
    private struct Payload: Codable {
        var collapsed: PanelCollapsedState
        var visible: PanelVisibilityState
    }

    static func encode(collapsed: PanelCollapsedState, visible: PanelVisibilityState) -> String {
        let payload = Payload(collapsed: collapsed, visible: visible)
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    static func decode(
        _ string: String
    ) -> (collapsed: PanelCollapsedState, visible: PanelVisibilityState) {
        guard !string.isEmpty, let data = string.data(using: .utf8) else {
            return (PanelCollapsedState(), PanelVisibilityState())
        }
        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return (payload.collapsed, payload.visible)
        }
        // Legacy (pre-LT-01-fix3) flat shape, or garbage → defaults.
        return (LayoutSnapshot.decodeCollapsed(string), PanelVisibilityState())
    }
}

// MARK: - Layout arithmetic

/// Pure geometry for the 5-zone shell. Extracted out of `LayoutShellView`
/// in LT-01-fix3 so the hidden-panel redistribution rule is unit-testable
/// without instantiating SwiftUI.
///
/// Precedence per panel: hidden → 0pt · collapsed → gutter · else →
/// its share of what's left, renormalised against the other *expanded*
/// panels' ratios.
enum LayoutMetrics {

    /// Number of splitter bars actually rendered between `visibleCount`
    /// adjacent panels.
    static func splitterCount(visibleCount: Int) -> Int {
        max(0, visibleCount - 1)
    }

    /// (topLeft, topCenter, topRight) widths in points.
    static func upperWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat, CGFloat) {
        let hidden = [!visibility.topLeft, !visibility.topCenter, !visibility.topRight]
        let isCollapsed = [collapsed.topLeft, collapsed.topCenter, collapsed.topRight]
        let r = ratios.count == 3 || ratios.count == 5
            ? [ratios[0], ratios[1], ratios[2]]
            : [LayoutSnapshot.default.ratios[0],
               LayoutSnapshot.default.ratios[1],
               LayoutSnapshot.default.ratios[2]]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        let gutter = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<3).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * gutter)

        let expandedSum = (0..<3)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return gutter }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1), width(2))
    }

    /// (bottomLeft, bottomRight) widths in points. `ratios[4]` is
    /// bottomLeft's share of the lower band.
    static func lowerWidths(
        totalWidth: CGFloat,
        ratios: [Double],
        collapsed: PanelCollapsedState,
        visibility: PanelVisibilityState
    ) -> (CGFloat, CGFloat) {
        let leftRatio = ratios.count == 5 ? ratios[4] : LayoutSnapshot.default.ratios[4]
        let hidden = [!visibility.bottomLeft, !visibility.bottomRight]
        let isCollapsed = [collapsed.bottomLeft, collapsed.bottomRight]

        let visibleCount = hidden.filter { !$0 }.count
        let splitters = CGFloat(splitterCount(visibleCount: visibleCount))
            * CGFloat(LayoutSnapshot.splitterPixels)
        let available = max(0, totalWidth - splitters)

        // A collapsed lower panel keeps only its header bar; horizontally
        // it still needs a readable strip, so we reuse the upper gutter
        // width as its minimum footprint.
        let strip = CGFloat(LayoutSnapshot.topCollapsedPixels)
        let collapsedVisibleCount = (0..<2).filter { !hidden[$0] && isCollapsed[$0] }.count
        let forExpanded = max(0, available - CGFloat(collapsedVisibleCount) * strip)

        let r = [leftRatio, 1.0 - leftRatio]
        let expandedSum = (0..<2)
            .filter { !hidden[$0] && !isCollapsed[$0] }
            .reduce(0.0) { $0 + r[$1] }

        func width(_ i: Int) -> CGFloat {
            if hidden[i] { return 0 }
            if isCollapsed[i] { return strip }
            guard expandedSum > 0 else { return 0 }
            return forExpanded * CGFloat(r[i] / expandedSum)
        }
        return (width(0), width(1))
    }

    /// Height of the lower band. If every lower panel is hidden the band
    /// collapses to 0 and the upper band takes the whole window (and
    /// vice-versa) — otherwise `ratios[3]` splits them.
    ///
    /// LT-01-fix5 优化1 fallback: 装机 user 8/7 拍板, 当所有可隐藏 panel
    /// (项目管理 / 检视 / 状态) 都被隐藏后, 整个窗口只剩下 文档
    /// (topCenter) + 聊天 (bottomLeft) 这两块核心创作区, 此时
    /// 自动切到 "50:50" 模式 — upper band 占 50% 总高, lower band 占
    /// 50% 总高. 这样用户在大屏前用 chat + doc 双窗口时不会因为之前
    /// 拖到 30:70 而被迫拖回去. 持久化的 `ratios[3]` 在 fallback 期间
    /// **不**被改写, 一旦用户手动 un-hide 一个 dismissible panel,
    /// 下次 fallback 计算立刻退出, 还原 ratio-driven 行为.
    static func lowerBandHeight(
        totalHeight: CGFloat,
        ratios: [Double],
        visibility: PanelVisibilityState
    ) -> CGFloat {
        let lowerVisible = visibility.bottomLeft || visibility.bottomRight
        let upperVisible = visibility.topLeft || visibility.topCenter || visibility.topRight
        if !lowerVisible { return 0 }
        if !upperVisible { return totalHeight }
        if isFallbackLayout(visibility: visibility) {
            // Force 50:50 split regardless of what `ratios[3]` says.
            return totalHeight * 0.5
        }
        let r = ratios.count == 5 ? ratios[3] : LayoutSnapshot.default.ratios[3]
        return totalHeight * CGFloat(r)
    }

    /// LT-01-fix5 优化1: 当所有 dismissible panel (项目管理 / 检视 /
    /// 状态) 都被隐藏, 只剩 文档 + 聊天 这两块不可隐藏的核心区可见
    /// 时, 返回 `true`. 这是 "文档:聊天 = 50:50 fallback layout" 的
    /// 触发条件.
    ///
    /// 注意: 默认情况下 (所有 panel 都可见) 此函数返回 `false`.
    /// `isDismissible` 由 `PanelID` extension 提供 — 是 compile-time
    /// 常量 (见 `PanelID.swift`).
    static func isFallbackLayout(visibility: PanelVisibilityState) -> Bool {
        // Document + chat (topCenter + bottomLeft) are always visible
        // because they're not dismissible. We just need to make sure no
        // dismissible panel slipped into visible = true.
        guard visibility.topCenter, visibility.bottomLeft else { return false }
        return !visibility.topLeft
            && !visibility.topRight
            && !visibility.bottomRight
    }
}
