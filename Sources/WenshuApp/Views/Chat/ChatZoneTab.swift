//
//  ChatZoneTab.swift · Wenshu · v0.40 apple-001 phase 3 ticket 1a
//
//  Extracted from App.swift (formerly nested as
//  `enum ChatZoneTab` inside `struct ChatZoneView`, line 1155).
//
//  v0.21 ticket 43: chat zone top-bar has 3 tabs to switch between
//  (boss 2026-08-22 06:22 拍 backlog 20). The nested enum blocked
//  the upcoming ChatZoneTabBar extraction (= ChatZoneTabBar's
//  parameter type was `ChatZoneTab` = a path-bound
//  nested type that can't cross file boundaries). Promoting the
//  enum to module scope = ChatZoneTabBar (and any future
//  caller) can reference it without the parent struct.
//
//  Apple HIG = one type per file. The enum is small (= 13 LOC
//  including the icon computed property) but the @MainActor
//  isolation pattern is non-trivial (= the enum holds display
//  state, not raw model state, = it belongs with the view layer,
//  not the data layer). The icon property uses Lucide-first
//  with SF Symbol fallback (= the v0.25.1 ticket 005 fix:
//  "bot" hits Lucide, = the canonical icon per boss 8/26 OOB).
//
//  v0.40 apple-001 phase 3 ticket 1a (ChatZoneTabBar prep):
//  ticket 1b (next slice) will move the ChatZoneTabBar struct
//  out of App.swift into its own file at
//  Sources/WenshuApp/Views/Chat/ChatZoneTabBar.swift, where
//  it can use this module-level ChatZoneTab directly (= no
//  more `ChatZoneTab` path-bound references).
//

import SwiftUI

// v0.21 ticket 43: chat zone top-bar has 3 tabs to switch between
// (boss 2026-08-22 06:22 拍 backlog 20).
// v0.40 apple-001 phase 3 ticket 4a: rawValue switched from CJK display
// labels (= "对话" / "搜索" / "设置") to ASCII identifiers (= "chat" /
// "search" / "settings") per Apple HIG convention for enum rawValues
// (= machine identifiers should be ASCII). Display labels moved to
// computed `displayLabel` property using WenshuI18n.t() (= "tab.title.chat"
// / "tab.title.search" / "tab.title.settings", shipped in Q2 batch 2
// + this slice).
enum ChatZoneTab: String, CaseIterable, Identifiable {
    case chat = "chat"
    case search = "search"
    case settings = "settings"
    var id: String { rawValue }
    var displayLabel: String {
        switch self {
        case .chat: return WenshuI18n.t("tab.title.chat")
        case .search: return WenshuI18n.t("tab.title.search")
        case .settings: return WenshuI18n.t("tab.title.settings")
        }
    }
    var icon: String {
        switch self {
        case .chat: return "bot"  // v0.25.1 (= ticket 005): 老板 2026-08-26 拍 .bot 直接替换 SF person.crop... (= Lucide-first helper 在 ChatZoneTabBar 里用了, "bot" 命中 Lucide, SF Symbol 作为 fallback). Old (= ticket 015.014 robot face) was SF `person.crop.circle.badge.questionmark` (= Lucide 没有同名, 只能 Image(systemName:) fallback, 不再使用).
        case .search: return "magnifyingglass"  // 老板 8/25 拍 "保留现在的这个"
        case .settings: return "slider.horizontal.3"  // 老板 8/25 拍 "保留现在的这个"
        }
    }
}
