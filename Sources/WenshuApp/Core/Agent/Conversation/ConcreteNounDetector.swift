import Foundation

/// Heuristic detector for concrete proper nouns in a Chinese-language
/// user prompt. Used by the agent driver (= SystemPrompt.universal
/// Guidance 'agent_driver') to decide whether to force the LLM into
/// a `web_search` round-trip BEFORE composing its reply.
///
/// Why heuristic (= not LLM-judged):
/// The LLM's self-assessment of "do I know this noun?" is unreliable
/// (= over-confidence; = training data already covers most common
/// Chinese proper nouns; = the LLM answers confidently without
/// verifying). The mechanical rule (= "any concrete proper noun
/// triggers a search") sidesteps this bias and routes every
/// verifiable fact through a grounded round-trip.
///
/// What counts as a concrete noun:
///   - Professions / job titles: 入殓师 / 律师 / 厨师 / 程序员 /
///     殡葬师 / 律师 / 焊工 / ...
///   - Chinese cities / counties / regions / streets: 沧州 / 任丘 /
///     佛山 / 黄骅 / 北京 / 上海 / ...
///   - Historical periods / dynasties / named eras: 唐宋 / 民国 /
///     文革 / 贞观 / 康熙 / ...
///   - Named events: 义和团 / 五四 / 唐山大地震 / 辛亥革命 / ...
///   - Person names (= ambiguous in Chinese; = conservative match):
///     2-character or 3-character names appearing as a noun phrase
///     (= not a verb / adverb).
///   - Brand names / industry terms / techniques (= Latin-script
///     capitalization heuristic: Apple-style camelcase or all-caps
///     runs > 2 chars).
///
/// What does NOT count:
///   - Pronouns, particles, generic nouns (= 你 / 我 / 他 / 这件事 /
///     那个 / 好的 / 是 / 不 / ...)
///   - Time words (= 今天 / 昨天 / 去年 / 上周)
///   - Self-referential words (= 文枢 / wenshu / 我 / 老板)
///   - The exact token "老板" (= boss's preferred address in this
///     repo's narrative; = NOT a research target).
enum ConcreteNounDetector {

    /// Detect concrete proper nouns in the user prompt. Returns the
    /// matched noun phrases (= one per detected noun, in source order).
    ///
    /// Conservative match: false negatives are acceptable (= LLM may
    /// still decide to research a noun the detector missed); = false
    /// positives (= triggering a needless search) are tolerable
    /// because `web_search` is keyless / free. The detector is
    /// designed to err on the side of triggering the search.
    static func detect(in prompt: String) -> [String] {
        var hits: [String] = []
        var seen = Set<String>()

        func add(_ noun: String) {
            let trimmed = noun.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if seen.insert(trimmed).inserted {
                hits.append(trimmed)
            }
        }

        // 1. Profession / occupation dictionary match (= exact substring).
        for profession in professionDictionary {
            if prompt.contains(profession) {
                add(profession)
            }
        }

        // 2. Chinese place-name dictionary match (= exact substring).
        for place in placeDictionary {
            if prompt.contains(place) {
                add(place)
            }
        }

        // 3. Dynasty / historical-period dictionary match (= exact substring).
        for period in periodDictionary {
            if prompt.contains(period) {
                add(period)
            }
        }

        // 4. Named-event dictionary match (= exact substring).
        for event in eventDictionary {
            if prompt.contains(event) {
                add(event)
            }
        }

        // 5. CamelCase / ALLCAPS Latin-script brand-name heuristic
        // (= Apple / IBM / GitHub / NASA / ...).  Matches runs of
        // 3+ Latin letters where at least one uppercase letter
        // appears. Catches Latin-script brand / product / technique
        // names without maintaining a manual brand list.
        if let regex = try? NSRegularExpression(pattern: "\\b[A-Za-z]*[A-Z][A-Za-z0-9]*\\b") {
            let range = NSRange(prompt.startIndex..., in: prompt)
            for match in regex.matches(in: prompt, range: range) {
                if let r = Range(match.range, in: prompt) {
                    let token = String(prompt[r])
                    // Filter out single-uppercase-letter words (= "I",
                    // "A", initial letters). Filter out Chinese-pure
                    // matches (= regex shouldn't fire on CJK; = but be
                    // safe).
                    guard token.count >= 3 else { continue }
                    guard token.allSatisfy({ $0.isASCII }) else { continue }
                    add(token)
                }
            }
        }

        return hits
    }

