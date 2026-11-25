//
//  StoryClaimReaderTests.swift · Wenshu
//
//  The claims a book already writes down, read back out of its own
//  field lines.
//
//  The fixtures carry the book's own Chinese lines, because the
//  production reader splits on the book's own punctuation and a
//  fixture written in English would not prove the two agree. The
//  field lines are copied out of a real book in the repo's own
//  `.ws` package, so the reader is measured against the text it will
//  actually be asked about.
//
//

import Foundation
import Testing
import WenshuData

@Suite("StoryClaimReader (= a book's own field lines, read)")
struct StoryClaimReaderTests {
    // MARK: - The lines a book writes

    @Test("a document's header lines are claims about its subject")
    func headerLinesAreClaims() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            # 雨水

            实体类型: concept
            标签: 二十四节气 / 春季
            摘要: 二十四节气第 2 位。

            ## 1. 基础档案

            - **节气名**: 雨水（节令名）
            - **太阳到达**: 黄经 330°
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 5)
        #expect(claims.allSatisfy { $0.subject == "雨水" })
        #expect(claims.allSatisfy { $0.chapter == nil })
        #expect(claims.map(\.attribute) == ["实体类型", "标签", "摘要", "节气名", "太阳到达"])
        #expect(claims.map(\.value).contains("黄经 330°"))
    }

    @Test("a claim's id names the subject and the line it came from")
    func claimsAreNamed() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            实体类型: concept
            摘要: 二十四节气第 2 位。
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.map(\.id) == ["雨水#0", "雨水#1"])
    }

    @Test("a document with no title states no claim")
    func aDocumentWithNoTitleStatesNothing() {
        let document = StoryDocument(
            title: "   ",
            text: """
            实体类型: concept
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a plain field line is a claim")
    func aPlainFieldLineIsAClaim() {
        let document = StoryDocument(
            title: "张铁牛",
            text: """
            ## 基本信息

            - 姓名: 张铁牛
            - 年龄: 42
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 2)
        #expect(claims.map(\.attribute) == ["姓名", "年龄"])
        #expect(claims.map(\.value) == ["张铁牛", "42"])
    }

    // MARK: - The lines that state nothing

    @Test("a heading names a section, not a property")
    func aHeadingIsNotAClaim() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            ## 基础档案

            ## 2. 古籍原句
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a quote is the book's citation of someone else")
    func aQuoteIsNotAClaim() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            > 「雨水之日，獭祭鱼。」
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a link list names other documents, not a property")
    func aLinkListIsNotAClaim() {
        let document = StoryDocument(
            title: "十二地仙",
            text: """
            - [[核心设定.md]]
            - [[地理或位置.md]]
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a bare line with a colon is prose, not a property")
    func aBareLineWithAColonIsProse() {
        // The books this reader serves write their fields as bullets.
        // A bare line is a sentence, = and a sentence that happens to
        // hold a colon states nothing about the subject.
        let document = StoryDocument(
            title: "体系或规则",
            text: """
            这套世界观有三条硬规则：分清、唯一、代价。
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a bullet with no name is prose, not a property")
    func aBulletWithNoNameIsNotAClaim() {
        let document = StoryDocument(
            title: "体系或规则",
            text: """
            - 三分法 · 分清原则（用户拍板）：
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a table row is a table, not a field")
    func aTableRowIsNotAClaim() {
        let document = StoryDocument(
            title: "十二案",
            text: """
            | 卷 | 朝代 | 职业 |
            | --- | --- | --- |
            """
        )
        #expect(StoryClaimReader.claims(in: document).isEmpty)
    }

    @Test("a horizontal rule is a rule, not a field")
    func aHorizontalRuleIsNotAClaim() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            ---

            实体类型: concept
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 1)
        #expect(claims.first?.attribute == "实体类型")
    }

    // MARK: - The weight a line carries

    @Test("a template the writer has not filled in states nothing")
    func anUnfilledTemplateIsNotAClaim() {
        let document = StoryDocument(
            title: "张铁牛",
            text: """
            - 姓名: <本名 / 化名 / 称号>
            - 年龄: 42
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 1)
        #expect(claims.first?.attribute == "年龄")
    }

    @Test("a line the book is not sure about weighs less than the kernel's threshold")
    func aHintWeighsLess() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            - **太阳到达**: 可能为黄经 330°
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 1)
        #expect(claims.first?.grade == StoryClaimReader.hintedGrade)
        #expect(claims.first?.grade ?? 1 < StoryConsistency.defaultMinimumGrade)
    }

    @Test("a line the book states flatly carries a full claim")
    func aFlatLineIsAFirmClaim() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            - **太阳到达**: 黄经 330°
            """
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.first?.grade == StoryClaimReader.firmGrade)
    }

    // MARK: - The moment a claim belongs to

    @Test("a chapter's claim belongs to that chapter")
    func aChaptersClaimCarriesItsChapter() {
        let document = StoryDocument(
            title: "第 3 章 北门",
            text: """
            摘要: 旧疤在北门下发痒。
            """,
            chapter: 3
        )
        let claims = StoryClaimReader.claims(in: document)
        #expect(claims.count == 1)
        #expect(claims.first?.chapter == 3)
    }

    @Test("a document that is not a chapter states what holds beside the chapters")
    func aSheetsClaimCarriesNoChapter() {
        let document = StoryDocument(
            title: "张铁牛",
            text: """
            - 身份: 仵作
            """
        )
        #expect(StoryClaimReader.claims(in: document).first?.chapter == nil)
    }

    // MARK: - Several documents

    @Test("two documents about one subject are read as two sets of claims under it")
    func twoDocumentsShareASubject() {
        // The reader's own promise: = = two documents about one subject
        // are read as two sets of claims UNDER ONE SUBJECT, = = so the
        // kernel can weigh them together. = = The promise is about the
        // subject, = = and the two documents here share a title (= the
        // same subject), = = which is what the promise names.
        let sheet = StoryDocument(
            title: "张铁牛",
            text: """
            - 身份: 仵作
            """,
            identity: "characters/张铁牛.md"
        )
        let chapter = StoryDocument(
            title: "张铁牛",
            text: """
            - 出场角色: 张铁牛
            """,
            chapter: 3,
            identity: "chapters/03.md"
        )
        let claims = StoryClaimReader.claims(in: [sheet, chapter])
        #expect(claims.count == 2)
        #expect(claims.map(\.subject) == ["张铁牛", "张铁牛"])
        #expect(claims.map(\.attribute) == ["身份", "出场角色"])
        #expect(claims.map(\.chapter) == [nil, 3])
        // The two documents share a subject, = = so their claims would
        // share a name (= the subject plus the line) = = and a report
        // could not point at one of them. = = The caller says which
        // document is which, = = so the names are apart.
        #expect(Set(claims.map(\.id)).count == 2)
        #expect(claims.map(\.id) == ["characters/张铁牛.md#0", "chapters/03.md#0"])
    }

    @Test("the same book reads the same way twice")
    func theSameBookReadsTheSameWay() {
        let document = StoryDocument(
            title: "雨水",
            text: """
            实体类型: concept
            标签: 二十四节气
            - **太阳到达**: 黄经 330°
            """
        )
        #expect(StoryClaimReader.claims(in: document) == StoryClaimReader.claims(in: document))
    }

    @Test("the reader opens no file")
    func theReaderOpensNoFile() {
        // The reader is a function over text: it is handed the book's
        // words and returns the claims they state. Where those words
        // come from is another layer's business.
        let document = StoryDocument(title: "雨水", text: "实体类型: concept")
        #expect(!StoryClaimReader.claims(in: document).isEmpty)
    }

    // MARK: - A real book

    /// The lines a real book writes.
    ///
    /// Copied out of a book's own world document in the `.ws` package
    /// this repo builds, = and kept here as the book's own data (= the
    /// line shapes a writer fills in by hand). = The document's
    /// paragraph holds sentences with the full-width colon, = its
    /// bullets hold a bold name, = a bold name with a trailing note and
    /// no value, = a nested bullet whose colon sits inside the bold
    /// name, = and a bullet whose name the book states flatly.
    private static let realBookLines = """
    "分清"管的是分类：神是神、文化是文化、物件是物件，三者互不越界；"唯一"管的是不重复：十二案各占一个朝代、一门职业、一个地支，不重样；"代价"管的是收忆者——每一次"保护"都要以杀死、冻结、替代为代价，故事里没有免费的好事。此外还有一条创作规则：正文由作者亲笔，AI 只给梗概与建议，不代写成稿。
    ## 关键点
    - **三分法 · 分清原则**（用户拍板）：
      - **神 = 主角十二案中"看见"或"引用"的**——神格层，归 `08-3大类实体/01-神/`。
      - **文化 = 主角十二案中"使用"的**——民俗层（节气 / 律吕调阳 / 习俗 / 行业祖师 / 民间职业），归 `08-3大类实体/02-文化/`。
      - **物件 = 主角十二案中"看到"并"使用"的**——建筑 / 器物 / 工具 / 礼器，归 `08-3大类实体/03-物件/`。
      - 用法口诀（用户原话）：**"和谁在一起发生的故事"用神；"聊天的过程中引入哪些文化"用文化；"使用的看到的是什么物件"用物件。**
    - **三档神格分寸**：创世神（盘古 / 女娲 / 伏羲）只闻其声不见其人，只被"引用"；大神（三清 / 玉帝 / 阎罗 / 佛祖 / 王母）偶尔被引用，不"出场"；民俗神（夏目友人帐、聊斋志异一路）出场并成为某段故事的核心，可"看见"并与之聊天。
    - **十二案映射律**：一案 = 一地支 = 一朝代 = 一职业。卷一的职业是仵作，卷七是媒婆，卷十二是屠户——职业即视角的入口。
    """

    @Test("a real book's own field lines are read as claims")
    func aRealBooksFieldLinesAreRead() {
        let claims = StoryClaimReader.claims(in: StoryDocument(
            title: "体系或规则",
            text: Self.realBookLines
        ))
        // Three of the book's bullets state a property: = the one with
        // a plain name, = and the two with a bold name and a value.
        #expect(claims.count == 3)
        #expect(claims.allSatisfy { $0.subject == "体系或规则" })
        #expect(claims.map(\.attribute) == [
            "用法口诀（用户原话）",
            "三档神格分寸",
            "十二案映射律",
        ])
        #expect(claims.allSatisfy { $0.grade == StoryClaimReader.firmGrade })
    }

    @Test("a real book's prose is not read as claims")
    func aRealBooksProseIsNotAClaim() {
        // The paragraph's sentences carry the full-width colon, = and a
        // sentence is not a field: = the paragraph states nothing.
        //
        // The text checked here lives only in that bare paragraph, = =
        // and it sits AFTER the colon. = = So a reader that broke the
        // bullet rule would split the bare line at the colon, = = put
        // the sentence's tail in the VALUE, = = and this check would
        // see it. = = The attribute is checked too, = = because a reader
        // that split the line the other way would put the sentence's
        // head there instead.
        let claims = StoryClaimReader.claims(in: StoryDocument(
            title: "体系或规则",
            text: Self.realBookLines
        ))
        #expect(!claims.contains { $0.value.contains("互不越界") })
        #expect(!claims.contains { $0.attribute.contains("互不越界") })
    }

    @Test("a real book's nested bullets state nothing")
    func aRealBooksNestedBulletsStateNothing() {
        // The nested bullets hold their colon inside the bold name
        // (= `**god = the one who sees**`), = and the rest of the line
        // is prose after an em dash. = So they state no property.
        //
        // The text checked here is that prose, = = and it sits AFTER
        // the bold name. = = So a reader that read a bold head with no
        // colon of its own would put it in the VALUE, = = and this
        // check would see it.
        let claims = StoryClaimReader.claims(in: StoryDocument(
            title: "体系或规则",
            text: Self.realBookLines
        ))
        #expect(!claims.contains { $0.value.contains("神格层") })
        #expect(!claims.contains { $0.attribute.contains("神格层") })
    }

    @Test("a real book's bullet with a trailing note and no value states nothing")
    func aRealBooksEmptyBulletStatesNothing() {
        // The book wrote the name, = then a note about it, = and left
        // the value empty. = An empty value states nothing.
        let claims = StoryClaimReader.claims(in: StoryDocument(
            title: "体系或规则",
            text: Self.realBookLines
        ))
        #expect(!claims.contains { $0.attribute.contains("分清原则") })
    }
}
