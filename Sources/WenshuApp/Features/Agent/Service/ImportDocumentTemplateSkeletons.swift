//
//  ImportDocumentTemplateSkeletons.swift
//
//  Skeleton markdown constants extracted from ImportDocumentTemplates.swift
//  (= §6.6 god-class split: 6 `private static let <x>Skeleton` consts +
//  their /// doc comments + // MARK section markers = 440 LOC of pure
//  data + 6 large doc comments moved out of the templates file). Each
//  constant is a markdown skeleton (= the LLM fills the body of each
//  section; = the section headings are the "wenshu signature" that makes
//  the document recognizable as a wenshu-generated doc).
//
//  The 6 constants here are referenced by `ImportDocumentTemplate.skeleton`
//  (= the `var skeleton: String { switch self { ... } }` per-case
//  switch in the original file). The original file's switch now uses
//  `Self.worldSkeleton` etc. (= the same names; = the extraction
//  moved the bodies, not the names).
//

import Foundation

    // MARK: - World template

    /// 世界观 (world/) template.
    /// A 世界观 document captures
    /// ONE element of the story's
    /// world (= a location, a
    /// magic system, a race, a
    /// historical event, a
    /// political faction; = NOT
    /// the entire world bible; =
    /// each world/ file is one
    /// element; = the union of all
    /// world/ files is the world
    /// bible). Research source:
    /// jerryjenkins.com character
    /// profile + novelists.cn
    /// worldbuilding template +
    /// adazing.com worldbuilding.
    ///
    /// (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// feedback). The world/
    /// folder now has 6
    /// mandatory .md files
    /// (= one per H2); = this
    /// "main file" is the
    /// INDEX (= metadata +
    /// 6 sub-file references).
    /// The 6 sub-files are
    /// written via the
    /// `extraFiles` pipeline
    /// (= same path as
    /// [archived-round]'s "split out
    /// non-B content" feature;
    /// = the LLM populates
    /// each sub-section
    /// independently).

/// Namespace container for the 6 template-skeleton constants.
/// (= the markdown body the LLM fills for each folder; = see
/// ImportDocumentTemplate.skeleton for the per-case switch
/// that selects which skeleton to use.)
enum ImportDocumentTemplateSkeletons {
    static let worldSkeleton = """
    # <世界观元素名>

    实体类型: <location | concept | event | era | organization | artifact | other>
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个元素在故事中的核心作用>

    ## 6 份必填子文档

    (= [archived-round] 拆分后, 世界观 = 1 主索引 + 6 份独立 .md
    在 world/ 同目录下):

    - [`核心设定.md`](核心设定.md) — 这个元素"是什么"和"为什么重要"
    - [`地理或位置.md`](地理或位置.md) — 地形 / 气候 / 资源 / 危险
    - [`体系或规则.md`](体系或规则.md) — 能力 / 成本与限制 / 边界情况
    - [`历史脉络.md`](历史脉络.md) — 起源 → 关键转折 → 当前状态
    - [`与其他元素的关系.md`](与其他元素的关系.md) — 引用 / 反派 / 盟友
    - [`关键场景种子.md`](关键场景种子.md) — 主角会面临的场景
    """

    // MARK: - Characters template

    /// 角色 (characters/) template.
    /// A 角色 document captures
    /// ONE character's full
    /// profile. Research source:
    /// jerryjenkins.com character
    /// profile + reddit
    /// r/writing character profile
    /// thread + dramatica discussion.
    /// 8 mandatory sections (= the
    /// most detailed template
    /// because character motivation
    /// drives the plot).
    static let charactersSkeleton = """
    # <角色名>

    实体类型: character
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个角色在故事中的位置>

    ## 基本信息

    - 姓名: <本名 / 化名 / 称号>
    - 年龄: <数字或年龄区间>
    - 性别: <男 / 女 / 其他>
    - 身份: <职业 / 地位 / 阵营>

    ## 外在形象

    <身高 / 体格 / 穿着 / 标志性特征 / 习惯性动作；不超过 200 字>

    [TODO: 外在 = 需调研: <具体未知的细节>]

    ## 内在性格

    ### 核心性格（一两个词）

    <例如：谨慎 / 冲动 / 矛盾>

    ### 优点

    <2-3 条>

    ### 缺点与盲点

    <2-3 条；这些是角色的戏剧张力来源>

    ## 动机与目标

    ### 表面目标（角色自己声称的）

    <角色口头说自己要做什么>

    ### 深层动机（角色不愿承认的）

    <真正驱动角色的是什么；通常与恐惧或过去相关>

    [TODO: 动机 = 需调研: <具体未知的细节>]

    ## 恐惧与弱点

    <角色最怕什么；什么会让角色崩溃或做出错误决定>

    ## 背景与过去

    <关键经历；不超过 300 字；这些经历塑造了角色的核心>

    ## 与其他角色的关系

    - 盟友: <角色 A>：<关系描述>
    - 敌对: <角色 B>：<关系描述>
    - 暧昧/师徒/家人: <角色 C>：<关系描述>

    ## 角色弧线

    <故事开始时这个角色是什么样 → 故事结束时变成什么样；不超过 200 字>

    ## 关键场景种子

    <这个角色会迫使主角面临什么样的场景？列出 2-3 个可能场景>

    ## 备注

    <其他元数据、来源、研究笔记；可省略>
    """