    /// Build a system-prompt reminder that forces the LLM to call
    /// `web_search` for each detected noun BEFORE writing the reply.
    /// The reminder is structured (= a numbered checklist) so the LLM
    /// can follow it as a tool-use instruction (= not as a polite
    /// suggestion). Returns "" when the prompt has no detectable
    /// nouns (= the caller can skip injecting any reminder).
    static func reminderIfAny(in prompt: String) -> String {
        let nouns = detect(in: prompt)
        guard !nouns.isEmpty else { return "" }
        let list = nouns.enumerated()
            .map { idx, noun in "  \(idx + 1). \"\(noun)\"" }
            .joined(separator: "\n")
        return """
        [WENSHU AGENT DRIVER — mandatory tool trigger]

        The user's prompt contains the following concrete proper
        nouns that MUST be verified via `web_search` BEFORE you write
        your reply (= the LLM's training-data confidence is NOT a
        sufficient reason to skip; = the user is asking precisely
        because they don't know the grounded answer):

        \(list)

        CRITICAL EXECUTION RULE: do NOT write a prose acknowledgement
        first (= "好的, 我先调研一下..."). The very first blocks of
        your assistant turn MUST be the parallel `web_search` tool_use
        blocks (= one per noun above). Only AFTER all web_search
        results have landed and `reference_library.create`/`upsert`
        has persisted them, write the user-facing reply. The system
        below the agent-driver block expects tool_use as turn 1
        (= ConversationLoop's tool dispatch loop only fires on
        tool_use blocks in the first response; = a plain-text
        acknowledgement closes the turn without dispatching tools).

        TOOL FORMAT (= Anthropic Messages API tool_use block):
        Each tool call MUST be emitted as a separate
        `tool_use` content block in your response (= NOT as a markdown
        code block, NOT as a `function_calls` wrapper, NOT as a
        `<tool_call>` XML tag). The Anthropic API emits each tool call
        as a JSON object with `type: "tool_use"`, `id: "toolu_<random>"`,
        `name: "<tool_name>"`, `input: {<args>}`. The runtime reads
        these blocks directly off your response (= a markdown
        ```tool_call block will NOT be dispatched and the user will
        see no research results).

        Required tool shape:
          1. `web_search` per noun, all in PARALLEL within the SAME
             assistant turn, action="search", query=<the noun
             verbatim>, limit=10. Independent calls = no ordering.
             Each call is its own `tool_use` content block.
          2. After web_search results land, `reference_library.create`
             (= or `upsert` if same-title already exists) to persist
             a per-noun summary. Use layer="entities" for people /
             places / events / professions; layer="raw" for general
             research.
          3. THEN (= in the SAME assistant turn after the tool
             results) write the user-facing reply grounded in the
             search hits. If a search returned no usable hits, say so
             plainly — do NOT fabricate details about a specific
             profession / place / event.
        """
    }

    // MARK: - Heuristic dictionaries

    /// Conservative profession / occupation list. Add to this set as
    /// novel-writing users surface new professions (= the heuristic
    /// is conservative: missing a profession = LLM still answers,
    /// false-positive profession = harmless extra search round-trip).
    private static let professionDictionary: [String] = [
        // Funeral / death-care
        "入殓师", "殡葬师", "殡仪师", "防腐师", "墓地管理员",
        // Legal / financial
        "律师", "法官", "检察官", "公证员", "会计师", "审计师",
        "税务师", "资产评估师",
        // Healthcare
        "医生", "护士", "药剂师", "中医", "针灸师", "推拿师",
        "心理医生", "心理咨询师", "营养师",
        // Skilled trades
        "厨师", "焊工", "电工", "木工", "瓦工", "钳工",
        "水管工", "油漆工", "裁缝", "鞋匠",
        // Tech / data
        "程序员", "软件工程师", "前端工程师", "后端工程师",
        "算法工程师", "数据分析师", "数据科学家", "产品经理",
        "UI设计师", "UX设计师",
        // Education
        "教师", "幼师", "小学老师", "中学老师", "大学教授",
        "家教",
        // Arts / media
        "作家", "编剧", "导演", "演员", "配音演员", "摄影师",
        "画家", "雕塑家", "音乐家", "钢琴家", "指挥家",
        "记者", "编辑",
        // Service / hospitality
        "服务员", "酒店前台", "导游", "空乘", "出租车司机",
        // Domestic / home
        "月嫂", "保姆", "育儿嫂", "钟点工",
        // Agriculture / blue-collar
        "渔民", "农民", "牧民", "护林员",
        // Defense / public safety
        "军人", "警察", "消防员", "保安",
        // Religious / cultural
        "僧人", "道士", "阿訇", "牧师",
        // Office
        "秘书", "文员", "会计", "出纳", "人事专员",
        // Self-employed / modern
        "外卖员", "快递员", "网约车司机", "代驾",
    ]

