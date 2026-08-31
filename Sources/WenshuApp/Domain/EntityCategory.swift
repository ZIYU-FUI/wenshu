// Sources/WenshuApp/Domain/EntityCategory.swift
//
// v0.29 boss 2026-08-30 OOB '资料库里的实体文件夹, 我觉得不能直接
// 显示实体, 用户会不知道是什么意思, 实体需要按分类新建成多个文件夹,
// 这里直接显示这些分类文件夹, 比如, 历史, 科学, 这样的分类,
// 你可以参考图书馆的分类法, 这一个规则, 自动归类实体':
//
// = Library taxonomy for entity classification. Based on 《中国图书
// 馆分类法》(CLC = Chinese Library Classification) 5th edition, simplified
// to 22 top-level categories. Each Reference entity (= character,
// location, organization, event, item from the research library) is
// auto-classified into one of these categories.
//
// Use this enum when:
// - Saving a new Reference entity (= assign its category at save time
//   via EntityClassifier.classify())
// - Listing categories in the ReferenceLibrary sidebar (= show category
//   folder names, NOT entity names)
// - Filtering references by category
//
// Listed in ComponentIndex.md (not yet — will be added when reference
// library v0.29 work is complete).
//
// Design notes:
// - 22 top-level categories (= CLC standard, all letters A-Z used
//   except 4 letters: L/M/N reserved for future use, 1 letter Q used
//   for biology specifically)
// - Each category has a Chinese display name + Lucide icon + subcategories
//   (= 2nd level for finer classification, e.g. "I 文学" → "I1 文学理论",
//   "I2 中国文学", "I3 外国文学")
// - Categories are created INCREMENTALLY (= boss OOB: "分类文件夹随着内容
//   逐渐增加, 而不是一下子铺满") = sidebar only shows categories that
//   have at least 1 entity. Empty categories = hidden from sidebar.

import Foundation

