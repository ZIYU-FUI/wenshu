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
//    poster, a diagram, a screenshot or an interface).
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
        Create original bright whimsical hand-painted Chinese-style fantasy scroll \
        paintings with playful tavern-card-game energy; never imitate an existing \
        franchise, character, card frame, logo or official illustration. Render \
        the subject as one dimensional layered scroll painting, softly embossed \
        and built from a few clear planes of depth, floating on a clean pale cream \
        ground. The whole painting is in bright daylight under a clear pale sky, \
        and nothing in it is dark or night-time. The painting sits in the middle \
        of the paper and pale empty paper stays visible on all four sides, so the \
        picture breathes instead of filling the frame. Place the subject in the \
        middle of the picture, and leave the whole lower third of the picture as \
        bare empty paper, with no water, no clouds, no rocks and no plants along \
        the bottom edge, and nothing at all in the lower left corner, because a \
        title is read over that space. Use soft ink-wash mountains and mist in the \
        far distance, broad painterly brushwork, saturated warm color masses, rich \
        midtones, tactile painted materials, a little gold, and a confident \
        illustrative finish. Poster tile framing in a 4:3 picture, the subject \
        centered and complete with air on every side. A small artist's seal in one \
        corner is the only writing allowed. This is a painted picture, never a \
        document, a slide, a poster, a diagram, a screenshot or an interface, and \
        it contains no written words at all.
        """

    /// Joins the art direction and the subject into the prompt that
    /// goes to the image model.
    ///
    /// The art direction comes FIRST, so the model reads the style
    /// before it reads what to draw, and the subject LAST, so the
    /// instruction that names the subject is the most recent thing the
    /// model has seen.
    static func prompt(subject: String) -> String {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return style }
        return style + " " + trimmed
    }
}
