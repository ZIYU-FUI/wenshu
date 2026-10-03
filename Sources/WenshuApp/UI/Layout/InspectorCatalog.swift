// InspectorCatalog.swift · Wenshu
//
// Per Q244 §3.1 + §5.2 (wenshu MVVM audit pattern): right column's
// shell widget catalog + page routing were inlined in
// ShellDetailColumn.filteredToolsForCurrentPage (= business + data
// inside the View, violating the canonical Apple MVVM layering).
// After Phase 6, ShellDetailColumn is InspectorView; = this
// catalog is the data layer paired with InspectorView.
//
// Extracts the DATA layer to a new file (= the static catalog of InspectorPage metadata).
// Tickets 02 (InspectorPage.tools = business layer) and 03
// (InspectorView 切到新 API + 删旧 inline) follow.
//
// Per Q244 §3.1 SoT pool unchanged: InspectorCatalog is stateless
// static (= catalog 12 条不变, no @Observable needed; = pure data
// + business definitions, not state).
//
// The 12 SF Symbols 6 icons are the verified names per
// /Applications/SF Symbols Beta.app/Contents/Executables/sfsymbols
// search 2026-09-16 (= post Lucide → SF Symbols 6 migration真值).
//
// Outline glyphs only (= no .fill variant in any catalog entry).
//
// Per Q57 + Q112 + Q186: extract InspectorCatalog to its own file.
// 1 file per ticket, atomic commit, no behavior change in this
// commit (= InspectorView still references its inline catalog;
// ticket 03 cuts over).

import SwiftUI

/// Inspector page tab selection (= 4 cases per boss spec = the
/// 4 inspector column pages: Authoring / Style / Characters /
/// Project Management). Lives in InspectorCatalog (= same file
/// as InspectorTool = the page → tools mapping reads the
/// catalog via `InspectorCatalog.<tool>` references).
///
/// Originally defined in the deleted wenshu-summary wrapper layer
/// (= removed in Phase 6 because it conflated column-binding
/// plumbing with the Apple canonical NavigationSplitView shape).
/// Moved here as part of the multi-column rewrite that strips
/// wenshu-summary wrappers; = the enum is a data-layer concern
/// and pairs with InspectorTool in this catalog file.
enum InspectorPage: Hashable, CaseIterable {
    case authoringFiction
    case authoringStyle
    case authoringCharacters
    case projectManagement

    var localizedTitle: String {
        switch self {
        case .authoringFiction:     return WenshuI18n.t("inspector.page.authoringFiction")
        case .authoringStyle:       return WenshuI18n.t("inspector.page.authoringStyle")
        case .authoringCharacters:  return WenshuI18n.t("inspector.page.authoringCharacters")
        case .projectManagement:    return WenshuI18n.t("inspector.page.projectManagement")
        }
    }

    var icon: String {
        switch self {
        case .authoringFiction:     return "book.pages"
        case .authoringStyle:       return "paintpalette"
        case .authoringCharacters:  return "person.2"
        case .projectManagement:    return "folder.badge.gearshape"
        }
    }

    /// Page→tools routing. The page enum owns the routing as a
    /// computed property (= page 跟它的 3 tools 绑一起 = single
    /// source of truth; = 新增 page 只改 enum 一个地方).
    var tools: [InspectorTool] {
        switch self {
        case .authoringFiction:
            return [
                InspectorCatalog.foreshadowing,
                InspectorCatalog.placeholder,
                InspectorCatalog.plotThread
            ]
        case .authoringStyle:
            return [
                InspectorCatalog.longForm,
                InspectorCatalog.readerExperience,
                InspectorCatalog.genreFit
            ]
        case .authoringCharacters:
            return [
                InspectorCatalog.characterRelationships,
                InspectorCatalog.characterLifecycle,
                InspectorCatalog.emotionCurve
            ]
        case .projectManagement:
            return [
                InspectorCatalog.ideaLibrary,
                InspectorCatalog.tagManager,
                InspectorCatalog.bookSettingConstraints,
                InspectorCatalog.bookmark,
                InspectorCatalog.backgroundReview
            ]
        }
    }
}

/// Single specialized tool = the data-layer type for the right
/// column's specializedTools zone. Owned by `InspectorCatalog` (= 13
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
/// `id` is the i18n key (= `tab.title.X` keys). It
    /// doubles as the unique identifier for Hashable / Identifiable and
    /// the lookup key for `WenshuI18n.t(_:)` (= title is the resolved
    /// localized string).
///
/// Per Q244 §5.2 service-style extraction (不动 SoT, 业务从 View 抽走):
/// InspectorTool is a value type, Sendable, stateless, owned by
/// `InspectorCatalog`. View layer never constructs these directly —
/// it consumes them via `InspectorPage.tools`.
struct InspectorTool: Identifiable, Hashable, Sendable {
    let id: String
    let icon: String
    let title: String
    let view: @MainActor () -> AnyView

