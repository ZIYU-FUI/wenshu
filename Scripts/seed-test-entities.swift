// Scripts/seed-test-entities.swift
//
// v0.29: Seed test entities (= sample research library content) across
// multiple categories so we can verify the entity classification + the
// incremental sidebar display.
//
// Usage: swift Scripts/seed-test-entities.swift <library-path>
//
// This is a one-shot test script (not a runtime feature) = boss OOB
// '用从这里开始教我们的帮助文档, 也当测试用的文件'. We seed:
//   - 6 entities across 5 categories (历史 K, 军事 E, 经济 F, 文学 I, 哲学 B)
//   - 1 unclassified (= layer = .layerEntities, category = nil) to show
//     the fallback behavior
//   - 1 raw material (= layer = .layerRaw) to show it's hidden
//
// Each entity has a UUID + a .md body + an entry in entities.json.

import Foundation

// MARK: - Stub models (= mirror of Domain/Reference.swift + LibraryMigrator.swift)

// In production: import WenshuApp and use Reference + FileSystemReferenceStore.
// In this script: re-implement minimal struct (= same Codable layout) + write JSON directly.

struct EntitySeed {
    let title: String
    let summary: String
    let body: String
    let category: String?  // "K", "E", etc. or nil for unclassified
}

let seeds: [EntitySeed] = [
    // K — 历史、地理 (3 entities)
    EntitySeed(
        title: "唐朝贞观之治",
        summary: "唐太宗李世民在位期间 (627-649) 的盛世局面。",
        body: """
        # 唐朝贞观之治

        贞观之治是唐太宗李世民在位期间 (627-649 年) 出现的盛世。这一时期, 中国政治清明、经济复苏、文化繁荣, 对后世产生了深远影响。

        ## 主要措施

        1. 任用贤臣: 房玄龄、杜如晦、魏征等
        2. 轻徭薄赋: 减轻百姓负担
        3. 完善科举: 选拔人才
        4. 开放外交: 与突厥、高昌、吐蕃等交流

        ## 历史意义

        贞观之治是中国历史上少有的盛世之一, 为后来的开元盛世奠定了基础。
        """,
        category: "K"
    ),
    EntitySeed(
        title: "赤壁之战",
        summary: "三国时期决定性的水上战役 (208 年)。",
        body: """
        # 赤壁之战

        赤壁之战 (208 年冬) 是中国历史上著名的以少胜多的战役。东吴孙权与刘备联军在长江赤壁一带大败曹操水军, 奠定了三国鼎立的局面。

        ## 战役背景

        - 曹操率 20 余万大军南下, 意图一统天下
        - 孙权、刘备联军约 3 万人
        - 周瑜、诸葛亮联手策划火攻

        ## 战役影响

        此战之后, 三国鼎立的局面基本形成。
        """,
        category: "K"
    ),
    EntitySeed(
        title: "罗马帝国兴亡",
        summary: "罗马帝国从兴起到衰亡的全过程。",
        body: """
        # 罗马帝国兴亡

        罗马帝国 (公元前 27 年 - 公元 476 年西罗马灭亡) 是古代世界最强大的帝国之一。

        ## 历史阶段

        - 王政时期 (前 753 - 前 509)
        - 共和国时期 (前 509 - 前 27)
        - 帝国时期 (前 27 - 476)

        ## 重要事件

        凯撒被刺 (前 44)、奥古斯都建立帝制 (前 27)、君士坦丁堡迁都 (330)、西罗马灭亡 (476)。
        """,
        category: "K"
    ),

    // E — 军事 (1 entity)
    EntitySeed(
        title: "汉尼拔的战术",
        summary: "迦太基名将汉尼拔的经典军事战术。",
        body: """
        # 汉尼拔的战术

        汉尼拔·巴卡 (前 247 - 前 183) 是古代世界最伟大的军事家之一。

        ## 经典战役

        - 坎尼会战 (前 216): 双重包围战术的典范
        - 翻越阿尔卑斯山: 携带战象攻打罗马

        ## 战术特点

        - 灵活机动, 出其不意
        - 善于利用地形
        - 重骑兵与轻步兵协同
        """,
        category: "E"
    ),

    // F — 经济 (1 entity)
    EntitySeed(
        title: "宋朝海上丝绸之路",
        summary: "宋朝繁荣的海上贸易体系。",
        body: """
        # 宋朝海上丝绸之路

        宋朝 (960-1279) 是中国古代海上贸易最繁荣的时期。

        ## 贸易港口

        - 泉州: 天下第一港
        - 广州: 南方贸易中心
        - 明州 (今宁波): 对日贸易

        ## 主要商品

        输入: 香料、珠宝、药材
        输出: 瓷器、丝绸、铜钱

        ## 经济影响

        海上贸易为宋朝带来了大量财政收入, 也促进了造船和航海技术的发展。
        """,
        category: "F"
    ),

    // I — 文学 (1 entity)
    EntitySeed(
        title: "李白与杜甫",
        summary: "唐代最伟大的两位诗人。",
        body: """
        # 李白与杜甫

        李白 (701-762) 与杜甫 (712-770) 是中国唐代最伟大的两位诗人, 被并称为 "李杜"。

        ## 李白

        - 诗仙, 浪漫主义诗人
        - 代表作: 《静夜思》、《将进酒》、《蜀道难》

        ## 杜甫

        - 诗圣, 现实主义诗人
        - 代表作: 《春望》、《登高》、《茅屋为秋风所破歌》

        ## 历史影响

        李杜的诗作对中国后世诗歌发展产生了深远影响。
        """,
        category: "I"
    ),

    // B — 哲学、宗教 (1 entity, low-keyword test)
    EntitySeed(
        title: "王阳明心学",
        summary: "明代哲学家王阳明的心学体系。",
        body: """
        # 王阳明心学

        王阳明 (1472-1529) 是明代著名的哲学家、军事家, 心学的集大成者。

        ## 核心理念

        - 心即理: 心是万物本源
        - 知行合一: 认识与实践的统一
        - 致良知: 唤醒内在的道德判断

        ## 历史影响

        心学在明清两代影响深远, 后传入日本、朝鲜。
        """,
        category: "B"
    ),

    // unclassified (= category = nil)
    EntitySeed(
        title: "未分类研究材料",
        summary: "一个还没经过分类的研究材料。",
        body: "# 未分类研究材料\n\n这里应该是一段还没经过实体分类的内容, 会落到 layerEntities 但 category 为 nil, sidebar 不显示。\n",
        category: nil
    ),
]