    // MARK: - Outlines template

    /// 大纲 (outlines/) template.
    /// An outlines document
    /// captures a story-level OR
    /// act-level outline (= the
    /// chapter-by-chapter outline
    /// lives in chapters/; = the
    /// outlines/ is the high-level
    /// structure = acts, blocks,
    /// key turns). Research source:
    /// scyn.app 27-chapter outline +
    /// litmemo.com novel outline +
    /// chapter.pub novel outline.
    /// 5 mandatory sections.
    static let outlinesSkeleton = """
    # <大纲名>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个大纲的范围（一卷 / 一幕 / 全书）>

    ## 故事核心问题

    <这个故事要回答的戏剧性问题是什么？不超过 50 字>

    ## 三幕骨架

    ### 第一幕（Setup，约 25%）

    - **Hook（0-5%）**: <故事开始时主角的"普通世界"是什么样>
    - **Inciting Incident（约 10%）**: <打破平衡、主角无法再回避的事件>
    - **First Plot Point（约 25%）**: <主角主动选择进入旅程；不可回头的门槛>

    ### 第二幕（Confrontation，约 50%）

    - **Midpoint（约 50%）**: <主角对冲突的理解发生反转；中点翻转>
    - **Second Plot Point（约 75%）**: <最低点；主角失去一切旧计划>

    ### 第三幕（Resolution，约 25%）

    - **Climax（约 90%）**: <主角面对核心敌人的最终对决>
    - **Resolution（95-100%）**: <新平衡；与 Hook 形成对照>

    [TODO: 大纲 = 需调研: <具体未知的细节>]

    ## 关键转折

    <3-5 个让读者"没想到"的转折点；每个转折点 = 改变主角理解的事件>

    ## 主题

    <这个故事要表达的核心命题；不超过 100 字>

    ## 备注

    <字数目标 / 题材 / 受众 / 风格参考；可省略>
    """

    // MARK: - Chapters template

    /// 章节 (chapters/) template.
    /// A chapters document captures
    /// a SINGLE chapter (= one
    /// chapter per file; = the
    /// chapter-by-chapter outline
    /// row lives in outlines/ as
    /// the master plan). Research
    /// source: litmemo.com chapter
    /// planner + chapter.pub
    /// chapter-by-chapter template.
    /// 5 mandatory sections.
    static let chaptersSkeleton = """
    # 第 <N> 章 <章节标题>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述本章发生什么>

    ## 章节目标

    <本章要让读者知道/感受到什么？不超过 50 字>

    ## 主要事件

    <2-3 句：发生了什么；本章结束时与开始时有什么不同>

    ## 出场角色

    - <角色 A>（= A 在 characters/ 目录下有对应 .md）
    - <角色 B>
    - <新引入角色 C>[TODO: 角色 C = 需调研: <这个角色还没有正式 profile>]

    ## 伏笔

    - **埋设**: <本章埋下一个细节，指向未来章节>
    - **兑现**: <本章兑现之前的某个伏笔，源自第 X 章>

    ## 字数目标

    <计划字数 / 实际字数 / 状态：草稿 / 定稿>

    ---

    <章节正文；按时间顺序的叙述；如果原文有正文，请尽量保留原内容>

    """

    // MARK: - Drafts template

