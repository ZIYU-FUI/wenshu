// InspectorCatalog.swift · Wenshu · v1.71a ticket 001
//
// Per boss 2026-09-22 OOB 'UI 业务 数据分离，符合苹果的 MVVM' (= the
// other zones have done UI / 业务 / 数据 分离; the right column
// also needs to match). Per Q244 §3.1 + §5.2 (wenshu MVVM audit
// pattern): right column's shell widget catalog + page routing were
// inlined in ShellDetailColumn.filteredToolsForCurrentPage (=
// business + data inside the View, violating the canonical Apple
// MVVM layering).
//
// This commit (v1.71a) extracts the DATA layer to a new file.
// Tickets 02 (InspectorPage.tools = business layer) and 03
// (ShellDetailColumn 切到新 API + 删旧 inline) follow.
//
// Per Q244 §3.1 SoT pool unchanged: InspectorCatalog is stateless
// static (= catalog 12 条不变, no @Observable needed; = pure data
// + business definitions, not state).
//
// Per boss 2026-09-16 OOB 'ICON 丢失还是没有彻底解决': the 12 SF
// Symbols 6 icons are the verified names per /Applications/SF
// Symbols Beta.app/Contents/Executables/sfsymbols search 2026-09-16
// (= post Lucide → SF Symbols 6 migration真值).
//
// Per boss 2026-09-18 '所有 ICON，都不要 .fill': outline glyphs only
// (= no .fill variant in any catalog entry).
//
// Per Q57 + Q112 + Q186: extract InspectorCatalog to its own file.
// 1 file per ticket, atomic commit, no behavior change in this
// commit (= ShellDetailColumn still references its inline catalog;
// ticket 03 cuts over).

import SwiftUI

/// Single specialized tool = the data-layer type for the right
/// column's specializedTools zone. Owned by `InspectorCatalog` (= 12
/// static entries) and `InspectorPage.tools` (ticket 02 = the
/// business-layer routing, which returns `[InspectorTool]`).
///
/// `view` is a `@MainActor () -> AnyView` closure so that catalog
/// load (= ticket 02 `InspectorPage.tools` first read) does NOT
/// eagerly instantiate 12 specialized tool views (= the previous
/// inline tuple eagerly constructed `AnyView(ForeshadowingView())`
/// etc. on every body re-render). View construction is deferred to
/// `view()` call time (= one instantiation per render, not 12).
///
/// `id` is the i18n key (= boss 9/12 真值 `tab.title.X` keys). It
/// doubles as the unique identifier for Hashable / Identifiable and
/// the lookup key for `WenshuI18n.t(_:)` (= title is the resolved
/// localized string).
///
/// Per Q244 §5.2 service-style extraction (不动 SoT, 业务从 View 抽走):
/// InspectorTool is a value type, Sendable, stateless, owned by
/// `InspectorCatalog`. View layer never constructs these directly —
/// it consumes them via `InspectorPage.tools`.
public struct InspectorTool: Identifiable, Hashable, Sendable {
    public let id: String
    public let icon: String
    public let title: String
    public let view: @MainActor () -> AnyView

