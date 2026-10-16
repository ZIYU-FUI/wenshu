//
//  WCIRPromptHelpers.swift
//
//  4 prompt builder helpers extracted from
//  WenshuConductorImportRouterHelpers.swift
//  (= §6.6 god-class split + discoverability: userPrompt +
//  rewriteModeBlock + jsonShape + contentSamePrompt moved out of
//  the WCIRHelpers namespace into this dedicated `enum
//  WCIRPromptHelpers`).
//
//  Why extracted (= §6.6 god-class split + discoverability): the
//  WCIRHelpers namespace is 1182 LOC = 1.97x the 600-LOC cap. The
//  4 prompt builder helpers are a single concern (= "build the
//  LLM prompt that asks the Wenshu to categorize + rewrite the
//  .md file"). Putting them in a dedicated file named after the
//  concern (= WCIRPromptHelpers.swift) lets the next reader find
//  the prompt logic by name.
//
//  The 4 funcs are static (= no instance state; = safe to call from
//  any context).
//

import Foundation

/// Namespace container for the prompt builder helpers. Wrapped
/// in an enum (= same pattern as A56's `enum ImportServiceDedup`
/// and A62's `enum ImportServiceCache`).
enum WCIRPromptHelpers {
    static func userPrompt(filePath: String, body: String, rewriteMode: ImportFileInput.RewriteMode = .consolidate) -> String {
        // Cap the body sent to the LLM (= the fix default Anthropic context window is
        // plenty for a classification + tag + title rewrite task; = 12,000
        // chars is more than enough for a 1-2 page markdown file's worth of
        // classification signal; = the LLM never needs the full text body to
        // make a routing decision; = the cap also keeps the cost low for a
        // 456-file batch).
        let trimmed = String(body.prefix(12_000))
        // (= boss 2026-10-09 (see OOB.md #2026-10-09) [archived-round] "三个问题" feedback): 1)
        // "小说草稿里的卡片还是显示 ID": = the previous prompt included the `filePath`
        // line (= the source path); = the LLM sometimes echoed the path as the
        // title (= a long string with `/` stripped →
        // "UsersanbaiqiangLibraryMob ileDocumentsiCloud~md..."); = the
        // filename = the LLM title = a path echo; = the sidebar card title was
        // unreadable. Fix: drop the filePath line from the prompt entirely (=
        // the body alone is enough for the LLM to find the canonical entity
        // name; = the filePath was the leak that turned into a filename). 2)
        // "世界观混入了大量本来放在资料库 里的资料" (= 124 items in world/, all folk-god / 五脊六兽 /
        // 三台星 / generic cosmic lore; = the LLM wrongly routed generic-world-
        // knowledge into world/). Fix: world/ is now the STRICT constitution-
        // level folder; = the default routing is referenceLibrary; = world/
        // requires explicit "in this novel" / "本小说独有" markers in the body; =
        // otherwise referenceLibrary. 3) "资料库多了一个 tag '十二地仙'": = the LLM was
        // leaking the target novel's name into the tag list (= a hard-rule
        // violation; = tags must come from the body content, NOT from the
        // novel context). Fix: explicit "no book name in tags" rule + the
        // "target novel" mention is now ONLY used as the routing signal; =
        // tags derive from the body.
        return """
        请阅读下面的 Markdown 资料，输出一行 JSON 描述如何整理它。

        ## 正文
        \(trimmed)

        ## 任务
        1) 重写一个**最短**的中文标题 (= 取文件表示
           的**最核心实体名字**, 不要前缀/后缀/说
           明; = 文件名只放**一个实体的名字**; = 不
           带 "档案"、"资料"、"研究"、"卷"、朝代、
           年份、章节号等修饰词; = 如果一个文件讲了
           多个实体, 选**最核心**那一个):
             - "太平广记卷一○○李寄斩蛇" → "李寄"
             - "门闩神民俗研究" → "门闩神"
             - "XX 朝代元 1290 狗案" → "狗"
             - "主角职业入殓师" → "入殓师"
        2) 写一句话的中文摘要
        3) 提取**最多 3 个**真实内容的标签（= 老板
           2026-10-09 [archived-round] "限制资料库文档的
           标签数量，要最有用的，只能有 3 个标
           签" 反馈; = **不要 5-8 个, 只能 1-3
           个**; = 仅从正文内容本身提取: 人物 /
           地点 / 年代 / 概念 / 品牌等真实信
           息; = **严禁**把小说名字、目标小
           说、用户身份、当前项目名等元信息
           塞进 tag; = 标签只能描述"这个文件
           讲的是什么内容"，不能描述"这个文
           件属于哪本书"; = **严格 3 个以内**;
           = 资料库 sidebar 的 tag facet 用
           户筛选用, 太多 tag = 难以导航)
        4) **destination 已经被用户选好**（= 老板
           2026-10-09 [archived-round] "强制让用户分开导
           入"指令）。你**不需要**判 断 destination
           — 用户在 sheet 里已经选了"导入到资料
           库"或"导入到书"；= 你**只负责**生成
           title / summary / tags。
        \(Self.rewriteModeBlock(rewriteMode))

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {\(Self.jsonShape(rewriteMode))}
        """
}