// MARK: - Write to library

let libraryPath = CommandLine.arguments.dropFirst().first
    ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/anbaiqiang.ws")
        .path

let libraryURL = URL(fileURLWithPath: libraryPath)
let entitiesDir = libraryURL.appendingPathComponent("reference-library/entities")
let rawDir = libraryURL.appendingPathComponent("reference-library/raw")

// Ensure dirs exist
try? FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)

// Track entity IDs + categories for the index
var entities: [[String: Any]] = []

for seed in seeds {
    let id = UUID().uuidString
    let filename = "\(id).md"

    // Write .md body to category subdir
    var mdURL: URL
    if let cat = seed.category {
        let catDir = entitiesDir.appendingPathComponent(cat.lowercased())
        try? FileManager.default.createDirectory(at: catDir, withIntermediateDirectories: true)
        mdURL = catDir.appendingPathComponent(filename)
    } else {
        // Unclassified = flat entities dir
        mdURL = entitiesDir.appendingPathComponent(filename)
    }
    try? seed.body.data(using: .utf8)?.write(to: mdURL)

    // Track in entities index
    let entry: [String: Any] = [
        "id": id,
        "title": seed.title,
        "summary": seed.summary,
        "layer": "layerEntities",
        "category": seed.category as Any? ?? NSNull(),
        "subcategory": NSNull(),
        "characterRefIds": [] as [Any],
        "worldRefIds": [] as [Any],
        "bookRefIds": [] as [Any],
        "createdAt": ISO8601DateFormatter().string(from: Date()),
        "updatedAt": ISO8601DateFormatter().string(from: Date()),
        "url": NSNull()
    ]
    entities.append(entry)

    print("Seeded: \(seed.title) → \(seed.category ?? "(unclassified)")")
}

// Also seed 1 raw material (= should be hidden from sidebar)
let rawId = UUID().uuidString
let rawBody = """
# 原始研究材料

这是一个原始研究材料 (= layerRaw), 不应该出现在 sidebar 资料库分类中。
只对 LLM 提取流程有意义。
"""
let rawURL = rawDir.appendingPathComponent("\(rawId).md")
try? rawBody.data(using: .utf8)?.write(to: rawURL)
print("Seeded raw material: \(rawId) (hidden from sidebar)")

// Write entities.json index
let indexJSON = try! JSONSerialization.data(
    withJSONObject: entities,
    options: [.prettyPrinted, .sortedKeys]
)
let indexURL = entitiesDir.appendingPathComponent("entities.json")
try indexJSON.write(to: indexURL)
print("Wrote entities index: \(entities.count) entities → \(indexURL.path)")

print()
print(String(repeating: "=", count: 50))
print("Summary: \(entities.count) entities seeded across \(Set(seeds.compactMap { $0.category }).count) categories")
print("Categories: \(Set(seeds.compactMap { $0.category }).sorted().joined(separator: ", "))")