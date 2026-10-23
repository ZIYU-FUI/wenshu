//
//  CoverArtDirectionTests.swift · Wenshu
//
//  Proves the art direction is ONE constant, applied in ONE order,
//  and that it carries the constraints the boss asked for.
//
//  The point of this test is the style text: it is asserted
//  BYTE-IDENTICAL to the text the cover pipeline was verified against
//  on 2026-10-23. If someone edits the style in place, the whole
//  material zone's visual language changes, and this test is what
//  says no.
//
//  The rest are the constraint tests. Each of them is a thing that
//  went wrong at the live image endpoint:
//
//  - the empty margin is a NUMBER, because "留白" alone did not hold
//    it and the model painted to the edges,
//  - the subject names the motifs AND the arrangement, because the
//    model draws an arrangement better than it draws a list,
//  - the culture's own words come from the motifs (= the app does
//    not decide what a picture should be called),
//  - the last sentence forbids writing, because every prompt that
//    says nothing about writing comes back with a signature.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover art direction")
struct CoverArtDirectionTests {

    /// The motifs a test draws with.
    static let motifs = CoverMotifs(
        register: "中式",
        style: "宋韵插画",
        brush: "东方水墨笔触",
        motifs: ["牛郎", "织女", "喜鹊桥", "巧果"],
        arrangement: "牛郎织女隔桥相望，巧果置前",
        palette: ["靛蓝", "朱红", "银白"],
        mood: ["浪漫", "静谧"]
    )

    @Test("The style text is byte-identical to the one that was checked")
    func styleIsTheVerifiedText() {
        let expected = """
            插画设计，纯白背景上的立体插画，{register}风格，立体质感，明亮色彩，高级晕染。\
            极简插画风格，{style}：一组主体紧凑聚拢在画面正中，像一束插花。\
            四周留白占据整个画布的一半以上（超过百分之五十），留白处必须完全空白，\
            画面里再没有别的景物。每一个实体只画一个，不要重复。\
            {subject}。花草和松枝只贴在主体上，像插花的一部分，不散开到四周。细腻的{brush}，精致细节，清晰的线条结构，\
            晕染，空灵清透，烟雾流体，明亮的{palette}配色，{mood}的氛围，平衡简洁的布局。\
            这是一张纯插画，不是中国画、不是手卷、不是挂轴作品：画面上没有题字、印章、落款、\
            签名、水印，也没有任何一处文字。
            """

        #expect(CoverArtDirection.styleTemplate == expected)
    }

    @Test("The prompt carries every slot")
    func fillsEverySlot() {
        let prompt = CoverArtDirection.prompt(title: "七夕", motifs: Self.motifs)

        #expect(prompt.contains("中式风格"))
        #expect(prompt.contains("宋韵插画"))
        #expect(prompt.contains("东方水墨笔触"))
        #expect(prompt.contains("牛郎、织女、喜鹊桥、巧果"))
        #expect(prompt.contains("牛郎织女隔桥相望，巧果置前"))
        #expect(prompt.contains("靛蓝、朱红、银白"))
        #expect(prompt.contains("浪漫、静谧"))
        #expect(!prompt.contains("{"))
    }

    @Test("The composition comes first, so the model reads the frame first")
    func compositionComesFirst() {
        let prompt = CoverArtDirection.prompt(title: "七夕", motifs: Self.motifs)

        #expect(prompt.hasPrefix("插画设计，纯白背景上的立体插画"))
        #expect(prompt.hasSuffix("也没有任何一处文字。"))
    }

    @Test("The empty margin is a number, and the writing is forbidden")
    func carriesTheHardConstraints() {
        let prompt = CoverArtDirection.prompt(title: "七夕", motifs: Self.motifs)

        #expect(prompt.contains("四周留白占据整个画布的一半以上"))
        #expect(prompt.contains("留白处必须完全空白"))
        #expect(prompt.contains("每一个实体只画一个"))
        #expect(prompt.contains("像插花的一部分，不散开到四周"))
        #expect(prompt.contains("没有题字"))
        #expect(prompt.contains("印章"))
        #expect(prompt.contains("不是中国画"))
    }

    @Test("A long subject is cut, and the art direction is not")
    func longSubjectIsCutToTheProviderLimit() {
        let long = CoverMotifs(
            register: "中式",
            style: "宋韵插画",
            brush: "东方水墨笔触",
            motifs: Array(repeating: "一个非常非常长的实体名字", count: 40),
            arrangement: String(repeating: "摆法", count: 200),
            palette: ["靛蓝"],
            mood: ["静谧"]
        )

        let prompt = CoverArtDirection.prompt(title: "七夕", motifs: long)

        #expect(prompt.count <= CoverArtDirection.providerPromptLimit)
        #expect(prompt.hasPrefix("插画设计，纯白背景上的立体插画"))
        #expect(prompt.contains("四周留白占据整个画布的一半以上"))
    }

    @Test("The culture's own words are the ones the motifs carry")
    func theCultureIsNotDecidedByTheApp() {
        let japanese = CoverMotifs(
            register: "日式",
            style: "浮世绘",
            brush: "和风笔触",
            motifs: ["鸟居", "樱花", "纸鹤"],
            arrangement: "鸟居居中，樱花两侧，纸鹤在上",
            palette: ["樱粉", "靛蓝"],
            mood: ["幽静"]
        )

        let prompt = CoverArtDirection.prompt(title: "赏花", motifs: japanese)

        #expect(prompt.contains("日式风格"))
        #expect(prompt.contains("浮世绘"))
        #expect(prompt.contains("和风笔触"))
    }
}