    static func rewriteModeBlock(_ mode: ImportFileInput.RewriteMode) -> String {
        switch mode {
        case .consolidate:
            return """
            5) **整理正文** (= consolidate 模式也要
               标准化 .ws 格式; = 老板 2026-10-09
               [archived-round] "重写后格式不统一" 反馈;
               = 现在的 consolidate 模式只是
               "原样落地" 没有整理, 老板要统一
               格式, 不只是 searchAndRewrite 整
               理):
               - 输出**整理后的 .ws 格式正文**到
                 `rewrittenBody` 字段 (= 即使你没
                 有搜索, 也要把原文按 .ws 格式
                 标准化; = 不写 = 字段留空 = 走
                 "原样落地" fallback).
            """
        case .searchAndRewrite:
            return """
            5) **整理新正文**:
               - 你**可以**调用 `web_search` 工具查
                 找该实体的标准资料 (= action=search,
                 query=<实体名>，limit=5); = 也可以不
                 调用（= 如果你从原文已经能整理出完
                 整 .ws 格式正文).
               - 把搜索结果 + 原文**整理**成 .ws 格
                 式的最终正文 (= 不要扩写或加虚构内
                 容; = 搜索只是补全原文里不完整的部
                 分; = 整理 = 标准化 .ws 格式).
               - .ws 资料库正文格式 (= 老板 2026-10-09
                 [archived-round] "不要参考 MD 的格式，而
                 是盘点文枢的功能，做出文枢
                 的头部格式" directive; = 抛弃
                 老板旧 MD 的 `类型/状态/核心
                 信息/详细描述` 模板; = **从头**
                 设计 = 基于文枢 `Reference`
                 struct 字段):
                 ```
                 # <实体名>

                 实体类型: <character | location | event | concept | artifact | organization | era | work | other>
                 标签: <tag1>; <tag2>; <tag3>
                 摘要: <一句话中文摘要>

                 <自由 markdown 正文 — 内容随你; 不
                  要分 "核心信息 / 详细描述"; 不
                  要 frontmatter 之外的字段名>
                 ```
                 - 头信息**必须**包含 3 行 (= 老板
                   2026-10-09 [archived-round] "头部信息
                   必须包含哪些"):
                   1. `实体类型: <值>` (= 必填; =
                      .ws `Reference.entityType`;
                      = 9 个枚举值; = 没填 = 后
                      端无法分类 = 卡片 facet
                      失灵)
                   2. `标签: <值1>; <值2>; <值3>`
                      (= 必填; = .ws `Reference.tags`;
                      = ≤ 3 个; = `; ` 分隔; = 资料
                      库 sidebar tag facet 唯一
                      的导航源)
                   3. `摘要: <值>` (= 必填; = .ws
                      `Reference.summary`; = 一句
                      话; = 卡片副标题)
                 - 头信息**可选**:
                   - `出处: <值>` (= .ws `Reference.source`;
                     = 资料库 = 资料来源 (e.g.
                     "《太平广记》卷一○○"))
                   - `链接: <值>` (= .ws `Reference.url`;
                     = 资料库 = web URL)
                 - **严禁**写 (= 这些字段文枢已经
                   用别的机制管理, 不写在 .md body):
                   - `类型: ...` / `状态: ...` (= 没
                     意义; = 文枢不维护 status 字
                     段; = `状态: 已建` 这种字段
                     是冗余的)
                   - `核心信息:` / `详细描述:` (= 不
                     需要分节; = 自由写)
                   - `反链:` / `tags:` / `标签:` 在正
                     文 = 跟 metadata 重复
                   - `上次更新: ...` / `created: ...` /
                     `modified: ...` (= entities.json
                     有 `createdAt` / `updatedAt`)
                   - `../` / `[[...]]` (= Obsidian
                     link; = 关系走 .ws 关系链
                     字段, 不在 .md 里)
                   - `<!-- ... -->` (= Obsidian plugin
                     痕迹)
               - .ws 书目录正文格式: 直接 `<实体
                 名>相关正文` (无 frontmatter; =
                 老板原 .md 格式).
               - **保留** (= 重要结构): `# 标题` /
                 `## 子标题` / `### 子标题` /
                 `**加粗**: value` / bullet `-` / 段落.
               - 把整理后的正文放 JSON 的
                 `rewrittenBody` 字段 (= 没有整理
                 = 字段留空字符串 = 走"原样落地"
                 fallback)。
            """
        case .reorganize:
            // (= boss 2026-10-10 (see OOB.md #2026-10-10) 格式和样式" 反馈). The LLM's job is to
            // **actively reorganize** the source A into the template B's
            // structure (= world = 6 H2, characters = 4 H2, etc.). No
            // tools (= the LLM has the source body).
            return """
            5) **重组正文 (A → B)**:
               - 输出**主索引文件**到
                 `rewrittenBody` 字段
                 (= [archived-round]: world/
                 模板 = 1 主索引 +
                 6 必填子文件 + N 自
                 定义子文件; = 主索引
                 含 metadata + 6 必填
                 子文件路径引用):
                 - **必须**按 B 模板的
                   元数据头 (= # 标题
                   + 实体类型 + 标签
                   + 摘要)
                 - 然后列出 6 份必填
                   子文件路径引用:
                     - [`核心设定.md`](核心设定.md)
                     - [`地理或位置.md`](地理或位置.md)
                     - [`体系或规则.md`](体系或规则.md)
                     - [`历史脉络.md`](历史脉络.md)
                     - [`与其他元素的关系.md`](与其他元素的关系.md)
                     - [`关键场景种子.md`](关键场景种子.md)
                 - 主体 body 可以放 1 段
                   简短概述 (= LLM 用
                   一段话总结这个世界
                   观元素是什么 = wenshu
                   主索引风格)
                 - **不要**在主索引 body
                   里填 6 必填的 H2
                   内容 (= 内容进
                   extraFiles 子文件
                   里; = 主索引只引
                   用不重复)
                 - 角色/大纲等 模板
                   没有 6-份拆分 (= 只
                   是 1 大文件 9 H2);
                   = 保持原状
                 - 章节/草稿/构思
                   = 自由 markdown
                 - 空的 H2 写
                   `[TODO: 需调研补齐]`
                 - **强制去反链** (= 老
                   板 2026-10-10
                   "强制去反链" 反馈;
                   = 全部 `[[xxx]]`
                   形式去掉; = 嵌段
                   中间/图片/独立
                   行)
                 - **强制去版本记录**
                   (= 老板 2026-10-10
                   "强制去版本记
                   录" 反馈; = 上次
                   更新/修改记录/
                   Created/Modified
                   等 13 个 prefix
                   全部去掉; = 不
                   写到 body)
                 - **不要**扩写或虚构
                   (= 老板 "不要扩写
                   或加虚构内容")
               - 输出**6 必填 + N 自
                 定义子文件**到
                 `extraFiles` 数组
                 (= [archived-round] 老板
                 原话 "6 份必填,
                 其它不在 6 份
                 里的, 可以自
                 定义名字, 如果
                 归属于世界观, 那
                 就放在世界观里.
                 不要备注标题的文
                 档. 其它不在六份
                 里的, 可以单独
                 写文档, 约等于
                 备注"):
                 - **6 必填 (required:
                   true)** (= wenshu
                   canonical; = 文
                   件名 = H2 标题
                   verbatim; = 这
                   6 个 world/ 子文
                   件必须存在):
                   1. `核心设定.md`
                      (= 1 句话
                      "是什么
                      和为
                      什么
                      重
                      要";
                      ≤80 字)
                   2. `地理或位置.md`
                      (= 地形/
                      气候/
                      资源/
                      危险;
                      ≤200
                      字)
                   3. `体系或规则.md`
                      (= 能力/
                      成本
                      限
                      制/
                      边界
                      情
                      况;
                      2-3 条
                      各)
                   4. `历史脉络.md`
                      (= 起源
                      →转
                      折
                      →当
                      前;
                      ≤300
                      字)
                   5. `与其他元素的关系.md`
                      (= 引
                      用/
                      反
                      派/
                      盟
                      友列
                      表)
                   6. `关键场景种子.md`
                      (= 主角
                      会
                      面
                      临
                      的
                      场
                      景;
                      2-3
                      个)
                 - **N 自定义 (required:
                   false)** (= 老
                   板 "其它不在
                   6 份里的, 可
                   以自定义名
                   字"; = 约等
                   于备注; = 文件
                   名 = LLM 决
                   定; = e.g.
                   "十二生肖原
                   型" /
                   "元炁体系" /
                   "时间线" 等):
                   1. LLM 决定 title
                      (= 中文; =
                      ≤30 字; = 不
                      含路径分隔
                      符)
                   2. LLM 决定 body
                      (= 完整内容)
                 - **绝对不要写 `备注.md`
                   或 `备注` 标题** (= 老板
                   "不要备注标题的文
                   档"; = 旧的 wenshu
                   7th H2 废弃; = 如
                   果 LLM 习惯性想
                   写, 删掉; = 归类
                   进自定义)
                 - 每个 element 字段:
                   1. `folder` (= 6 必填
                      全部 = world;
                      = 自定义看归
                      属: 世界观 =
                      world, 角色
                      资料 =
                      characters,
                      = etc.)
                   2. `title` (= 必填
                      = H2 标题
                      verbatim;
                      = 自定义
                      = LLM 决
                      定; = 不能
                      含 `/` 或
                      `:`)
                   3. `body` (= 完整
                      markdown; =
                      `\\n` 表
                      示换行)
                   4. `required` (= 必填
                      = true; =
                      自定义 =
                      false; =
                      编排器
                      用这个
                      区分
                      6 必
                      填
                      vs
                      N 自
                      定
                      义)
                 - **6 必填 + 5 自定义
                   上限 = 11 element**
                   (= 6 必填优先; =
                   超出的丢弃;
                   = 防 LLM 过
                   度拆)
                 - **空数组 OK** (= 如
                   果 A 完全符合
                   6 必填, 没有任
                   何自定义内容;
                   = 主索引就够了)
                 - **不要把 A 里已经
                   重组进
                   rewrittenBody
                   的内容再写到
                   extraFiles**
                   (= dedup; = 6
                   必填都是新内
                   容, 不会重复;
                   = 自定义要避
                   免跟主索引重叠)
            """
    }
}

