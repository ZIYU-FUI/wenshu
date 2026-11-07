//
//  ManuscriptShaperTests.swift · Wenshu
//
//  The submission manuscript's shape, HELD.
//
//  The rules under test are the measured per-platform facts (= the
//  spec §6 table and the platform study):
//
//  - Jinjiang's segment indent lives IN THE CONTENT (= two full-width
//    spaces U+3000 U+3000 at the start of every segment) and its
//    spacing is a BLANK LINE between segments.
//  - Qidian / Tomato's platform renders the indent (= CSS text-indent
//    2em) and the spacing (= CSS margin), = and Tomato deletes the
//    extra spaces and blank lines on publish, = so the manuscript
//    carries NEITHER.
//  - The chapter title is the platform's own separate field, = so
//    it is not in the manuscript's body.
//
//  The tests drive the production seam (`ManuscriptShaper`), = and
//  the mutations that would break the rules are named below.
//

@testable import WenshuApp
import XCTest

final class ManuscriptShaperTests: XCTestCase {
    // MARK: - The targets' own rules

    /// Jinjiang's indent is IN THE CONTENT: = two full-width spaces at
    /// the start of EVERY segment. = This is the rule a mutation
    /// would break (= one space, = a tab, = an ASCII space).
    func testJinjiangIndentIsTwoFullWidthSpacesOnEverySegment() {
        let body = "第一段。\n\n第二段。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .jinjiang)

        XCTAssertEqual(
            manuscript,
            "\u{3000}\u{3000}第一段。\n\n\u{3000}\u{3000}第二段。",
            "晋江's indent must be two full-width spaces on every segment"
        )
        // The indent is U+3000 twice, = not an ASCII space and not
        // one full-width space.
        XCTAssertTrue(manuscript.hasPrefix("\u{3000}\u{3000}"))
        XCTAssertFalse(manuscript.contains("  "), "the indent must not be ASCII spaces")
    }

    /// Jinjiang's spacing is a BLANK LINE between segments (= its
    /// reading end has margin 0 on every paragraph).
    func testJinjiangSeparatesSegmentsWithABlankLine() {
        let body = "第一段。\n\n第二段。\n\n第三段。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .jinjiang)

        XCTAssertEqual(
            manuscript,
            "\u{3000}\u{3000}第一段。\n\n\u{3000}\u{3000}第二段。\n\n\u{3000}\u{3000}第三段。"
        )
        // Two newlines between segments, = not one.
        XCTAssertTrue(manuscript.contains("\n\n"))
    }

    /// Qidian / Tomato carry NEITHER the indent NOR the blank line: = the
    /// platform renders both itself.
    func testQidianAndFanqieCarryNeitherIndentNorBlankLine() {
        let body = "第一段。\n\n第二段。"
        for target in [ManuscriptTarget.qidian, .fanqie] {
            let manuscript = ManuscriptShaper.manuscript(body: body, target: target)
            XCTAssertEqual(
                manuscript,
                "第一段。\n第二段。",
                "\(target.displayName) must carry neither the indent nor the blank line"
            )
            XCTAssertFalse(manuscript.contains("\u{3000}"), "\(target.displayName) must carry no full-width space")
            XCTAssertFalse(manuscript.contains("\n\n"), "\(target.displayName) must carry no blank line")
        }
    }

    /// THE CHAPTER TITLE IS THE PLATFORM'S OWN FIELD, = so the
    /// manuscript's body never carries it. = The policy is not a
    /// constant on the target (= a constant nothing reads is a
    /// declaration, = not a behaviour): = it is the SHAPER that drops
    /// the body's own title line (= the app's own `extractTitle` rule
    /// = the body's first `# ` line), = and this case holds that.
    func testTheChapterTitleIsNotInTheBody() {
        for target in ManuscriptTarget.allCases {
            let manuscript = ManuscriptShaper.manuscript(
                body: "# 第一章 夜袭\n\n正文第一段。",
                target: target
            )
            XCTAssertFalse(
                manuscript.contains("夜袭"),
                "\(target.displayName) must not carry the chapter title in its body"
            )
        }
    }

    // MARK: - The plain text