/// Top-level entity categories (= 22 大类 based on 《中国图书馆分类法》).
///
/// Used by `Reference.category` (= the field added in v0.29) to
/// organize research entities into library-taxonomy folders.
///
/// v0.29 incremental display rule (= boss OOB): only categories with
/// >= 1 entity are visible in the sidebar. Empty categories are
/// hidden. New categories are added to the sidebar automatically as
/// entities are added to them (= the UI calls `EntityClassifier`
/// on save which sets the category, and the sidebar reloads).
public enum EntityCategory: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    // MARK: - 22 顶级分类 (《中图法》第五版简化)

    case a = "A"  // 马克思主义、列宁主义、毛泽东思想、邓小平理论
    case b = "B"  // 哲学、宗教
    case c = "C"  // 社会科学总论
    case d = "D"  // 政治、法律
    case e = "E"  // 军事
    case f = "F"  // 经济
    case g = "G"  // 文化、科学、教育、体育
    case h = "H"  // 语言、文字
    case i = "I"  // 文学
    case j = "J"  // 艺术
    case k = "K"  // 历史、地理
    case n = "N"  // 自然科学总论
    case o = "O"  // 数理科学和化学
    case p = "P"  // 天文学、地球科学
    case q = "Q"  // 生物科学
    case r = "R"  // 医药、卫生
    case s = "S"  // 农业科学
    case t = "T"  // 工业技术
    case u = "U"  // 交通运输
    case v = "V"  // 航空、航天
    case x = "X"  // 环境科学、安全科学
    case z = "Z"  // 其它 (= catch-all fallback category, v0.30 boss 8/31)

    public var id: String { rawValue }

    /// Chinese display name (= boss 8/25 'UI 全中文' carve-out).
    /// E.g. "I" → "文学", "K" → "历史、地理".
    public var displayName: String {
        switch self {
        case .a: return "马克思列宁毛邓"
        case .b: return "哲学、宗教"
        case .c: return "社会科学总论"
        case .d: return "政治、法律"
        case .e: return "军事"
        case .f: return "经济"
        case .g: return "文化、科学、教育、体育"
        case .h: return "语言、文字"
        case .i: return "文学"
        case .j: return "艺术"
        case .k: return "历史、地理"
        case .n: return "自然科学总论"
        case .o: return "数理科学和化学"
        case .p: return "天文学、地球科学"
        case .q: return "生物科学"
        case .r: return "医药、卫生"
        case .s: return "农业科学"
        case .t: return "工业技术"
        case .u: return "交通运输"
        case .v: return "航空、航天"
        case .x: return "环境科学、安全科学"
        case .z: return "其它"
        }
    }

    /// Short Chinese label (= used in tight UI like sidebar chips,
    /// 1-2 char per CLC convention).
    public var shortName: String {
        switch self {
        case .a: return "马列毛邓"
        case .b: return "哲学"
        case .c: return "社科总论"
        case .d: return "政法"
        case .e: return "军事"
        case .f: return "经济"
        case .g: return "文教科"
        case .h: return "语言"
        case .i: return "文学"
        case .j: return "艺术"
        case .k: return "史地"
        case .n: return "自科总论"
        case .o: return "数理化"
        case .p: return "天球"
        case .q: return "生物"
        case .r: return "医药"
        case .s: return "农业"
        case .t: return "工业"
        case .u: return "交通"
        case .v: return "航天"
        case .x: return "环境"
        case .z: return "其它"
        }
    }

    /// Filesystem directory name (= the on-disk folder under
    /// `reference-library/entities/`). Stable across rename (= Apple
    /// HIG: directory = identity, not the category's display label).
    /// Uses lowercase letter (= POSIX-compliant) for all cases EXCEPT
    /// `.z` (= 其他 fallback, uses Chinese name to match the fallback
    /// convention so LLM output is consistent across the system).
    public var directoryName: String {
        switch self {
        case .z: return "其它"
        default: return rawValue.lowercased()
        }
    }

    /// Lucide icon name for sidebar folder display.
    public var icon: String {
        switch self {
        case .a: return "book-marked"           // 经典
        case .b: return "brain"                  // 哲学
        case .c: return "users"                  // 社科
        case .d: return "scale"                  // 政法
        case .e: return "sword"                  // 军事
        case .f: return "trending-up"            // 经济
        case .g: return "graduation-cap"         // 文教科
        case .h: return "alphabet"               // 语言文字
        case .i: return "book-open"              // 文学
        case .j: return "palette"                // 艺术
        case .k: return "landmark"               // 史地
        case .n: return "atom"                    // 自科
        case .o: return "sigma"                  // 数理化
        case .p: return "globe-2"                 // 天文地球
        case .q: return "leaf"                    // 生物
        case .r: return "heart-pulse"            // 医药
        case .s: return "wheat"                  // 农业
        case .t: return "cog"                     // 工业
        case .u: return "truck"                  // 交通
        case .v: return "plane"                  // 航天
        case .x: return "leaf-2"                  // 环境
        case .z: return "library"                // 综合
        }
    }

    /// 2nd level subcategories (= 2-letter CLC codes, used for finer
    /// classification within each top-level category).
    ///
    /// Not all entities will get a subcategory (= many fit directly
    /// in the top-level bucket). Subcategory is OPTIONAL in Reference
    /// (= Reference.subcategory = String? = e.g. "I2" or nil).
    ///
    /// Boss OOB: keep taxonomy simple (= 22 top-level is enough for
    /// v0.29; subcategories are pre-defined here for future use but
    /// not enforced).
    public var subcategories: [(code: String, displayName: String)] {
        switch self {
        case .a: return [("A1", "马列经典"), ("A2", "毛邓思想")]
        case .b: return [("B1", "哲学理论"), ("B2", "世界哲学"), ("B3", "中国哲学"), ("B4", "宗教")]
        case .c: return [("C1", "社会科学理论"), ("C2", "社会学"), ("C3", "人口学"), ("C4", "人才学")]
        case .d: return [("D1", "政治理论"), ("D2", "中国共产党"), ("D3", "中国政治"), ("D4", "世界政治"), ("D5", "法律")]
        case .e: return [("E1", "军事理论"), ("E2", "中国军事"), ("E3", "世界军事"), ("E4", "战略战术")]
        case .f: return [("F1", "经济理论"), ("F2", "中国经济"), ("F3", "世界经济"), ("F4", "工业经济"), ("F5", "农业经济")]
        case .g: return [("G1", "文化理论"), ("G2", "信息传播"), ("G3", "教育"), ("G4", "体育")]
        case .h: return [("H1", "语言学"), ("H2", "汉语"), ("H3", "中国少数民族语言"), ("H4", "外语")]
        case .i: return [("I0", "文学理论"), ("I1", "世界文学"), ("I2", "中国文学"), ("I3", "亚洲文学"), ("I4", "非洲文学"), ("I5", "欧洲文学"), ("I6", "美洲文学"), ("I7", "大洋洲文学")]
        case .j: return [("J0", "艺术理论"), ("J1", "绘画"), ("J2", "雕塑"), ("J3", "书法"), ("J4", "音乐"), ("J5", "舞蹈"), ("J6", "戏剧"), ("J7", "电影"), ("J8", "摄影")]
        case .k: return [("K1", "史学理论"), ("K2", "中国史"), ("K3", "世界史"), ("K4", "亚洲史"), ("K5", "非洲史"), ("K6", "欧洲史"), ("K7", "美洲史"), ("K8", "大洋洲史"), ("K9", "地理")]
        case .n: return [("N1", "自然科学总论"), ("N2", "自然研究法"), ("N3", "自然调查")]
        case .o: return [("O1", "数学"), ("O2", "力学"), ("O3", "物理学"), ("O4", "化学"), ("O5", "晶体学")]
        case .p: return [("P1", "天文学"), ("P2", "测绘学"), ("P3", "地球物理学"), ("P4", "地质学"), ("P5", "地理学"), ("P6", "采矿工程"), ("P7", "石油天然气")]
        case .q: return [("Q1", "普通生物学"), ("Q2", "细胞学"), ("Q3", "遗传学"), ("Q4", "生理学"), ("Q5", "生物化学"), ("Q6", "古生物学"), ("Q7", "微生物学"), ("Q8", "植物学"), ("Q9", "动物学")]
        case .r: return [("R1", "预防医学"), ("R2", "中国医学"), ("R3", "基础医学"), ("R4", "临床医学"), ("R5", "内科学"), ("R6", "外科学"), ("R7", "药学")]
        case .s: return [("S1", "农业基础"), ("S2", "农业工程"), ("S3", "农学"), ("S4", "植物保护"), ("S5", "农作物"), ("S6", "园艺"), ("S7", "林业"), ("S8", "畜牧"), ("S9", "水产")]
        case .t: return [("T1", "工业技术总论"), ("T2", "自动化"), ("T3", "电子"), ("T4", "通信"), ("T5", "计算机"), ("T6", "化工"), ("T7", "冶金"), ("T8", "机械"), ("T9", "建筑")]
        case .u: return [("U1", "综合运输"), ("U2", "铁路"), ("U3", "公路"), ("U4", "水路"), ("U5", "航空"), ("U6", "管道")]
        case .v: return [("V1", "航空"), ("V2", "航天（火箭/卫星）")]
        case .x: return [("X1", "环境科学基础"), ("X2", "环境污染"), ("X3", "废物处理"), ("X4", "灾害防治"), ("X5", "安全科学")]
        case .z: return [("Z1", "丛书"), ("Z2", "百科全书"), ("Z3", "词典"), ("Z4", "年鉴"), ("Z5", "期刊")]
        }
    }
}