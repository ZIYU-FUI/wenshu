//
//  WorldSubSection.swift
//
//  World/ sub-section enum extracted from ImportDocumentTemplates.swift
//  (= §6.6 god-class split: 157 LOC of the WorldSubSection enum + its
//  doc comment moved out of the templates file). The 6 cases are the
//  canonical filenames for the world/ folder (= boss 2026-10-10 (see
//  OOB.md #2026-10-10) "标题就是这 6 份的标题" = filename = H2 title, no
//  aliases). All 6 are MANDATORY for every import (= the canonical
//  wenshu 6-H2 world structure; = a missing one gets the `[TODO:
//  需调研补齐]` placeholder).
//

import Foundation


/// (= boss 2026-10-10 (see OOB.md #2026-10-10)
/// 定不完整" feedback).
/// The world/ folder is
/// split into 6 separate
/// .md files (= one per
/// mandatory H2 section).
/// Each file = ONE
/// wenshu-canonical H2;
/// = future-novel LLM
/// constraint lookups can
/// target a single H2
/// without loading the
/// whole 6-H2 file; = the
/// user can edit one H2 in
/// isolation. The 6 cases
/// below ARE the canonical
/// filenames (= boss
/// mandated "标题就是这
/// 6 份的标题" = filename
/// = H2 title, no aliases).
/// All 6 are MANDATORY for
/// every import (= boss
/// "无论用户导入的世界观
/// 文件是什么, 这六个
/// 文件是必须的"); = a
/// missing one (= the LLM
/// didn't produce content
/// for it) gets the
/// `[TODO: 需调研补齐]`
/// placeholder (= the
/// canonical wenshu
/// "worldview is incomplete"
/// affordance).
enum WorldSubSection: String, CaseIterable, Sendable, Hashable, Codable {
    case core       = "核心设定"
    case geography  = "地理或位置"
    case system     = "体系或规则"
    case history    = "历史脉络"
    case relations  = "与其他元素的关系"
    case scenes     = "关键场景种子"

    /// Human-readable name (= the H2 title;
    /// = the on-disk filename stem; =
    /// matches `rawValue`).
    var displayName: String { rawValue }

    /// The on-disk filename (= no `.md`
    /// extension; = the basename only;
    /// = the orchestrator appends the
    /// `.md` extension at write time).
    /// Convention: filename = H2
    /// title, verbatim (= boss
    /// mandated; = the sidebar
    /// card title = the filename
    /// stem = the H2 title = the
    /// enum rawValue; = no
    /// translation, no aliasing).
    var filename: String { rawValue }

    /// The mini-skeleton for this
    /// sub-section (= a 1-H2
    /// markdown stub the LLM
    /// fills; = the canonical
    /// wenshu format for this
    /// specific section). All 6
    /// are MANDATORY.
    var skeleton: String {
        switch self {
        case .core:
            return Self.coreSkeleton
        case .geography:
            return Self.geographySkeleton
        case .system:
            return Self.systemSkeleton
        case .history:
            return Self.historySkeleton
        case .relations:
            return Self.relationsSkeleton
        case .scenes:
            return Self.scenesSkeleton
        }
    }

    // MARK: - 6 mandatory mini-skeletons

    /// 核心设定 — one-line
    /// "what is this element
    /// and why does it matter".
    private static let coreSkeleton = """
    ## 核心设定

    <一句话回答：这个世界观元素"是什么"和"为什么重要"；不超过 80 字>
    """

    /// 地理或位置 — terrain,
    /// climate, resources,
    /// dangers.
    private static let geographySkeleton = """
    ## 地理或位置

    <位置描述：地形 / 气候 / 资源 / 危险；不超过 200 字>

    [TODO: 地理 = 需调研: <具体未知的细节>]
    """

    /// 体系或规则 — magic /
    /// tech / social system.
    private static let systemSkeleton = """
    ## 体系或规则

    ### 能力

    <系统能做什么；列举 2-3 条>

    ### 成本与限制

    <使用这个系统的代价是什么；硬性"不允许"的规则是什么>

    ### 边界情况

    <做得太过火会发生什么>
    """

    /// 历史脉络 — origin →
    /// turning point → current
    /// state.
    private static let historySkeleton = """
    ## 历史脉络

    <起源 → 关键转折 → 当前状态；不超过 300 字>

    [TODO: 历史 = 需调研: <具体未知的细节>]
    """

    /// 与其他元素的关系 —
    /// cross-references to
    /// other world/ elements +
    /// characters/ + antagonists.
    private static let relationsSkeleton = """
    ## 与其他元素的关系

    - 引用: <世界观里其他元素 A>（= A 也在 world/ 目录下有对应 .md）
    - 引用: <角色 B>（= B 在 characters/ 目录下有对应 .md）
    - 反派: <敌对势力 C>
    """

    /// 关键场景种子 — 2-3
    /// possible scenes this
    /// element forces the
    /// protagonist into.
    private static let scenesSkeleton = """
    ## 关键场景种子

    <这个世界观元素会迫使主角面临什么样的场景？列出 2-3 个可能场景>
    """
}
