// IconLibrary.swift · 文枢 (Wenshu) · v0.05.0 ICON v2
//
// 沿 v0.03.0 V0-fix-11-4 t_c8ec4bd6 落的 11 SF Symbol 单一真值源基础上,
// v0.05.0 t_d4e02b80 加 SPM (lucide-swift, ajaxjiang96) 收口 + Action 收纳。
//
// 设计意图 (沿 AGENTS.md §3.2 / §3.5 / §3.8 / §3.9 / §5.1 / §14.9 + t_b1e81260):
//   - SF Symbol (现网) → Lucide 真名 (沿 t_a4e3ff5f) 双 namespace 切换路径
//   - rawValue 沿用 SF Symbol 字面量 (V0-fix-3/5/7/8 + LT-01-fix7 + IconLibrary V0-fix-11-4 测试断言保护,
//     XCTAssertTrue(code.contains("\"folder\"")) 等 20+ 断言, 不动)
//   - lucideName 字段 = v0.05.x 切 Lucide 渲染的预留 API,
//     v0.05.0 实施阶段全部置字面值 metadata (SPM 已加, 但渲染层保留 SF Symbol 兜底,
//     双重保险 — 见 AGENTS §3.9 拍板)
//   - Action 枚举: 15 case (fullScreenToggle / docItem / fileList /
//     emptyTray / expandOptions / checkbox / leaf / layoutSwitch +
//     newProject / openProject / importProject / exportProject /
//     createDocument / chatPlaceholder / characterWorldEntry)
//     收纳 8 散落文件的字面量 (顶部 toolbar 7 + inspector leaf +
//     editor outline doc.text 态 + editor outline 文件列表 +
//     project 空 tray + expandOptions sparkles + expandOptions checkbox)
//     + 2 fillSymbol 静态方法 (docItemFill / checkboxFill), 单一真值源集中管理
//
// 用法 1 (5 收口函数): `IconLibrary.shared.symbolName(for: .projects)` →
//   SF Symbol 字符串, 内部 = Name.projects.rawValue
// 用法 2 (8 散落文件): `IconLibrary.Action.fileList.symbolName` →
//   "list.bullet.rectangle"; `IconLibrary.Action.fileList.lucideName` →
//   "list" (v0.05.x 启用)
// 用法 3 (v0.05.x 切 Lucide 渲染): `Image(uiImage: LucideSwift.image(named:))`
//   走 `LucideSwift` 库 — 当前帧仍未启用, API 留 metadata

import Foundation

/// 单一真值源 — 11 SF Symbol (5 区 layout grammar 沿 AGENTS §8.1:
/// 左上 5 tab + 下左 4 chat + 右上 2 inspector)。
///
/// rawValue = SF Symbol 字符串字面量, 严格沿 V0-fix-3/5/6/7/8 +
/// V0-fix-11-4 (IconLibrary t_c8ec4bd6) + 各 V0Fix*Tests / LT-01-fix7 测试
/// 断言 grep 的字面量 (XCTAssertTrue(code.contains("\"folder\"")) 等),
/// 不擅自改 — 改 rawValue 必破 20+ 不回归测试断言, 边界严 (AGENTS §3.9)。
///
/// lucideName 字段 = Lucide 真名 (沿 t_b1e81260-ICON-v2-LIB §2 37 位映射表),
/// v0.05.0 阶段 SwiftUI 仍渲 SF Symbol (systemImage: 兜底), lucideName
/// 仅作字面值集中管理的 metadata 字段 — v0.05.x 启用 Lucide 渲染时切
/// `Image(uiImage: LucideSwift.image(named:))` 即生效。
struct IconLibrary {

    /// 全局单例 — 字典无状态, 单例 + private init 防止外部误 new。
    static let shared = IconLibrary()

    private init() {}

    // MARK: - 11 SF Symbol 枚举 (rawValue = SF Symbol 字符串, 测试保护)

    enum Name: String, CaseIterable, Sendable {

        // MARK: 5 tab (左上 1-5)

        /// 槽位 1: 项目 (左上第 1 tab)
        case projects = "folder"

        /// 槽位 2: 章节 (左上第 2 tab)
        case chapters = "doc.text"

        /// 槽位 3: 设定 (左上第 3 tab)
        case settings = "gearshape"

        /// 槽位 4: 资料 (左上第 4 tab)
        /// 保留 `archive` rawValue — V0-fix-11-4 + ProjectListView.swift:84 + V0Fix3/8 测试断言。
        case materials = "archive"

        /// 槽位 5: 看板 (左上第 5 tab)
        case kanban = "square.grid.3x3"

        // MARK: 4 chat (下左 1-4)

        /// 槽位 1: 聊天 (下左第 1 sub tab)
        case chat = "bubble.left.and.bubble.right"

        /// 槽位 2: 时间线 (下左第 2 sub tab)
        case timeline = "clock.arrow.circlepath"

        /// 槽位 3: 关系图 (下左第 3 sub tab)
        case relationships = "person.2"

        /// 槽位 4: 大纲 (下左第 4 sub tab)
        case outline = "list.bullet.indent"

        // MARK: 2 inspector (右上 1-2)

        /// 槽位 1: 伏笔 (右上第 1 tab)
        case foreshadow = "eye"

        /// 槽位 2: 修真 (右上第 2 tab)
        case revise = "pencil.and.list.clipboard"
    }

    /// 11 SF Symbol 真值字典, key = Name, value = SF Symbol rawValue。
    /// 由 `Name.allCases` 自动派生, 与枚举 rawValue 严格 1:1。
    let icons: [Name: String] = Dictionary(
        uniqueKeysWithValues: Name.allCases.map { ($0, $0.rawValue) }
    )

