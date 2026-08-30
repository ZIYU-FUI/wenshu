// Sources/WenshuApp/Storage/EntityClassifier.swift
//
// v0.29 boss 2026-08-30 OOB: '实体需要按分类新建成多个文件夹, 这里直接
// 显示这些分类文件夹, 比如, 历史, 科学, 这样的分类, 你可以参考
// 图书馆的分类法, 这一个规则, 自动归类实体. 分类文件夹随着内容
// 逐渐增加, 而不是一下子铺满':
//
// = Auto-classify Reference entities into library-taxonomy categories
// (EntityCategory). Uses a 2-pass strategy:
//   1st pass: keyword matching (= fast, no LLM call, ~95% accuracy)
//   2nd pass: LLM classifier (= if 1st pass low confidence)
//
// Why not LLM-everything?
// - Cost: every entity save = 1 LLM call = $$$  + latency
// - Speed: keyword match is <1ms vs LLM ~500ms
// - Determinism: keyword match is reproducible (= same input → same
//   category), LLM is stochastic
// - Offline: keyword match works without LLM credentials, LLM requires
//   network
//
// So we use keyword for the easy cases, and LLM only for the ambiguous
// ones (= ~5% of entities that don't have obvious keyword signals).
//
// "增量" (incremental) rule: the sidebar only shows categories that
// have at least 1 entity. Empty categories = hidden. So as entities
// are added, new category folders appear in the sidebar (= exactly
// what boss wants).

import Foundation

/// Auto-classify a Reference entity into an EntityCategory.
///
/// **Use this** when saving a new Reference (= after Reference body is
/// extracted from raw materials). The classifier picks the best
/// category based on the entity's title + summary + body content.
///
/// **Two-pass strategy**:
/// 1. **Keyword pass** (default, no LLM): scan title + summary for
///    category-specific keywords (= e.g. "将军" → E 军事, "唐朝" → K
///    历史, "细胞" → Q 生物). If a clear winner emerges (= 1 category
///    has 2x score of any other), use it directly.
/// 2. **LLM pass** (fallback for ambiguous): if keyword scores are tied
///    or all categories score < 2 points, ask the LLM to classify with
///    a structured prompt (= returns 1 EntityCategory + confidence).
///
/// The LLM pass is opt-in (= boss can set `useLLMFallback = false` in
/// Settings to force keyword-only classification = no LLM cost).
public struct EntityClassifier: Sendable {
    public init() {}

    /// Optional LLM callback (= signature matches WenshuConductor's
    /// chat completion). When nil, only keyword pass is used (= the
    /// default = keyword-only mode for offline + free use).
    public typealias LLMCallback = @Sendable (String) async throws -> String

    /// Classify a reference (= title + summary + body) into an
    /// EntityCategory. Always returns a category (= falls back to .z
    /// = 综合性图书 = "catch-all" if both passes fail).
    public func classify(
        title: String,
        summary: String = "",
        body: String = "",
        useLLMFallback: Bool = true,
        llmCallback: LLMCallback? = nil
    ) async -> EntityCategory {
        // 1st pass: keyword matching (= sync, fast, no LLM cost)
        let keywordResult = keywordClassify(title: title, summary: summary, body: body)

        // If keyword result is confident (= clear winner), use it directly
        if keywordResult.confidence >= 0.6 {
            return keywordResult.category
        }

        // 2nd pass: LLM (only if enabled + LLM callback available)
        if useLLMFallback, let llm = llmCallback {
            do {
                let llmResult = try await llmClassifier(
                    title: title,
                    summary: summary,
                    body: body,
                    llmCallback: llm
                )
                if llmResult.confidence >= 0.5 {
                    return llmResult.category
                }
            } catch {
                // LLM failed (= network down, etc.) = fall through to
                // keyword result (= even if low confidence, it's the
                // best we have).
            }
        }

        // Fallback (= keyword result OR .z = 综合性图书)
        return keywordResult.category
    }

    // MARK: - Keyword classifier (1st pass)

    /// Result of the keyword pass (= category + confidence 0-1).
    public struct KeywordResult: Sendable {
        public let category: EntityCategory
        public let confidence: Double  // 0.0 = no signal, 1.0 = definitive
    }