    /// The manuscript is PLAIN TEXT: = the app's own editor writes
    /// these markers (= the engine's context menu writes `==` and
    /// `~~`, = the twelve format commands write the rest), = and a
    /// submission carries the words, = not the markup.
    ///
    /// A mutation that keeps a marker would fail here.
    func testTheManuscriptIsPlainText() {
        let body = """
        # 标题

        这是**粗体**和*斜体*，还有`行内代码`和==高亮==和~~删除~~。

        - 列表项
        - 第二项

        > 引用

        [链接](https://example.com)

        ![图注](/tmp/a.png)

        [[人物|UUID-1]]

        ---
        """
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(manuscript.contains("**"))
        XCTAssertFalse(manuscript.contains("*"))
        XCTAssertFalse(manuscript.contains("`"))
        XCTAssertFalse(manuscript.contains("=="))
        XCTAssertFalse(manuscript.contains("~~"))
        XCTAssertFalse(manuscript.contains("["))
        XCTAssertFalse(manuscript.contains("]"))
        XCTAssertFalse(manuscript.contains("#"))
        XCTAssertFalse(manuscript.contains(">"))

        // The words survive.
        XCTAssertTrue(manuscript.contains("粗体"))
        XCTAssertTrue(manuscript.contains("斜体"))
        XCTAssertTrue(manuscript.contains("行内代码"))
        XCTAssertTrue(manuscript.contains("高亮"))
        XCTAssertTrue(manuscript.contains("删除"))
        XCTAssertTrue(manuscript.contains("列表项"))
        XCTAssertTrue(manuscript.contains("第二项"))
        XCTAssertTrue(manuscript.contains("引用"))
        XCTAssertTrue(manuscript.contains("链接"))
        XCTAssertTrue(manuscript.contains("图注"))
        // A wiki link carries its NAME (= the UUID is the link's
        // target, = not a word of the manuscript).
        XCTAssertTrue(manuscript.contains("人物"))
        XCTAssertFalse(manuscript.contains("UUID"))
    }

    /// A horizontal rule carries no prose, = so it contributes
    /// nothing to the manuscript (= its markup, = not the author's
    /// words).
    func testAHorizontalRuleContributesNothing() {
        let body = "第一段。\n\n---\n\n第二段。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertEqual(manuscript, "第一段。\n第二段。")
    }

    /// A heading's hashes are markup, = and its text is prose.
    ///
    /// ONLY A HEADING AFTER THE TITLE: = the body's FIRST level-one
    /// heading is the title (= the app reads a document's title from
    /// it, = and the platform has a title field of its own), = so that
    /// line goes; = a heading after it is the author's own prose.
    func testAHeadingAfterTheTitleContributesItsText() {
        let body = "# 第一章\n\n正文。\n\n## 一节"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertEqual(manuscript, "正文。\n一节")
    }

    /// A code block's fence lines are markup, = and its content is
    /// the author's words.
    func testACodeBlockKeepsItsContentAndDropsItsFence() {
        let body = "正文。\n\n```swift\nlet x = 1\n```"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(manuscript.contains("```"))
        XCTAssertTrue(manuscript.contains("let x = 1"))
    }

    /// THE CONTENT OF A FENCE IS LITERAL: = the engine parses nothing
    /// inside a fence, = so the marks there are the CODE's own
    /// characters, = not the app's dialect. = `**kwargs` in a Python
    /// fence is a call, = not bold.
    ///
    /// MUTATION: = stripping the marks inside a fence (= the same
    /// strip the prose gets) = would rewrite the author's code.
    func testTheContentOfAFenceKeepsItsOwnMarks() {
        let body = "正文。\n\n```python\nresult = fn(**kwargs)\n```"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertTrue(
            manuscript.contains("fn(**kwargs)"),
            "the code's own asterisks must survive (= the engine parses nothing inside a fence)"
        )
    }

    /// A `---` inside a fence is a line of code, = not a rule (= and a
    /// rule carries no prose).
    ///
    /// MUTATION: = treating a fenced `---` as a rule (= the same rule
    /// check the prose gets) = would drop a line of code.
    func testAFenceHoldingARuleKeepsItsLine() {
        let body = "正文。\n\n```\n---\n```"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertTrue(
            manuscript.contains("---"),
            "a rule inside a fence is code (= the engine parses nothing inside a fence)"
        )
    }

    /// A FENCE SPANS BLANK LINES: = the engine's code block with a
    /// blank line in it is ONE code block, = and the content after the
    /// blank line is still code (= and still keeps its own marks).
    ///
    /// MUTATION: = splitting the body at every blank line (= even
    /// inside a fence) = would take the rest of the code out of its
    /// fence and read it as prose.
    func testAFenceSpanningABlankLineKeepsItsContentAsCode() {
        let body = "正文。\n\n```swift\nlet a = 1\n\nlet b = **bold**\n```"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertTrue(
            manuscript.contains("let b = **bold**"),
            "the content after a blank line inside a fence is still code"
        )
        XCTAssertFalse(manuscript.contains("```"), "the fence's markers are markup")
    }