    /// Lucide 真名字典 (沿 t_b1e81260-ICON-v2-LIB §2 37 位映射)。
    /// v0.05.0 阶段 SwiftUI 不消费 (systemImage: 兜底);
    /// v0.05.x 切 Lucide 渲染时, 视图层走 `Image(uiImage: LucideSwift.image(named:))` + 此字段。
    let lucideNames: [Name: String] = [
        .projects: "folder",
        .chapters: "file-text",
        .settings: "settings",
        .materials: "archive",
        .kanban: "layout-grid",
        .chat: "message-square",
        .timeline: "history",
        .relationships: "users",
        .outline: "list-tree",
        .foreshadow: "eye",
        .revise: "clipboard-pen"
    ]

    /// 单点查: SF Symbol rawValue (现网渲染用, 测试断言保护)。
    func symbolName(for name: Name) -> String { name.rawValue }

    /// 单点查: Lucide 真名 — v0.05.0 阶段 SwiftUI 不消费, 仅 metadata。
    func lucideName(for name: Name) -> String? { lucideNames[name] }

    // MARK: - Action 收纳 (8 散落文件字面量)

    /// Action 枚举收口 8 散落文件的字面量 (不含 11 名 enum 真值的
    /// 5 收口函数)。 每个 case = 1 个 UI 动作的 SF Symbol (rawValue) +
    /// 对应 Lucide 真名 (lucideName, v0.05.x metadata)。
    enum Action: String, CaseIterable, Sendable {

        /// 全屏 toggle (右下 EditorBottomToolbar) — 14pt medium
        case fullScreenToggle = "arrow.up.left.and.arrow.down.right"

        /// 文档 active (editor outline active row + 文档 icon) — 14pt medium
        case docItem = "doc.text"

        /// 文件列表 (ChapterTreeView / ProjectBrowserView / EditorOutlineView) — 14pt regular
        case fileList = "list.bullet.rectangle"

        /// 空 tray (ProjectListView / ProjectBrowserView) — 56pt light
        case emptyTray = "tray"

        /// 举一反三 入口 (ExpandOptionsView header) — 14pt medium
        case expandOptions = "sparkles"

        /// 4 类 checkbox 选中态 (ExpandOptionsView row) — 14pt medium
        case checkbox = "square"

        /// inspector 兜底 (空 foreshadow leaf) — 28pt light
        case leaf = "leaf"

        /// FCP 折叠 toggle (LayoutShellView fold 1, 区显/区隐 fill 二态) — 14pt medium
        /// 区显走 `rectangle.split.3x1` 描边; 区隐走 fill 变体 —
        /// 由 `IconLibrary.Action.layoutSwitchFillSymbol()` 静态方法返回。
        case layoutSwitch = "rectangle.split.3x1"

        /// 顶部 toolbar 新建项目 (LayoutShellView 红黄绿后 #1 按钮) — 14pt medium
        case newProject = "plus"

        /// 顶部 toolbar 打开项目 (LayoutShellView #2 按钮) — 14pt medium
        case openProject = "folder.badge.plus"

        /// 顶部 toolbar 导入项目 (LayoutShellView #3 按钮, placeholder) — 14pt medium
        case importProject = "square.and.arrow.down"

        /// 顶部 toolbar 分享/导出 (LayoutShellView #4 按钮, placeholder) — 14pt medium
        case exportProject = "square.and.arrow.up"

        /// 顶部 toolbar 新建文档 (LayoutShellView #5 按钮) — 14pt medium
        case createDocument = "doc.badge.plus"

        /// 顶部 toolbar 聊天占位 (LayoutShellView .chat route fallback) — 30pt light
        case chatPlaceholder = "bubble.left.and.bubble.right"

        /// 顶部 toolbar 人物世界占位 (LayoutShellView .characterWorld route fallback) — 30pt light
        case characterWorldEntry = "person.2.crop.square.stack"

        /// SF Symbol 字面量 (现网渲染, 测试/字面断言保护)。
        var symbolName: String { rawValue }

        /// Lucide 真名 (v0.05.x metadata)。
        var lucideName: String? {
            switch self {
            case .fullScreenToggle:     return "maximize-2"
            case .docItem:              return "file-text"
            case .fileList:             return "list"
            case .emptyTray:            return "inbox"
            case .expandOptions:        return "sparkles"
            case .checkbox:             return "square"
            case .leaf:                 return "leaf"
            case .layoutSwitch:         return "panel-left"
            case .newProject:           return "plus"
            case .openProject:          return "folder-plus"
            case .importProject:        return "download"
            case .exportProject:        return "upload"
            case .createDocument:       return "file-plus"
            case .chatPlaceholder:      return "message-square"
            case .characterWorldEntry:  return "users"
            }
        }

        /// LayoutSwitch 区隐变体 (`rectangle.split.3x1.fill`)。
        /// Fold toggle 用 — 区显走 `symbolName` (描边), 区隐走 fill 变体。
        static func layoutSwitchFillSymbol() -> String {
            "rectangle.split.3x1.fill"
        }

        /// DocItem active 变体 (`doc.text.fill`)。
        /// Editor outline active row 用 — 非 active 走 `symbolName` (描边),
        /// active 走 fill 变体。
        static func docItemFillSymbol() -> String {
            "doc.text.fill"
        }

        /// Checkbox 选中变体 (`checkmark.square.fill`)。
        /// ExpandOptionsView row 用 — 未选走 `symbolName` (描边),
        /// 已选走 fill 变体。
        static func checkboxFillSymbol() -> String {
            "checkmark.square.fill"
        }

        /// FCP 折叠第三按钮 (检视 toggle) 字面量 — 沿 v0.04.0 t_bfa84198
        /// 范式 = `checklist` 描边 + accent blue 背景区分显隐。
        static let inspectorFoldSymbol = "checklist"
    }
}