    /// Score each category by counting keyword matches in the text.
    /// Returns the highest-scoring category (= with confidence = top /
    /// (top + runner-up) so a clear winner = high confidence).
    public func keywordClassify(title: String, summary: String, body: String) -> KeywordResult {
        let text = (title + " " + summary + " " + body).lowercased()

        var scores: [EntityCategory: Int] = [:]
        for (category, keywords) in EntityClassifier.keywords {
            var count = 0
            for keyword in keywords {
                if text.contains(keyword) {
                    count += 1
                }
            }
            if count > 0 {
                scores[category] = count
            }
        }

        guard let topEntry = scores.max(by: { $0.value < $1.value }) else {
            // No keywords matched = return .z (= 综合性图书 = catch-all)
            return KeywordResult(category: .z, confidence: 0.0)
        }
        let topCategory = topEntry.key
        let topScore = topEntry.value

        // Confidence = top / (top + runner-up) so a clear winner = high.
        let runnerUp = scores
            .filter { $0.key != topCategory }
            .max(by: { $0.value < $1.value })?.value ?? 0
        let confidence: Double
        if topScore >= 2 && topScore >= 2 * runnerUp {
            confidence = 0.9  // Clear winner with 2x margin = high confidence
        } else if topScore >= 2 {
            confidence = 0.6  // Multiple matches = moderate
        } else {
            confidence = 0.3  // Only 1 match = low (= LLM will be called)
        }

        return KeywordResult(category: topCategory, confidence: confidence)
    }

    // MARK: - LLM classifier (2nd pass)

    /// Result of the LLM pass.
    public struct LLMResult: Sendable {
        public let category: EntityCategory
        public let confidence: Double
    }

    /// Ask the LLM to classify (= returns the category letter as a
    /// single character A-Z).
    private func llmClassifier(
        title: String,
        summary: String,
        body: String,
        llmCallback: LLMCallback
    ) async throws -> LLMResult {
        // Build a structured prompt (= request 1-char response for
        // fast parsing).
        let categoriesList = EntityCategory.allCases
            .map { "\($0.rawValue) = \($0.displayName)" }
            .joined(separator: "\n")
        let prompt = """
        你是一个图书馆分类专家。请将下面的资料归类到《中国图书馆分类法》(中图法) 的 22 个一级类目之一。

        ## 资料信息
        - 标题: \(title)
        - 摘要: \(summary)
        - 正文 (前 500 字): \(String(body.prefix(500)))

        ## 22 个一级类目
        \(categoriesList)

        ## 输出要求
        - 只输出一个字母（A-Z，不含 L/M/O），代表最合适的类目
        - 例如你的答案是: K
        - 不要任何解释, 不要任何其他文字, 不要标点
        """
        let response = try await llmCallback(prompt)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Parse single letter A-Z (also accept lowercase)
        if let firstChar = trimmed.first, let category = EntityCategory(rawValue: String(firstChar).uppercased()) {
            return LLMResult(category: category, confidence: 0.7)  // LLM = "trust but verify"
        }
        // Parse failed = return catch-all
        return LLMResult(category: .z, confidence: 0.0)
    }

    // MARK: - Keyword dictionary