    /// Chinese place-name dictionary. Conservative set; = covers the
    /// ~50 most common cities / counties that appear in novel prompts.
    private static let placeDictionary: [String] = [
        // 直辖市
        "北京", "上海", "天津", "重庆",
        // 省会 + 副省级
        "广州", "深圳", "南京", "杭州", "武汉", "成都", "西安",
        "郑州", "济南", "青岛", "大连", "沈阳", "长春", "哈尔滨",
        "石家庄", "太原", "呼和浩特", "兰州", "西宁", "乌鲁木齐",
        "南昌", "合肥", "福州", "厦门", "南宁", "海口", "贵阳",
        "昆明", "拉萨", "银川",
        // 中等城市 (= often appear in regional novel settings)
        "沧州", "任丘", "黄骅", "河间", "沧县",
        "佛山", "东莞", "中山", "珠海", "惠州",
        "苏州", "无锡", "常州", "南通", "扬州", "镇江", "徐州",
        "宁波", "温州", "绍兴", "嘉兴", "湖州", "金华", "台州",
        "泉州", "漳州", "莆田",
        "洛阳", "开封", "安阳", "许昌", "南阳",
        "咸阳", "宝鸡", "渭南", "汉中",
        "临沂", "淄博", "烟台", "潍坊", "济宁", "泰安",
        "唐山", "保定", "邯郸", "邢台", "廊坊", "承德",
        "大同", "运城", "临汾", "晋城",
        "鞍山", "抚顺", "本溪", "锦州", "营口",
        "齐齐哈尔", "大庆", "佳木斯",
        "九江", "赣州", "上饶", "宜春", "吉安",
        "芜湖", "蚌埠", "淮南", "马鞍山", "安庆",
        "南平", "龙岩", "宁德",
        "柳州", "桂林", "梧州", "北海",
        "三亚", "琼海",
        "遵义", "六盘水", "毕节",
        "曲靖", "玉溪", "大理", "丽江",
        // 港澳台
        "香港", "澳门", "台北",
    ]

    /// Historical period / dynasty dictionary. Substring match =
    /// "民国" fires on "民国时期" / "民国的故事" / "民国十年".
    private static let periodDictionary: [String] = [
        // 朝代
        "夏", "商", "周", "秦", "汉", "三国", "魏晋", "南北朝",
        "隋", "唐", "五代", "宋", "元", "明", "清",
        // 详细朝代
        "贞观", "开元", "天宝", "建隆", "靖康", "洪武", "永乐",
        "万历", "康熙", "雍正", "乾隆", "嘉庆", "道光", "咸丰",
        "光绪", "宣统",
        // 近代
        "清末", "晚清", "民国", "北洋", "五四", "北伐", "抗战",
        "解放", "文革", "改革开放",
        // 现代
        "九十年代", "千禧年", "二零零零年代", "十年代",
    ]

    /// Named-event dictionary (= political / historical events that
    /// often appear in novel prompts and are easily confused or
    /// mis-dated by training data).
    private static let eventDictionary: [String] = [
        // 近现代
        "义和团", "五四运动", "辛亥革命", "北伐战争", "抗日战争",
        "解放战争", "抗美援朝", "三年困难时期", "大跃进", "人民公社",
        "文化大革命", "上山下乡", "改革开放", "下岗潮", "入世",
        "汶川地震", "非典", "新冠",
        // 古代
        "安史之乱", "黄巾起义", "玄武门之变", "陈桥兵变",
        "靖康之变", "土木之变", "甲申国难",
        // 国际
        "第一次世界大战", "二战", "冷战", "海湾战争",
        "九一一", "金融危机", "苏联解体",
    ]
}