    /// A fenced line keeps its own indentation (= the code's shape is
    /// the author's).
    func testAFenceKeepsItsOwnIndentation() {
        let body = "```\nif x:\n    return 1\n```"
        let segments = ManuscriptShaper.segments(of: body)

        XCTAssertTrue(segments.contains("    return 1"), "the code's indentation is the author's")
    }

    /// An empty body produces an empty manuscript (= no segments, =
    /// no stray separators).
    func testAnEmptyBodyProducesAnEmptyManuscript() {
        for target in ManuscriptTarget.allCases {
            XCTAssertEqual(
                ManuscriptShaper.manuscript(body: "", target: target),
                ""
            )
        }
    }

    // MARK: - The frontmatter

    /// A body's LEADING frontmatter is metadata, = not the author's
    /// prose, = so it does not travel into the submission. = The app's
    /// own import path documents the body as "optional frontmatter +
    /// free markdown body" (= `ImportServiceTitleOnlyHelpers.swift:51`),
    /// = so a chapter body CAN carry one.
    func testTheLeadingFrontmatterIsNotInTheManuscript() {
        let body = """
        ---
        title: 第三章 风起
        date: 2026-11-06
        ---

        他推开门。

        屋里没有人。
        """
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(
            manuscript.contains("title:"),
            "the frontmatter's title must not travel into the submission"
        )
        XCTAssertFalse(
            manuscript.contains("date:"),
            "the frontmatter's date must not travel into the submission"
        )
        XCTAssertFalse(manuscript.contains("---"), "the fence is markup")
        XCTAssertEqual(manuscript, "他推开门。\n屋里没有人。")
    }

    /// The frontmatter's lines are not SEGMENTS either: = the count the
    /// platforms apply is the body's own characters, = and metadata is
    /// not the author's words.
    func testTheFrontmatterIsNotCountedAsASegment() {
        let body = "---\ntitle: 第三章\n---\n\n他推开门。"
        let segments = ManuscriptShaper.segments(of: body)

        XCTAssertEqual(segments, ["他推开门。"])
    }

    /// A body that OPENS with a horizontal rule and never closes one
    /// is NOT frontmatter (= a rule carries no prose anyway), = so its
    /// prose survives.
    func testALeadingRuleWithoutAClosingFenceKeepsItsProse() {
        let body = "---\n\n他推开门。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertEqual(manuscript, "他推开门。")
    }

    /// Only a LEADING block is frontmatter: = a `---` further down is
    /// a horizontal rule, = and the prose before and after it stays.
    func testARuleInsideTheBodyIsNotFrontmatter() {
        let body = "他推开门。\n\n---\n\n屋里没有人。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertEqual(manuscript, "他推开门。\n屋里没有人。")
    }