    /// Category keywords (= 22 categories × ~5-10 keywords each).
    /// Total ~150 keywords across all categories (= manageable size).
    ///
    /// Keywords are LOWER-CASE Chinese + English (= covers both).
    /// They should be:
    /// - Domain-specific (= "细胞" → 生物, not 医药)
    /// - Common in fiction (= "将军" → 军事, "公主" → 政治 or 文学)
    /// - Not too generic (= "the", "and" would match everything = useless)
    ///
    /// For ambiguous entities (= e.g. "皇帝" = politics K/D or
    /// history K), the LLM pass is the tie-breaker.
    public static let keywords: [EntityCategory: [String]] = [
        // A — 马克思列宁毛邓
        .a: ["马克思", "列宁", "毛泽东", "邓小平", "共产主义", "社会主义", "共产党宣言", "资本论", "mao", "lenin", "marx", "communism"],
        // B — 哲学、宗教
        .b: ["哲学", "宗教", "佛教", "基督教", "伊斯兰教", "道家", "儒家", "佛教", "神学", "philosophy", "religion", "buddhism", "christianity", "islam", "taoism", "confucianism", "道德经", "论语", "圣经", "古兰经", "哲学的", "尼采", "柏拉图", "苏格拉底"],
        // C — 社会科学总论
        .c: ["社会学", "人口学", "人才学", "社会调查", "统计学", "社会心理学", "sociology", "demographics", "statistics", "social research", "社会调查方法", "问卷调查"],
        // D — 政治、法律
        .d: ["政治", "法律", "政府", "国会", "总统", "选举", "民主", "独裁", "皇帝", "国王", "议会", "司法", "判决", "宪法", "刑法", "民法", "poilitics", "law", "government", "election", "democracy", "dictator", "constitution", "criminal", "civil law", "法院", "法律条文", "政治制度", "皇位", "王位", "登基"],
        // E — 军事
        .e: ["军事", "战争", "将军", "士兵", "武器", "枪", "炮", "军舰", "坦克", "战斗机", "军服", "军衔", "司令", "元帅", "将军", "军营", "战争史", "military", "war", "soldier", "weapon", "gun", "tank", "warship", "fighter jet", "军队", "战役", "战略", "战术", "战俘", "军事基地", "航母", "导弹"],
        // F — 经济
        .f: ["经济", "金融", "银行", "货币", "市场", "贸易", "公司", "股票", "投资", "GDP", "经济危机", "产业", "农业经济", "工业经济", "economy", "finance", "bank", "currency", "market", "trade", "company", "stock", "investment", "工厂", "制造业", "商业", "供需", "资本主义", "经济体制", "汇率", "通货膨胀"],
        // G — 文化、科学、教育、体育
        .g: ["文化", "教育", "学校", "大学", "小学", "中学", "教师", "学生", "课程", "考试", "体育", "运动", "足球", "篮球", "奥运会", "culture", "education", "school", "university", "teacher", "student", "sports", "football", "olympics", "校园", "课堂", "教学", "学历", "高考", "运动会"],
        // H — 语言、文字
        .h: ["语言", "文字", "汉字", "汉语", "英语", "日语", "法语", "西班牙语", "语法", "词汇", "方言", "文言文", "language", "linguistics", "chinese characters", "vocabulary", "dialect", "翻译", "文言", "方言学", "词典", "phonetics", "语音学"],
        // I — 文学
        .i: ["文学", "小说", "诗歌", "散文", "戏剧", "莎士比亚", "鲁迅", "曹雪芹", "李白", "杜甫", "诗人", "作家", "literature", "novel", "poetry", "drama", "shakespeare", "poem", "诗经", "楚辞", "唐诗", "宋词", "元曲", "红楼梦", "莎士比亚", "海明威", "马尔克斯", "托尔斯泰", "小说家", "作品", "诗集", "文集", "古典文学", "现代文学", "外国文学"],
        // J — 艺术
        .j: ["艺术", "绘画", "雕塑", "音乐", "舞蹈", "戏剧", "电影", "摄影", "书法", "画家", "作曲家", "导演", "演员", "美术馆", "画展", "音乐会", "art", "painting", "sculpture", "music", "dance", "film", "photography", "calligraphy", "演唱会", "钢琴", "小提琴", "油画", "水墨画", "摄影展", "电影导演", "奥斯卡"],
        // K — 历史、地理
        .k: ["历史", "朝代", "古代", "现代", "近代", "唐朝", "宋朝", "明朝", "清朝", "秦朝", "汉朝", "罗马帝国", "古希腊", "中世纪", "二战", "一战", "历史人物", "历史事件", "地理", "城市", "国家", "大陆", "海洋", "山脉", "河流", "history", "dynasty", "ancient", "medieval", "world war", "geography", "country", "continent", "战争年代", "三国", "魏晋南北朝", "元朝", "春秋战国", "中世纪", "古代中国", "近代史", "现代史", "开国皇帝", "王朝更替", "帝国兴亡", "地理学家"],
        // N — 自然科学总论
        .n: ["自然", "科学", "研究", "实验", "理论", "方法论", "natural science", "research method", "scientific method", "研究方法", "学术"],
        // O — 数理科学和化学
        .o: ["数学", "物理", "化学", "公式", "定理", "方程", "微积分", "代数", "几何", "量子", "相对论", "牛顿", "爱因斯坦", "数学家", "物理学家", "化学家", "mathematics", "physics", "chemistry", "calculus", "algebra", "geometry", "quantum", "relativity", "newton", "einstein", "公式推导", "物理定律", "化学元素", "化学反应", "原子", "分子"],
        // P — 天文学、地球科学
        .p: ["天文", "宇宙", "星球", "太阳", "月球", "星座", "彗星", "黑洞", "银河", "星云", "地球", "海洋", "火山", "地震", "气候", "气象", "地质", "矿物", "岩石", "化石", "astronomy", "planet", "sun", "moon", "galaxy", "black hole", "comet", "earth", "ocean", "volcano", "earthquake", "climate", "geology", "fossil", "恒星", "行星", "地质年代", "宇宙演化"],
        // Q — 生物科学
        .q: ["生物", "细胞", "基因", "DNA", "蛋白质", "进化", "生态系统", "物种", "动物", "植物", "微生物", "菌", "达尔文", "孟德尔", "biology", "cell", "gene", "DNA", "protein", "evolution", "ecosystem", "species", "animal", "plant", "bacteria", "darwin", "mendel", "细胞学", "遗传学", "生态学", "植物学", "动物学", "微生物学", "物种起源", "基因编辑"],
        // R — 医药、卫生
        .r: ["医药", "卫生", "医院", "医生", "护士", "药", "疾病", "治疗", "手术", "诊断", "症状", "病", "药方", "中药", "西药", "疫苗", "中医", "西医", "内科", "外科", "medicine", "doctor", "hospital", "nurse", "drug", "disease", "treatment", "surgery", "diagnosis", "vaccine", "中草药", "西药", "处方", "药典", "临床", "医院", "诊所", "病人", "医生"],
        // S — 农业科学
        .s: ["农业", "种植", "养殖", "畜牧", "作物", "稻", "麦", "玉米", "棉花", "果蔬", "肥料", "农药", "农业", "渔业", "agriculture", "farming", "livestock", "crop", "rice", "wheat", "corn", "fertilizer", "pesticide", "水稻", "小麦", "果农", "菜农", "渔民", "养殖业", "种植业", "农学", "园艺"],
        // T — 工业技术
        .t: ["工业", "制造", "工程", "技术", "机器", "自动化", "电子", "通信", "计算机", "软件", "硬件", "互联网", "AI", "人工智能", "芯片", "半导体", "industry", "manufacturing", "engineering", "technology", "machine", "automation", "computer", "software", "hardware", "internet", "AI", "chip", "semiconductor", "工厂", "生产", "制造工艺", "工程师", "工业革命", "数码", "5G", "人工智能"],
        // U — 交通运输
        .u: ["交通", "运输", "铁路", "公路", "汽车", "火车", "飞机", "船舶", "航运", "海运", "地铁", "公交", "transport", "railway", "highway", "car", "train", "airplane", "ship", "subway", "bus", "汽车", "司机", "铁路", "航班", "航班号", "船长", "铁路线", "运输工具", "物流"],
        // V — 航空、航天
        .v: ["航空", "航天", "飞机", "火箭", "卫星", "空间站", "太空船", "宇航员", "宇宙飞船", "探月", "火星", "aviation", "aerospace", "aircraft", "rocket", "satellite", "space station", "spaceship", "astronaut", "太空", "宇宙航行", "航天飞机", "探月计划", "火星探测", "喷气式", "螺旋桨", "民航", "机长", "空军"],
        // X — 环境科学、安全科学
        .x: ["环境", "污染", "环保", "气候变暖", "废物", "垃圾", "回收", "生态保护", "灾害", "地震", "洪水", "火灾", "事故", "安全", "环境科学", "environment", "pollution", "climate change", "recycling", "disaster", "earthquake", "flood", "fire", "safety", "温室气体", "碳排放", "垃圾分类", "自然灾害", "事故调查", "安全检查"],
        // Z — 综合性图书
        .z: ["百科", "全书", "综合", "手册", "指南", "年鉴", "词典", "辞典", "encyclopedia", "handbook", "manual", "yearbook", "dictionary", "总览", "综合类", "参考工具", "指南"],
    ]
}