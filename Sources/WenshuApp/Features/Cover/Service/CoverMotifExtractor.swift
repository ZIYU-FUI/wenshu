//
//  Features/Cover/Service/CoverMotifExtractor.swift
//
//   : CoverMotifExtractor.
//  Reduces a document to the objects its picture is made of.
//
//  This is the first of the two steps that draw a cover:
//
//    1. THE EXTRACTION (this file): a text call that turns a
//       document into three or four drawable objects, the culture
//       they belong to, the words that name that culture's picture
//       (= its medium and its brushwork), how the objects sit
//       together, their colours and their mood,
//    2. THE DRAWING (CoverArtDirection + CoverImageGenerator): the
//       fixed art direction with those ingredients in it.
//
//  The extraction is what makes the picture work. Handed the whole
//  document, the image model paints a landscape and drops most of
//  what it was asked for; handed three or four concrete objects and
//  one arrangement, it paints exactly those, in one group, on a
//  clean ground.
//
//  The culture's own words are asked for here, rather than decided
//  in the app, because the app cannot know what a Japanese festival
//  should be painted in. The answer is the model's to give.
//
//  The call goes to the chat model the USER picked (= the same
//  provider and model the app chats with), so a cover costs the
//  user's own chat quota and needs no configuration of its own.
//

import Foundation
import WenshuAgent

/// Turns a document into the materials its picture is drawn from.
protocol CoverMotifExtracting: Sendable {
    /// - Parameters:
    ///   - title: the document's title.
    ///   - summary: the document's short summary.
    func extract(title: String, summary: String) async throws -> CoverMotifs
}

/// What can go wrong while extracting.
enum CoverMotifError: Error, LocalizedError {
    /// The chat model could not be reached.
    case noConnector(String)
    /// The model answered, but not with anything usable.
    case unreadableAnswer(String)
    /// The model ran out of budget before it answered.
    ///
    /// This is not the same as an empty answer. A thinking model
    /// reasons out of the same budget as the answer, so a budget that
    /// is too small for the reasoning leaves the response with a
    /// thinking block and no answer at all. The distinction matters
    /// because the sidecar's `lastError` is what the next reader of a
    /// failed cover sees.
    case answerTruncated(String)

    var errorDescription: String? {
        switch self {
        case .noConnector(let slug):
            return "No chat model is available to describe the cover (\(slug))."
        case .unreadableAnswer(let raw):
            return "The cover description could not be read: \(raw.prefix(120))"
        case .answerTruncated(let detail):
            return "The cover description was cut off before the model answered: \(detail)"
        }
    }
}

/// The extraction, over the app's own chat model.
struct CoverMotifExtractor: CoverMotifExtracting {

    /// The prompt that asks for the reduction.
    ///
    /// It asks for a fixed, small shape, because a list the image
    /// model can draw is the whole point. The count is capped at
    /// four: asked for six, the model draws three or four of them
    /// and spends the rest of the frame on scenery.
    ///
    /// The culture's medium and brushwork are asked for in words,
    /// so the app never has to guess them (= the model is told to
    /// name the way that culture paints, not to pick from a list).
    static let prompt = """
    你是一位美术指导。给你一篇文档，请把它"提炼"成一张插画所需的素材清单。

    规则：
    1. 先判断这篇文档的文化归属，只能是三者之一：中式、日式、欧美。看内容里的节俗、器物、地名、传说，不要看文字是哪种语言。
    2. 用这个文化的说法，写出这一类画面叫什么（例如中式的"七夕乞巧陈设"、日式的"花见静物"、欧美的"冬季节庆陈设"）。它是一组**摆在桌上的东西**，不是一幅挂在墙上的画，所以不要用"卷""轴""壁画"这类说法。还要写出它的笔触的说法（例如"工笔重彩笔触"、"浮世绘勾线套色笔触"）。写你认为最贴切的说法，不要写"中国风""日式风"这种笼统词。
    3. 提炼 3 到 4 个"能画出来的具体实体"（名词，不是动作，不是抽象概念）。宁少勿多：超过四个，模型只会画出一半。
    4. 每个实体都要是一个可以单独放在一束花里的物件，能自己站住、自己成形。不要选天生会横铺满画面的东西（整条树枝、河流、山脉、长桥、星空），要选其中可以捧在手里的一小件（例如"一枝樱花"而不是"樱花树"，"一盏河灯"而不是"河面"）。这个选择决定了画面能不能收成一组。
    5. 给一句"怎么摆"的短句（不超过 24 字），必须**点名每一个实体**（写"牛郎与织女"，不要写"二人"），并说明它们怎么在一组里相处。如果有两个实体长得像，要写清怎么区分（例如"白羊在右，黄牛居中"）。
    6. 不要选"本身带文字"的物件（手卷、字帖、书信、招牌、匾额、写经的纸、刻着字的器物）。这一条同样决定了画面能不能干净。
    7. 给 2 到 3 个颜色词，以及 1 到 2 个氛围词。

    只输出下面这一行 JSON，不要解释，不要多余文字，每个字段只写一次：
    {"register":"中式|日式|欧美","style":"这一类插画的名称","brush":"这一类笔触的说法","motifs":["实体1","实体2","实体3","实体4"],"arrangement":"怎么摆","palette":["色1","色2"],"mood":["氛围词"]}
    """