    /// 草稿 (drafts/) template.
    /// (= boss
    /// 2026-10-10 "drafts/
    /// 草稿和正文模版
    /// 一至" + "Agent
    /// 写的正文一律
    /// 先进草稿. 由
    /// 用户确认后进
    /// 入正文" + "
    /// 正式章节的
    /// 内容，除了导
    /// 入，草稿确认
    /// 后的，Agent 不
    /// 可以在里面新
    /// 增内容"
    /// directive). The
    /// drafts template
    /// is now structurally
    /// identical to the
    /// chapters template
    /// (= the only
    /// difference between
    /// a draft and a
    /// chapter is the
    /// folder it lives
    /// in; = a draft
    /// becomes a chapter
    /// when the user
    /// right-clicks the
    /// card and picks
    /// "确定为正式章节"
    /// (= the
    /// `drafts/chapters`
    /// folder becomes
    /// `chapters/`; = the
    /// status flips from
    /// 草稿 to 定稿)).
    /// Both templates
    /// share the same
    /// section structure
    /// (= 章节目标 /
    /// 主要事件 / 出场
    /// 角色 / 伏笔 / 字
    /// 数目标 + 正文);
    /// = the user can
    /// move a file from
    /// drafts/ to
    /// chapters/ without
    /// any rewriting
    /// (= the file is
    /// already in the
    /// correct shape; =
    /// only the
    /// folder + status
    /// change). The
    /// product rule
    /// "Agent 写的正
    /// 文一律先进草
    /// 稿" means the
    /// LLM router MUST
    /// write to drafts/
    /// (= not chapters/;
    /// = this is enforced
    /// in a separate
    /// future commit;
    /// = the template is
    /// the structural
    /// foundation).
    static let draftsSkeleton = """
    # 第 <N> 章 <章节标题>

    实体类型: event
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述本章发生什么>

    ## 章节目标

    <本章要让读者知道/感受到什么？不超过 50 字>

    ## 主要事件

    <2-3 句：发生了什么；本章结束时与开始时有什么不同>

    ## 出场角色

    - <角色 A>（= A 在 characters/ 目录下有对应 .md）
    - <角色 B>
    - <新引入角色 C>[TODO: 角色 C = 需调研: <这个角色还没有正式 profile>]

    ## 伏笔

    - **埋设**: <本章埋下一个细节，指向未来章节>
    - **兑现**: <本章兑现之前的某个伏笔，源自第 X 章>

    ## 字数目标

    <计划字数 / 实际字数 / 状态：草稿>

    ---

    <章节正文；按时间顺序的叙述；如果原文有正文，请尽量保留原内容>

    """

    // MARK: - Ideas template

    /// 构思 (ideas/) template.
    /// (= boss
    /// 2026-10-10 "需
    /// 要加一个目录
    /// ，放你现在的
    /// 草稿，类似
    /// 构思" + "新
    /// 文件夹构思
    /// ，是一些零
    /// 散的设定，
    /// 和未来的
    /// 一些想法，
    /// 不是草稿"
    /// directive). The
    /// ideas/ folder is
    /// a scratchpad for
    /// loose world-
    /// building fragments
    /// and future-story
    /// ideas (= NOT a
    /// draft; = the
    /// distinction
    /// between `ideas`
    /// and `drafts` is:
    /// `ideas` = "things
    /// that MIGHT become
    /// characters /
    /// locations /
    /// events / chapters
    /// later, but I
    /// don't know what
    /// yet"; = `drafts` =
    /// "this IS a chapter
    /// but I haven't
    /// finalized it yet";
    /// = `chapters` = "I
    /// confirmed this is
    /// the final text").
    /// The ideas template
    /// is the lightest
    /// template (= 4
    /// sections; = no
    /// chapter body; = no
    /// character profile;
    /// = just a quick
    /// capture). The
    /// `可能成为` section
    /// (= "what it might
    /// become") is the
    /// key differentiator
    /// (= forces the
    /// user to commit to
    /// a destination when
    /// they promote the
    /// idea to a folder;
    /// = the user can
    /// also leave it
    /// blank if the
    /// idea is too
    /// unformed).
    static let ideasSkeleton = """
    # <想法名>

    实体类型: <character | location | event | concept | artifact | organization | era | work | other>
    标签: <tag1>; <tag2>; <tag3>
    摘要: <一句话中文摘要，描述这个想法的核心>

    ## 灵感来源

    <这个想法是因为什么而产生？读了什么 / 看了什么 / 想到了什么？不超过 100 字>

    ## 当前形态

    <现在这个想法是什么状态？一段话 / 几个关键词 / 一个场景？可省略>

    [TODO: 当前形态 = 需调研: <这个想法还不够具体，需要更深入的研究或思考>]

    ## 可能成为

    <这个想法未来可能成为什么？character / location | event | chapter | outline | 世界观的一个子项？可省略>

    ## 备注

    <其他元数据、来源、研究笔记；可省略>

    """


}
