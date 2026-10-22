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
//  The text below is the one that was verified against the live
//  image endpoint on 2026-10-22: a generated cover came back painterly
//  and hand-painted, with saturated warm colour and a readable
//  subject, and the banner crop kept the subject whole.
//
//  It also carries the negative constraints, because the failure mode
//  of an image model is to imitate a franchise. The instruction is
//  explicit that the result must be original.
//
//  The framing instruction at the end matters mechanically: the
//  provider generates 1024x512 and the crop to 768x320 happens
//  locally, so the subject is asked to sit centred with headroom on
//  both sides, and the crop takes the sides rather than the top.
//

import Foundation

/// The unified art direction for every generated cover.
enum CoverArtDirection {

    /// The style every cover is drawn in.
    static let style = """
        Create original bright whimsical hand-painted fantasy trading-card key \
        art with playful tavern-card-game energy; never imitate an existing \
        franchise, character, card frame, logo or official illustration. Use \
        broad painterly brushwork, saturated warm color masses, rich \
        midtones, tactile painted materials, lively fantasy worldbuilding \
        and a confident illustrative finish. Wide cinematic banner framing, \
        the subject centered with generous headroom on both sides, designed \
        to be cropped to a wide strip without losing the subject.
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