    /// The provider the extraction talks to (= the user's chat provider).
    private let providerSlug: @Sendable () -> String?

    /// The model the extraction talks to (= the user's chat model).
    private let modelSlug: @Sendable () -> String?

    /// Builds the connector (= the app's own factory, so the shape of
    /// the request matches the provider the user configured).
    private let connectorFor: @Sendable (String) -> (any LLMConnector)?

    init(
        providerSlug: @escaping @Sendable () -> String? = {
            UserDefaults.standard.string(forKey: "wenshu.llm.provider")
        },
        modelSlug: @escaping @Sendable () -> String? = {
            WenshuAppDelegateLLMHelpers.activeModelSlug()
        },
        connectorFor: @escaping @Sendable (String) -> (any LLMConnector)? = { slug in
            WenshuAppDelegateLLMHelpers.connectorForSlug(slug)
        }
    ) {
        self.providerSlug = providerSlug
        self.modelSlug = modelSlug
        self.connectorFor = connectorFor
    }

    /// The token budget the extraction asks for.
    ///
    /// The chat model is a THINKING model: it reasons before it
    /// answers, and the reasoning comes out of the same budget as the
    /// answer. Measured 2026-10-23 against MiniMax-M3.1-Flash on the
    /// document whose cultural register is hardest to decide (an
    /// outline template, which is a technical document with no
    /// customs in it): at 2000 the whole budget went to the thinking
    /// (thinking_tokens 1999) and the answer never arrived; at 8000
    /// the same document answered normally (1623 output tokens, 1527
    /// of them thinking).
    ///
    /// So the budget has to hold the reasoning AND the answer. It is
    /// a cap, not a cost: the model spends what it spends.
    static let answerTokenBudget = 8000

    func extract(title: String, summary: String) async throws -> CoverMotifs {
        let slug = providerSlug() ?? Provider.minimaxCn.slug
        guard let connector = connectorFor(slug) else {
            throw CoverMotifError.noConnector(slug)
        }
        let model = modelSlug() ?? "MiniMax-M3"

        let question = "标题：\(title)\n内容：\(summary)"
        let response = try await connector.send(
            messages: [LLMMessage.user(question)],
            options: LLMCallOptions(
                model: model,
                maxTokens: Self.answerTokenBudget,
                systemPrompt: Self.prompt,
                temperature: 0.3
            )
        )

        // A thinking model that ran out of budget leaves a thinking
        // block and no answer. That is a CUT-OFF answer, not an empty
        // one, and it has to be said as itself: the empty-answer
        // error reads like the model wrote nonsense, which sends the
        // next reader looking in the wrong place.
        if response.stopReason == .maxTokens {
            throw CoverMotifError.answerTruncated(
                "the model used its whole budget of \(response.usage.outputTokens) tokens and did not answer"
            )
        }

        let text = response.blocks
            .compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }
            .joined(separator: "\n")

        return try Self.parse(text)
    }

    /// Reads the answer.
    ///
    /// A model that was told to answer with one line of JSON
    /// sometimes wraps it in a sentence or a code fence, so the
    /// object is looked for inside the answer rather than assumed to
    /// be the whole of it.
    static func parse(_ text: String) throws -> CoverMotifs {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw CoverMotifError.unreadableAnswer(text)
        }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8) else {
            throw CoverMotifError.unreadableAnswer(text)
        }

        // The answer is read by hand, not decoded by a struct: a
        // model that was told to answer with one line of JSON
        // sometimes answers with a key twice (= the live endpoint
        // did: "palette" and "mood" both appeared twice), and
        // sometimes writes one colour as a bare string where the
        // shape asks for a list. A strict decoder turns either into
        // a failed cover; this reads what is there.
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoverMotifError.unreadableAnswer(text)
        }
        let motifs = Self.words(object["motifs"])
        guard !motifs.isEmpty else {
            throw CoverMotifError.unreadableAnswer(text)
        }

        // The words that name the culture's picture. A model that
        // leaves them out still has to be drawable, so they fall back
        // to the register's own word (= the app does not decide what
        // the picture is called, it only fills the blank).
        let register = Self.word(object["register"])
        let style = Self.word(object["style"])
        let brush = Self.word(object["brush"])
        let arrangement = Self.word(object["arrangement"])

        return CoverMotifs(
            register: register.isEmpty ? "东方" : register,
            style: style.isEmpty ? "\(register)插画" : style,
            brush: brush.isEmpty ? "手绘线描" : brush,
            motifs: Array(motifs.prefix(4)),
            arrangement: arrangement.isEmpty ? "聚拢在画面正中" : arrangement,
            palette: Self.words(object["palette"]),
            mood: Self.words(object["mood"])
        )
    }

    /// One cleaned word, or an empty string.
    private static func word(_ value: Any?) -> String {
        guard let text = value as? String else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A list of cleaned words, from a list or from one word.
    ///
    /// A model that names one colour sometimes writes it as a bare
    /// string instead of a one-item list, and a list of two is
    /// sometimes separated by a comma inside one string.
    private static func words(_ value: Any?) -> [String] {
        var raw: [String] = []
        if let list = value as? [Any] {
            raw = list.compactMap { $0 as? String }
        } else if let text = value as? String {
            raw = text.split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" })
                .map(String.init)
        }
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