    static func jsonShape(_ mode: ImportFileInput.RewriteMode) -> String {
        switch mode {
        case .consolidate:
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...]\""
        case .searchAndRewrite:
            // CRITICAL: `rewrittenBody` must be a single-line JSON string (= the string-
            // value `\\n` is the JSON escape for newline; = the LLM should
            // NOT emit a literal newline inside the string-value; = the
            // previous prompt said "可以包含换行 \\\\n" which the LLM took as
            // permission to insert a real newline; = the JSON parser then
            // bailed; = the boss 2026-10-09 (see OOB.md #2026-10-09)
            // fallback title). Fix: tell the LLM to use JSON-escaped `\n`
            // (= \\n) only; = the orchestrator un-escapes after parsing.
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...],\"rewrittenBody\":\"<整理后的 .ws 格式正文; 用 \\\\n 表示换行, 不要在字符串值里写真实换行>\""
        case .reorganize:
            // + [archived-round] (= boss 2026-10-10 (see OOB.md #2026-10-10) 其它自定义" 需求). The LLM
            // returns BOTH `rewrittenBody` (= the main index file body; =
            // [archived-round] = metadata + 6-必填子文件路径 引用) AND `extraFiles` (= 6 必填
            // + N 自定义 子文件). The `required` field tells the orchestrator
            // which are the 6 mandatory (= filename = H2 title, verbatim)
            // vs the N custom ones (= LLM-chosen title).
            return "\"title\":\"<中文标题>\",\"summary\":\"<一句话中文摘要>\",\"tags\":[\"<tag1>\",\"<tag2>\",...],\"rewrittenBody\":\"<主索引文件 body: 元数据 + 6 必填子文件路径引用; 用 \\\\n 表示换行, 不要写真实换行>\",\"extraFiles\":[{\"folder\":\"<world|characters|outlines|chapters|drafts|ideas>\",\"title\":\"<必填=H2 标题 verbatim, 自定义=LLM 决定>\",\"body\":\"<子文件完整 markdown; 用 \\\\n 表示换行>\",\"required\":<true for 6 必填, false for 自定义>}]"
    }
}

    static func contentSamePrompt(
        sourceBody: String,
        existingBody: String,
        sourceTitle: String
    ) -> String {
        // Cap each body to keep the prompt manageable (= the LLM doesn't need the full
        // 10k-char bodies to detect sameness; = 4000 chars per side = 8000
        // total = well under the 4096-token budget).
        let sBody = String(sourceBody.prefix(4000))
        let eBody = String(existingBody.prefix(4000))
        return """
        你要判断两段 markdown 正文是否讲**同一个内容**。标题都是「\(sourceTitle)」。

        ## 新文件 (= 用户刚刚选择的)
        \(sBody)

        ## 已有文件 (= 已经存在于目标文件夹)
        \(eBody)

        ## 任务
        1) 判断两段正文是否讲同一件事 (= 同样的人物 / 设定 / 故事)
        2) 给一个 0-1 的 confidence (= 1 = 完全相同, 0 = 完全无关)
        3) 写一句话中文 reasoning (= 给用户看的简短解释)

        ## 输出格式
        严格一行 JSON，不要任何其他文字、解释或 markdown 代码块：
        {"isContentSame":<true|false>,"confidence":<0-1>,"reasoning":"<一句话中文解释>"}
        """
}


}