    public static func == (lhs: InspectorTool, rhs: InspectorTool) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Right column specializedTools zone = data layer (single source of
/// truth for the 12 tool definitions).
///
/// Per Q244 §3.1 + boss 2026-09-22 OOB: this replaces the inline
/// tuple array that previously lived in
/// `ShellDetailColumn.filteredToolsForCurrentPage` (lines 111-130,
/// deleted in ticket 03). The 12 entries mirror the 12 specialized
/// tool views under `Views/Tools/` + `Views/SpecializedTools/`.
public enum InspectorCatalog {
    // v1.71a — 12 specialized tools, derived from the original inline
    // tuple in ShellDetailColumn.swift:111-130 (= v1.0.0-m1-shell
    // boss OOB 'three per page, split into four pages, show them all'
    // + 'the 12-tab view's localization is incomplete'真值).

    public static let foreshadowing = InspectorTool(
        id: "tab.title.foreshadowing",
        icon: "arrow.triangle.branch",
        title: WenshuI18n.t("tab.title.foreshadowing"),
        view: { AnyView(ForeshadowingView()) }
    )

    public static let placeholder = InspectorTool(
        id: "tab.title.placeholder",
        icon: "square.dashed",
        title: WenshuI18n.t("tab.title.placeholder"),
        view: { AnyView(PlaceholderView()) }
    )

    public static let longForm = InspectorTool(
        id: "tab.title.long_form",
        icon: "checkmark.shield",
        title: WenshuI18n.t("tab.title.long_form"),
        view: { AnyView(LongFormGuardrailsView()) }
    )

    public static let readerExperience = InspectorTool(
        id: "tab.title.reader_experience",
        icon: "sparkles",
        title: WenshuI18n.t("tab.title.reader_experience"),
        view: { AnyView(ReaderExperienceView()) }
    )

    public static let plotThread = InspectorTool(
        id: "tab.title.plot_thread",
        icon: "arrow.triangle.branch",
        title: WenshuI18n.t("tab.title.plot_thread"),
        view: { AnyView(PlotThreadView()) }
    )

    public static let genreFit = InspectorTool(
        id: "tab.title.genre_fit",
        icon: "bookmark",
        title: WenshuI18n.t("tab.title.genre_fit"),
        view: { AnyView(GenreFitView()) }
    )

    public static let emotionCurve = InspectorTool(
        id: "tab.title.emotion_curve",
        icon: "waveform.path.ecg",
        title: WenshuI18n.t("tab.title.emotion_curve"),
        view: { AnyView(EmotionCurveView()) }
    )

    public static let characterRelationships = InspectorTool(
        id: "tab.title.character_relationships",
        icon: "person.2",
        title: WenshuI18n.t("tab.title.character_relationships"),
        view: { AnyView(CharacterRelationshipsView()) }
    )

    public static let characterLifecycle = InspectorTool(
        id: "tab.title.character_lifecycle",
        icon: "clock",
        title: WenshuI18n.t("tab.title.character_lifecycle"),
        view: { AnyView(CharacterLifecycleView()) }
    )

    public static let tagManager = InspectorTool(
        id: "tab.title.tag_manager",
        icon: "tag",
        title: WenshuI18n.t("tab.title.tag_manager"),
        view: { AnyView(TagManagerView()) }
    )

    public static let ideaLibrary = InspectorTool(
        id: "tab.title.idea_library",
        icon: "lightbulb",
        title: WenshuI18n.t("tab.title.idea_library"),
        view: { AnyView(IdeaLibraryView()) }
    )

    public static let bookSettingConstraints = InspectorTool(
        id: "tab.title.book_setting_constraints",
        icon: "book.closed",
        title: WenshuI18n.t("tab.title.book_setting_constraints"),
        view: { AnyView(BookSettingConstraintsView()) }
    )

    /// All 12 tools in catalog order. Used by ticket 02
    /// `InspectorPage.tools` (= business layer routing) to return the
    /// 3 tools per page. Used by ticket 04 tests for catalog
    /// completeness assertions (= `count == 12` + unique IDs).
    public static let allTools: [InspectorTool] = [
        InspectorCatalog.foreshadowing,
        InspectorCatalog.placeholder,
        InspectorCatalog.longForm,
        InspectorCatalog.readerExperience,
        InspectorCatalog.plotThread,
        InspectorCatalog.genreFit,
        InspectorCatalog.emotionCurve,
        InspectorCatalog.characterRelationships,
        InspectorCatalog.characterLifecycle,
        InspectorCatalog.tagManager,
        InspectorCatalog.ideaLibrary,
        InspectorCatalog.bookSettingConstraints
    ]
}