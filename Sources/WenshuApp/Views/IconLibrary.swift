// IconLibrary.swift · 文枢 (Wenshu) · v0.03.0 V0-fix-10.1 → V0-fix-11
//
// SF Symbol namespace — replaces scattered "Image(systemName:)" literals
// across 6+ Swift files (LayoutShellView, PlaceholderContent, PanelContainer,
// ProjectListView, ChatPanelView, InspectorView). All ICON names live in
// one place so V0-fix-11 + future V0-fix-N can swap SF Symbols (or migrate
// to Lucide/Phosphor at v0.05.0+) without hunting through every view.
//
// V0-fix-11: Action enum +2 cases — openProject (folder.badge.plus) +
// importProject (square.and.arrow.down). 装机 user 8/11 14:35 红字
// "在新建后面加上打开和导入占位" → 修真 #1 修真 + 按钮修真 3 个纯 ICON
// 修真群 (新建 / 打开 / 导入占位). Also flips newProject from
// "plus.circle.fill" (V0-fix-8 fat + ICON) to "plus" (FCP Viewer 修真 +
// ICON, 沿 V0-fix-11 #1).
//
// 不引入 ICON 库依赖 (沿 V0-fix-10.1 — SF Symbol 6 优先, 不修真
// Package.swift 加 Lucide / Phosphor SPM 修真). 全部 18 SF Symbol
// SF Symbol 6 (WWDC 2024 + macOS 27 SDK 默认安装) 修真支持.

import SwiftUI

/// Centralized namespace for every SF Symbol string in the 文枢 (Wenshu)
/// app. Three groups: `Tab` (5 project + 4 chat + 2 inspector + 5 panel)
/// and `Action` (10 toolbar ICONs). Accessor functions take a typed enum
/// and return the raw SF Symbol string — that keeps the view code free
/// of literal SF Symbol strings.
enum IconLibrary {

    /// Tab SF Symbols — every ICON used by a top-of-panel tab/header.
    enum Tab {

        /// Project management 5 tab (V0-fix-8 AIF 16:20 截图真值):
        /// folder / doc.text / gearshape / archive / square.grid.3x3.
        enum Project: String {
            case projects  = "folder"
            case chapters  = "doc.text"
            case settings  = "gearshape"
            case resources = "archive"
            case kanban    = "square.grid.3x3"
        }

        /// Chat 4 tab (V0-fix-8 修真):
        /// bubble.left.and.bubble.right / clock.arrow.circlepath /
        /// person.2 / list.bullet.indent.
        enum Chat: String {
            case chat          = "bubble.left.and.bubble.right"
            case timeline      = "clock.arrow.circlepath"
            case relationships = "person.2"
            case outline       = "list.bullet.indent"
        }

        /// Inspector 2 tab (V0-fix-4 Fix 5):
        /// eye (伏笔) / pencil.and.list.clipboard (修订).
        enum Inspector: String {
            case foreshadow = "eye"
            case revision   = "pencil.and.list.clipboard"
        }

        /// Panel placeholder 5 SF Symbols (used by PlaceholderContent +
        /// PanelContainer when a panel is empty / placeholder).
        enum Panel: String {
            case topLeft     = "folder"
            case topCenter   = "doc.text"
            case topRight    = "sidebar.right"
            case bottomLeft  = "bubble.left.and.bubble.right"
            case bottomRight = "checklist"
        }
    }

    /// Action toolbar ICONs (新建/打开/导入/etc) — V0-fix-11 #1 adds
    /// openProject + importProject for the macOS title bar 3-ICON 修真群.
    enum Action: String {

        /// V0-fix-11 修真 #1: + 按钮 — "plus" (FCP Viewer thin + ICON),
        /// replacing V0-fix-8's "plus.circle.fill" (fat +).
        case newProject    = "plus"

        /// V0-fix-11 修真 #1: 打开项目 — 新建后面 + ICON. Posts
        /// `.wenshuOpenProjectURL` via NotificationCenter (wired by
        /// FileCommands V0-fix-10.1).
        case openProject   = "folder.badge.plus"

        /// V0-fix-11 修真 #1: 导入项目 — 打开后面 + ICON, `.disabled(true)`
        /// placeholder, real logic comes in v0.04.0.
        case importProject = "square.and.arrow.down"

        // Existing cases (V0-fix-10.1)
        case createProject    = "doc.badge.plus"
        case chatPlaceholder  = "bubble.left.and.bubble.right"
        case characterWorld   = "person.2.crop.square.stack"
        case leaf             = "leaf"
        case sparkles         = "sparkles"
        case checkmarkFilled  = "checkmark.square.fill"
        case squareEmpty      = "square"
    }

    // MARK: - Accessors (typed enum → SF Symbol string)

    /// Project management 5 tab SF Symbol accessor — LayoutShellView
    /// `.topLeftHeaderBar` + ProjectListView.
    static func tab(_ kind: ProjectManagementTab) -> String {
        switch kind {
        case .projects:  return Tab.Project.projects.rawValue
        case .chapters:  return Tab.Project.chapters.rawValue
        case .settings:  return Tab.Project.settings.rawValue
        case .resources: return Tab.Project.resources.rawValue
        case .kanban:    return Tab.Project.kanban.rawValue
        }
    }

    /// Chat 4 tab SF Symbol accessor — ChatPanelView.
    static func tab(_ kind: ChatPanelTab) -> String {
        switch kind {
        case .chat:          return Tab.Chat.chat.rawValue
        case .timeline:      return Tab.Chat.timeline.rawValue
        case .relationships: return Tab.Chat.relationships.rawValue
        case .outline:       return Tab.Chat.outline.rawValue
        }
    }

    /// Inspector 2 tab SF Symbol accessor — InspectorView.
    static func tab(_ kind: InspectorViewModel.Tab) -> String {
        switch kind {
        case .foreshadow: return Tab.Inspector.foreshadow.rawValue
        case .revision:   return Tab.Inspector.revision.rawValue
        }
    }

    /// Panel placeholder SF Symbol accessor — PlaceholderContent +
    /// PanelContainer.
    static func panel(_ id: PanelID) -> String {
        switch id {
        case .topLeft:     return Tab.Panel.topLeft.rawValue
        case .topCenter:   return Tab.Panel.topCenter.rawValue
        case .topRight:    return Tab.Panel.topRight.rawValue
        case .bottomLeft:  return Tab.Panel.bottomLeft.rawValue
        case .bottomRight: return Tab.Panel.bottomRight.rawValue
        }
    }
}