    /// THE BODY'S OWN TITLE IS NOT IN THE MANUSCRIPT: = the title is
    /// the platform's own separate field, = and the app reads a
    /// document's title from the body's first `# ` line (= so a
    /// chapter body carries its title there).
    ///
    /// MUTATION: = keeping the title line = would say the title twice
    /// (= once in the platform's field, = once as the story's first
    /// line of prose).
    func testTheBodysOwnTitleIsNotInTheManuscript() {
        let body = "# 第三章 风起\n\n他推开门。\n\n屋里没有人。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(
            manuscript.contains("第三章"),
            "the body's own title line must not travel into the submission"
        )
        XCTAssertEqual(manuscript, "他推开门。\n屋里没有人。")
    }

    /// ONLY THE TITLE GOES: = a later level-one heading is the
    /// author's own prose, = and it stays.
    func testALaterLevelOneHeadingStays() {
        let body = "# 第三章 风起\n\n他推开门。\n\n# 转折\n\n屋里没有人。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(manuscript.contains("第三章"))
        XCTAssertTrue(manuscript.contains("转折"), "a later heading is the author's prose")
    }

    /// The title is not prose, = and the platforms count the body
    /// WITHOUT it (= so it is not a segment either).
    func testTheTitleIsNotCountedAsASegment() {
        let body = "# 第三章 风起\n\n他推开门。"
        let segments = ManuscriptShaper.segments(of: body)

        XCTAssertEqual(segments, ["他推开门。"])
    }

    /// A `# ` line inside a code fence is the author's own code, = and
    /// the title is the body's first such line OUTSIDE the code.
    ///
    /// MUTATION: = taking any `# ` line (= the app's own `extractTitle`
    /// rule) = deletes a line of code.
    func testACommentInsideAFenceIsNotTheTitle() {
        let body = "```python\n# c\nprint(1)\n```\n\n# 真正的标题\n\n正文。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertTrue(manuscript.contains("# c"), "the code's own comment survives")
        XCTAssertTrue(manuscript.contains("print(1)"))
        XCTAssertFalse(manuscript.contains("真正的标题"), "the real title goes")
        XCTAssertTrue(manuscript.contains("正文。"))
    }

    /// Two rules with PROSE between them are two rules, = not
    /// frontmatter, = and the prose survives.
    ///
    /// MUTATION: = stripping any leading `---` block (= the app's own
    /// `extractSummary` rule) = deletes the author's prose.
    func testTwoRulesWithProseBetweenThemKeepTheProse() {
        let body = "---\n\n段落一。\n\n---\n\n段落二。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertTrue(manuscript.contains("段落一。"), "the prose between two rules survives")
        XCTAssertTrue(manuscript.contains("段落二。"))
    }

    /// A frontmatter block that CONTAINS a blank line is still
    /// frontmatter (= the reviewer's caveat: = the block is metadata,
    /// = so it goes).
    func testAFrontmatterBlockWithABlankLineIsStillFrontmatter() {
        let body = "---\ntitle: 第一章\n\n---\n\n正文第一段。"
        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)

        XCTAssertFalse(manuscript.contains("title:"))
        XCTAssertEqual(manuscript, "正文第一段。")
    }

    // MARK: - The segments themselves

    /// The segments are the source's paragraphs (= what a platform's
    /// segment IS: = Tomato's official rule is "a segment is one line,
    /// entered with the return key").
    func testTheSegmentsAreTheSourceParagraphs() {
        let body = "第一段。\n\n第二段。\n\n第三段。"
        let segments = ManuscriptShaper.segments(of: body)

        XCTAssertEqual(segments, ["第一段。", "第二段。", "第三段。"])
    }

    /// The count the platforms apply is the count of the BODY (= the
    /// title excluded) = and it is measured on the segments.
    func testTheSegmentsAreWhatTheWordCountIsMeasuredOn() {
        let body = "第一段。\n\n第二段。"
        let segments = ManuscriptShaper.segments(of: body)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(
            segments.reduce(0) { $0 + $1.count },
            "第一段。".count + "第二段。".count,
            "the count is the body's own characters (= the title excluded)"
        )
    }

    // MARK: - The panel's own words about the shape

    /// The export panel SAYS what the target's shape is. = The text
    /// is derived from the measured rules, = so this holds the reader
    /// text to them: = a rule that changes brings the words with it.
    func testThePanelsProseIsTheReaderTextTheRulesAskFor() {
        XCTAssertEqual(ManuscriptTarget.qidian.indentDescription, "每段首行不缩进")
        XCTAssertEqual(ManuscriptTarget.fanqie.indentDescription, "每段首行不缩进")
        XCTAssertEqual(ManuscriptTarget.jinjiang.indentDescription, "每段首行两个全角空格")
        XCTAssertEqual(ManuscriptTarget.qidian.spacingDescription, "段间无空行")
        XCTAssertEqual(ManuscriptTarget.fanqie.spacingDescription, "段间无空行")
        XCTAssertEqual(ManuscriptTarget.jinjiang.spacingDescription, "段间空一行")
    }

    /// The prose is DERIVED from the rule, = so it cannot state a shape
    /// the export does not produce. = This holds that link: = the
    /// indent's line names full-width spaces exactly when the shaper
    /// writes them, = and the spacing's line follows the blank line.
    func testThePanelsProseMovesWithTheMeasuredRule() {
        for target in ManuscriptTarget.allCases {
            let spaces = target.segmentIndent.filter { $0 == "\u{3000}" }.count
            XCTAssertEqual(
                target.indentDescription.contains("全角空格"),
                spaces > 0,
                "\(target.displayName)'s panel must name full-width spaces exactly when the shaper writes them"
            )
            XCTAssertEqual(
                target.spacingDescription == "段间空一行",
                target.separatesSegmentsWithBlankLine,
                "\(target.displayName)'s panel must follow the measured blank-line rule"
            )
        }
    }

    // MARK: - The count the target's rule measures

    /// The count is the CONTENT's characters: = the segments as the
    /// shaper reads them, = summed.
    ///
    /// MUTATION: = counting the SHAPED text (= with the indent and the
    /// blank lines) = would report a number the platform does not
    /// count, = and = counting the title with it = would count a field
    /// the platform keeps for itself.
    func testTheWordCountIsTheContentsOwnCharacters() {
        let body = """
        # 第一章

        第一段。
        第二段。
        """

        let count = ManuscriptShaper.wordCount(of: body)
        // = the title is the platform's own field, = so it is not in the
        // body the count measures.
        XCTAssertEqual(count, "第一段。第二段。".count)
        // = and the count is NOT the shaped text's length: = Jinjiang's
        // indent and its blank line are the platform's own shape.
        let jinjiang = ManuscriptShaper.manuscript(body: body, target: .jinjiang)
        XCTAssertNotEqual(count, jinjiang.count)
    }

    /// Every target counts the body, = and the one whose rule this
    /// build could source carries a range, = while the others carry none
    /// (= the app checks nothing against a number it cannot point at).
    func testTheTargetsCarryTheirWordCountRules() {
        for target in ManuscriptTarget.allCases {
            XCTAssertFalse(target.wordCountRule.isEmpty, "\(target.displayName) states what it counts")
        }
        XCTAssertEqual(ManuscriptTarget.fanqie.wordCountRule, "按正文计，不含标题")
        XCTAssertEqual(ManuscriptTarget.qidian.wordCountRule, "按正文计，标题单独计")
        XCTAssertEqual(ManuscriptTarget.jinjiang.wordCountRule, "按正文计，标题单独计")

        XCTAssertNotNil(ManuscriptTarget.qidian.chapterWordRange)
        XCTAssertNil(ManuscriptTarget.fanqie.chapterWordRange)
        XCTAssertNil(ManuscriptTarget.jinjiang.chapterWordRange)
        XCTAssertTrue(ManuscriptTarget.qidian.chapterWordRange?.contains(2000) == true)
        XCTAssertTrue(ManuscriptTarget.qidian.chapterWordRange?.contains(20001) == false)
    }

    /// The cap's VALUE is the load-bearing fact (= the published rule is
    /// "one chapter at most 20,000 characters"), = so the number is
    /// pinned and not merely the range's SHAPE.
    ///
    /// = Without this, any cap in [2,000, 20,000] passes (= and the
    /// panel then warns a writer about a rule the platform never
    /// published).
    func testThePublishedCapIsTheNumberThePlatformPublished() {
        XCTAssertEqual(ManuscriptTarget.qidian.chapterWordRange?.lowerBound, 0)
        XCTAssertEqual(ManuscriptTarget.qidian.chapterWordRange?.upperBound, 20000)
    }

    /// The warning fires for a count OUTSIDE the published range, = and
    /// only for that (= the decision is the model's, = so a test can
    /// reach it at all).
    func testTheWarningFiresOnlyForACountOutsideThePublishedRange() {
        XCTAssertNil(ManuscriptTarget.qidian.chapterWordCountWarning(for: 0))
        XCTAssertNil(ManuscriptTarget.qidian.chapterWordCountWarning(for: 20000))
        XCTAssertNotNil(ManuscriptTarget.qidian.chapterWordCountWarning(for: 20001))
    }

    /// A target that publishes no per-chapter rule earns NO warning, =
    /// because the app has no number to check against.
    func testATargetWithNoPublishedRuleEarnsNoWarning() {
        XCTAssertNil(ManuscriptTarget.fanqie.chapterWordCountWarning(for: 20001))
        XCTAssertNil(ManuscriptTarget.jinjiang.chapterWordCountWarning(for: 20001))
    }

    /// A frontmatter-shaped block with a FULL-WIDTH colon is NOT
    /// frontmatter.
    ///
    /// = The rule that strips a Chinese key reads the key as the text
    /// before the FIRST ASCII colon. = A full-width colon (= U+FF1A) is
    /// not a YAML colon, = so `标题：第一章` is a PROSE line, = and a
    /// block of prose between two rules is the author's own (= the
    /// rule that a body which opens with a rule and carries prose
    /// between two rules is not frontmatter).
    ///
    /// = So the block SURVIVES, = and the manuscript carries it.
    ///
    /// MUTATION: = accept a full-width colon as the key's separator
    /// (= `firstIndex(of: ":") ?? firstIndex(of: "\u{FF1A}")`) = =
    /// would strip the block, = and this test goes red.
    func testAFullWidthColonBlockIsNotFrontmatter() {
        let body = """
        ---
        标题：第一章
        作者：文枢
        ---

        第一段。
        """

        let manuscript = ManuscriptShaper.manuscript(body: body, target: .qidian)
        XCTAssertTrue(
            manuscript.contains("标题：第一章"),
            "a full-width colon is not a YAML colon, = so the block is the author's prose and it stays"
        )
        XCTAssertTrue(manuscript.contains("作者：文枢"))
        XCTAssertTrue(manuscript.contains("第一段。"))
    }
}