    static func == (lhs: InspectorTool, rhs: InspectorTool) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Right column specializedTools zone = data layer (single source of
/// truth for the 12 tool definitions).
///
/// Per Q244 §3.1: this replaces the inline tuple array that previously
/// lived in the deleted ShellDetailColumn (= replaced by InspectorView
/// in Phase 6; = the legacy lines 111-130 are now obsolete).
/// The 12 entries mirror the 12 specialized tool views under
/// `Views/Tools/` + `Views/SpecializedTools/`.
enum InspectorCatalog {
    // 12 specialized tools, derived from the original inline
    // tuple in the now-deleted ShellDetailColumn (= lines 111-130).

    static let foreshadowing = InspectorTool(
        id: "tab.title.foreshadowing",
        icon: "arrow.triangle.branch",
        title: WenshuI18n.t("tab.title.foreshadowing"),
        view: { AnyView(ForeshadowingView()) }
    )

    static let placeholder = InspectorTool(
        id: "tab.title.placeholder",
        icon: "square.dashed",
        title: WenshuI18n.t("tab.title.placeholder"),
        view: { AnyView(PlaceholderView()) }
    )

    static let longForm = InspectorTool(
        id: "tab.title.long_form",
        icon: "checkmark.shield",
        title: WenshuI18n.t("tab.title.long_form"),
        view: { AnyView(LongFormGuardrailsView()) }
    )

    static let readerExperience = InspectorTool(
        id: "tab.title.reader_experience",
        icon: "sparkles",
        title: WenshuI18n.t("tab.title.reader_experience"),
        view: { AnyView(ReaderExperienceView()) }
    )

    static let plotThread = InspectorTool(
        id: "tab.title.plot_thread",
        icon: "arrow.triangle.branch",
        title: WenshuI18n.t("tab.title.plot_thread"),
        view: { AnyView(PlotThreadView()) }
    )

    static let genreFit = InspectorTool(
        id: "tab.title.genre_fit",
        icon: "bookmark",
        title: WenshuI18n.t("tab.title.genre_fit"),
        view: { AnyView(GenreFitView()) }
    )

    static let emotionCurve = InspectorTool(
        id: "tab.title.emotion_curve",
        icon: "waveform.path.ecg",
        title: WenshuI18n.t("tab.title.emotion_curve"),
        view: { AnyView(EmotionCurveView()) }
    )

    static let characterRelationships = InspectorTool(
        id: "tab.title.character_relationships",
        icon: "person.2",
        title: WenshuI18n.t("tab.title.character_relationships"),
        view: { AnyView(CharacterRelationshipsView()) }
    )

    static let characterLifecycle = InspectorTool(
        id: "tab.title.character_lifecycle",
        icon: "clock",
        title: WenshuI18n.t("tab.title.character_lifecycle"),
        view: { AnyView(CharacterLifecycleView()) }
    )

    static let tagManager = InspectorTool(
        id: "tab.title.tag_manager",
        icon: "tag",
        title: WenshuI18n.t("tab.title.tag_manager"),
        view: { AnyView(TagManagerView()) }
    )

    static let ideaLibrary = InspectorTool(
        id: "tab.title.idea_library",
        icon: "lightbulb",
        title: WenshuI18n.t("tab.title.idea_library"),
        view: { AnyView(IdeaLibraryView()) }
    )

    static let bookSettingConstraints = InspectorTool(
        id: "tab.title.book_setting_constraints",
        icon: "book.closed",
        title: WenshuI18n.t("tab.title.book_setting_constraints"),
        view: { AnyView(BookSettingConstraintsView()) }
    )

    // v2.8a (boss 2026-09-28 OOB): bookmark tab for the
    // specializedTools pane. WSBookmark @Model + WSBookmarkRepository
    // (= SwiftData per AGENTS.md §11.4 phase 5 ticket 10b) are
    // already canonical; = this entry just wires the view into
    // the inspector catalog.
    static let bookmark = InspectorTool(
        id: "tab.title.bookmark",
        icon: "bookmark",
        title: WenshuI18n.t("tab.title.bookmark"),
        view: { AnyView(BookmarkView()) }
    )

    // v2.9a (boss 2026-09-28 OOB A3): BackgroundReview tab = the
    // manual surface for the v2.8c BackgroundReview agent surface.
    // BackgroundReviewOps.listPending / approve / reject (= @MainActor
    // enum 4 entry points) are already canonical; = this entry wires
    // the view into the inspector catalog (= the boss A3
    // 'manual surface 缺一半' fix).
    static let backgroundReview = InspectorTool(
        id: "tab.title.background_review",
        icon: "checkmark.circle.badge.questionmark",
        title: WenshuI18n.t("tab.title.background_review"),
        view: { AnyView(BackgroundReviewView()) }
    )

    /// All 14 tools in catalog order. Used by ticket 02
    /// `InspectorPage.tools` (= business layer routing) to return the
    /// 3 tools per page. Used by ticket 04 tests for catalog
    /// completeness assertions (= `count == 14` + unique IDs).
    static let allTools: [InspectorTool] = [
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
        InspectorCatalog.bookSettingConstraints,
        InspectorCatalog.bookmark,
        InspectorCatalog.backgroundReview
    ]
}