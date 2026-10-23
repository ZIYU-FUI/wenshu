//
//  Features/Cover/Service/CoverArtDirection.swift
//
//   : CoverArtDirection.
//  The ONE art direction every generated cover shares.
//
//  The style lives here, in one constant, and the model is told only
//  WHAT to draw. That is the whole point: the model supplies the
//  subject, and this file supplies the look. If the style travelled
//  with the subject, every card would drift into its own visual
//  language and the material zone would stop reading as one set.
//
//  The text below is the one that was checked against the live image
//  endpoint on 2026-10-23, in four rounds, after the boss showed what
//  the covers were missing: the old direction filled the frame with a
//  busy scene, and the boss wanted the Chinese scroll look (= a
//  dimensional subject floating on pale paper, with air around it).
//
//  What the live endpoint taught, and the reason the text reads the way
//  it does:
//  - "flowing water" pulls the water and the clouds to the BOTTOM of
//    the picture (= the style's own convention), so the bottom is left
//    alone,
//  - the subject has to be PLACED (= "in the middle of the picture"),
//    because a negative instruction alone is ignored,
//  - the model writes a small signature wherever it likes (= a red
//    inscription in a corner), so the text allows that one and forbids
//    the rest,
//  - the picture's own title must NOT be in the artwork: the card
//    writes the title over the picture, and an image model cannot
//    write it legibly,
//  - a subject that names a night or a rite gets painted as a dark
//    full-frame scene, whatever the style says. The light has to be
//    stated (= "in bright daylight under a clear pale sky"),
//  - a subject whose text reads like a plan or an outline gets
//    painted as a DOCUMENT, with English headings and columns. So the
//    picture is ruled out by name (= never a document, a slide, a
//    poster, a diagram, a screenshot or an interface),
//  - the sentence that says the subject is CENTERED and COMPLETE with
//    air on every side is load-bearing, and so is "a confident
//    illustrative finish". Cutting them (to save characters for the
//    subject) made the model paint a photorealistic close-up portrait
//    that filled the frame. A prompt can fail on a word.
//  - the provider takes a prompt shorter than 1500 characters, and
//    the art direction is already long, so the subject is the part
//    that gets cut. The art direction is never cut: the art is the
//    part that must not change,
//  - the emptiness is what the boss asked for, and it is NOT a pale
//    backdrop with a picture on it: the picture IS the emptiness, the
//    big open space the eye rests in (= 留白). So the text says
//    "generous empty space", and it says NOTHING about paper or a
//    cream ground.
//
//  It also carries the negative constraints, because the failure mode
//  of an image model is to imitate a franchise. The instruction is
//  explicit that the result must be original.
//
//  The framing instruction at the end matters mechanically: the
//  provider generates 1024x768 and the crop to 768x576 happens
//  locally, so the subject is asked to sit centred with headroom
//  above it, and the crop takes the sides rather than the top.
//
//  The tile's shape is the card's shape (= 4:3, and the card's
//  picture fills the card with the title on it), so the picture is
//  asked for in the shape it is finally shown in, and the lower left
//  is asked to be calm, because that is where the title sits.
//

import Foundation

/// The unified art direction for every generated cover.
enum CoverArtDirection {

    /// The style every cover is drawn in.
    ///
    /// The slots are filled from the document's motifs (= the
    /// culture, the words that name that culture's picture, the
    /// objects, the colours, the mood). Everything else is the same
    /// for every cover, which is what makes the material zone read
    /// as one set.
    static let styleTemplate = """
        插画设计，纯白背景上的立体插画，{register}风格，立体质感，明亮色彩，高级晕染。\
        极简插画风格，{style}：一组主体紧凑聚拢在画面正中，像一束插花。\
        四周留白占据整个画布的一半以上（超过百分之五十），留白处必须完全空白，\
        画面里再没有别的景物。每一个实体只画一个，不要重复。\
        {subject}。花草和松枝只贴在主体上，像插花的一部分，不散开到四周。细腻的{brush}，精致细节，清晰的线条结构，\
        晕染，空灵清透，烟雾流体，明亮的{palette}配色，{mood}的氛围，平衡简洁的布局。\
        这是一张纯插画，不是中国画、不是手卷、不是挂轴作品：画面上没有题字、印章、落款、\
        签名、水印，也没有任何一处文字。
        """

    /// Joins the art direction and a document's motifs into the
    /// prompt that goes to the image model.
    ///
    /// The art direction comes FIRST, so the model reads the frame
    /// and the look before it reads what to draw, and the subject
    /// inside it, so the instruction that names the subject is the
    /// most recent thing the model has seen.
    ///
    /// The most characters the image provider will take.
    ///
    /// It answers "invalid params, prompt length must be less than
    /// 1500" (= status 2013) when the prompt is longer, and the
    /// motifs are the part that grows: a book's summary is a
    /// paragraph, and the art direction is already long. So the
    /// motifs are cut to whatever fits, and the art direction is
    /// never touched (= the art is the part that must not change).
    static let providerPromptLimit = 1500

    /// - Parameters:
    ///   - title: the document's title (= the name of the thing the
    ///     picture is an impression of).
    ///   - motifs: what the picture is made of.
    static func prompt(title: String, motifs: CoverMotifs) -> String {
        let subject = "\(title)印象（\(motifs.motifs.joined(separator: "、"))）：\(motifs.arrangement)"
        let palette = motifs.palette.isEmpty ? "明亮" : motifs.palette.joined(separator: "、")
        let mood = motifs.mood.isEmpty ? "清雅" : motifs.mood.joined(separator: "、")

        let filled = styleTemplate
            .replacingOccurrences(of: "{register}", with: motifs.register)
            .replacingOccurrences(of: "{style}", with: motifs.style)
            .replacingOccurrences(of: "{brush}", with: motifs.brush)
            .replacingOccurrences(of: "{subject}", with: subject)
            .replacingOccurrences(of: "{palette}", with: palette)
            .replacingOccurrences(of: "{mood}", with: mood)

        // The provider's cap. The motifs are cut, the art is not.
        guard filled.count > providerPromptLimit else { return filled }
        return String(filled.prefix(providerPromptLimit))
    }
}
