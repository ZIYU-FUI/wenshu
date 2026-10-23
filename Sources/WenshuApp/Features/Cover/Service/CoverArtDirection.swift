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
    static let style = """
        Create original hand-painted Chinese-style fantasy scroll paintings; never \
        imitate an existing franchise, character, card frame, logo or official \
        illustration. Render the subject as one dimensional layered scroll \
        painting, softly embossed and built from a few clear planes of depth. The \
        whole painting is in bright daylight, and nothing in it is dark or \
        night-time. The painting sits in the middle of the frame and generous \
        empty space stays visible on all four sides, so the picture breathes \
        instead of filling the frame. Place the subject in the middle, and leave \
        the whole lower third empty, with no water, no clouds, no rocks and no \
        plants along the bottom edge, and nothing at all in the lower left corner, \
        because a title is read over that space. Use soft ink-wash mountains and \
        mist in the far distance, broad painterly brushwork, saturated warm color, \
        rich midtones, tactile materials, a little gold, a confident illustrative \
        finish. A small artist's seal in one corner is the only writing allowed. \
        The subject is centered and complete with air on every side. This is a \
        painted picture, never a document, a slide, a poster, a diagram, a \
        screenshot or an interface, and it contains no written words at all.
        """

    /// Joins the art direction and the subject into the prompt that
    /// goes to the image model.
    ///
    /// The art direction comes FIRST, so the model reads the style
    /// before it reads what to draw, and the subject LAST, so the
    /// instruction that names the subject is the most recent thing the
    /// model has seen.
    /// The most characters the image provider will take.
    ///
    /// It answers "invalid params, prompt length must be less than
    /// 1500" (= status 2013) when the prompt is longer, and the
    /// subject is the part that grows: a book's summary is a
    /// paragraph, and the art direction is already long. So the
    /// subject is cut to whatever fits, and the art direction is
    /// never touched (= the art is the part that must not change).
    static let providerPromptLimit = 1500

    static func prompt(subject: String) -> String {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return style }
        let room = providerPromptLimit - style.count - 1
        guard room > 0 else { return style }
        let subjectPart = trimmed.count > room ? String(trimmed.prefix(room)) : trimmed
        return style + " " + subjectPart
    }
}
