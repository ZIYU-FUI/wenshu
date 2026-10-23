//
//  CoverMotifExtractorTests.swift · Wenshu
//
//  Proves the reduction of a document to its motifs, WITHOUT a
//  network call.
//
//  The reduction is the half of the cover pipeline that decides
//  whether the picture works, so its shape is asserted here:
//
//  - the answer is one line of JSON, and the reader finds the object
//    inside a sentence or a code fence if the model wrapped it,
//  - the motifs are capped at four, because asked for six the image
//    model draws three of them and spends the rest of the frame on
//    scenery,
//  - the culture's own words are read from the answer, because the
//    app does not decide what a picture should be called,
//  - an answer with no motifs is an error, not an empty picture.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover motif extraction")
struct CoverMotifExtractorTests {

    @Test("A clean answer is read as it stands")
    func readsACleanAnswer() throws {
        let motifs = try CoverMotifExtractor.parse(
            """
            {"register":"中式","style":"宋韵插画","brush":"东方水墨笔触",\
            "motifs":["牛郎","织女","喜鹊桥","巧果"],\
            "arrangement":"牛郎织女隔桥相望，巧果置前",\
            "palette":["靛蓝","朱红","银白"],"mood":["浪漫","静谧"]}
            """
        )

        #expect(motifs.register == "中式")
        #expect(motifs.style == "宋韵插画")
        #expect(motifs.brush == "东方水墨笔触")
        #expect(motifs.motifs == ["牛郎", "织女", "喜鹊桥", "巧果"])
        #expect(motifs.arrangement == "牛郎织女隔桥相望，巧果置前")
        #expect(motifs.palette == ["靛蓝", "朱红", "银白"])
        #expect(motifs.mood == ["浪漫", "静谧"])
    }

    @Test("The object is found inside a wrapper")
    func findsTheObjectInsideAWrapper() throws {
        let motifs = try CoverMotifExtractor.parse(
            """
            好的，这是清单：
            ```json
            {"register":"日式","style":"浮世绘","brush":"和风笔触",\
            "motifs":["鸟居","樱花","纸鹤"],"arrangement":"鸟居居中",\
            "palette":["樱粉"],"mood":["幽静"]}
            ```
            """
        )

        #expect(motifs.register == "日式")
        #expect(motifs.style == "浮世绘")
        #expect(motifs.motifs == ["鸟居", "樱花", "纸鹤"])
    }

    @Test("More than four motifs are cut, because the model draws three")
    func capsTheMotifsAtFour() throws {
        let motifs = try CoverMotifExtractor.parse(
            """
            {"register":"中式","style":"宋韵插画","brush":"东方水墨笔触",\
            "motifs":["一","二","三","四","五","六"],"arrangement":"聚拢",\
            "palette":["靛蓝"],"mood":["静谧"]}
            """
        )

        #expect(motifs.motifs.count == 4)
        #expect(motifs.motifs == ["一", "二", "三", "四"])
    }

    @Test("An answer with no motifs is an error")
    func anEmptyAnswerIsAnError() {
        #expect(throws: CoverMotifError.self) {
            try CoverMotifExtractor.parse("{\"register\":\"中式\",\"motifs\":[]}")
        }
        #expect(throws: CoverMotifError.self) {
            try CoverMotifExtractor.parse("I could not do that.")
        }
    }

    @Test("A missing culture word falls back to the register's own")
    func aMissingCultureWordFallsBack() throws {
        let motifs = try CoverMotifExtractor.parse(
            """
            {"register":"欧美","motifs":["三脚架","天幕","松树"],\
            "arrangement":"三脚架居中","palette":["赭石"],"mood":["开阔"]}
            """
        )

        // The app fills the blank; it does not decide the picture's
        // name.
        #expect(motifs.style == "欧美插画")
        #expect(motifs.brush == "手绘线描")
    }

    @Test("The answer the live endpoint gave is read, duplicate keys and all")
    func readsTheLiveEndpointAnswer() throws {
        // The live endpoint answered with "palette" and "mood" twice,
        // and the first "palette" was a bare string where the shape
        // asks for a list. A strict decoder fails here, and a failed
        // parse is a failed cover.
        let motifs = try CoverMotifExtractor.parse(
            """
            {"register":"中式","style":"七夕乞巧案头陈设","brush":"工笔重彩笔触",\
            "motifs":["七巧果","乞巧彩线","织女星灯","牛郎竹偶"],\
            "arrangement":"七巧果居左，织女星灯居右，牛郎竹偶居中，彩线绕果",\
            "palette":"朱红","mood":["清雅","梦幻"],"palette":["靛蓝","银白"],\
            "mood":["清雅","梦幻"]}
            """
        )

        #expect(motifs.register == "中式")
        #expect(motifs.style == "七夕乞巧案头陈设")
        #expect(motifs.motifs == ["七巧果", "乞巧彩线", "织女星灯", "牛郎竹偶"])
        // The FIRST occurrence is the one that survives (= what
        // JSONSerialization keeps), so the palette is the bare colour
        // the model wrote first, and it is still a usable palette.
        #expect(motifs.palette == ["朱红"])
        #expect(motifs.mood == ["清雅", "梦幻"])
    }

    @Test("One colour written as a bare string is still a colour")
    func readsOneColourAsAString() throws {
        let motifs = try CoverMotifExtractor.parse(
            """
            {"register":"中式","motifs":["一盏灯","一枝梅"],\
            "arrangement":"灯在左，梅在右","palette":"朱红","mood":[]}
            """
        )

        #expect(motifs.palette == ["朱红"])
        #expect(motifs.mood.isEmpty)
    }

    @Test("The prompt asks for a small, drawable set")
    func thePromptAsksForASmallSet() {
        let prompt = CoverMotifExtractor.prompt

        #expect(prompt.contains("3 到 4"))
        #expect(prompt.contains("中式、日式、欧美"))
        #expect(prompt.contains("motifs"))
        #expect(prompt.contains("style"))
        #expect(prompt.contains("brush"))
    }
}
