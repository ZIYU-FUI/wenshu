//
//  Features/Cover/Model/CoverMotifs.swift
//
//   : CoverMotifs.
//  What a document's picture is made of.
//
//  A picture model cannot be told "draw this festival". It draws a
//  scene, fills the frame, and drops two of the six motifs it was
//  given. What it CAN do is draw a small, concrete set of objects in
//  one compact group.
//
//  So a document is reduced to its motifs FIRST (a text call, see
//  CoverMotifExtractor), and the picture is drawn from those. The
//  reduction is the part that decides whether the picture works:
//  the same document, reduced to four drawable objects in one
//  arrangement, comes back as one arrangement on a clean ground;
//  handed the whole document, it comes back as a landscape.
//
//  The motifs also carry the CULTURE the objects belong to, because
//  the same festival drawn as a Chinese scroll, as a Japanese print
//  and as a European poster are three different pictures, and which
//  one is right depends on the document, not on the app.
//
//  The culture's own words (= the medium it is painted in, the
//  brushwork it is painted with) come from the same call, because
//  naming them here would be a hardcoded guess about what a
//  Chinese-looking picture should be called. The app fills the
//  blanks; it does not decide.
//

import Foundation

/// The materials a document's picture is drawn from.
struct CoverMotifs: Codable, Equatable, Sendable {

    /// The culture the motifs belong to (= 中式, 日式, 欧美).
    var register: String

    /// The name of the medium in that culture (= 中式插画, 浮世绘, 版画).
    var style: String

    /// The name of the brushwork in that culture (= 东方, 和风, 西式).
    var brush: String

    /// The drawable objects (= three or four of them).
    var motifs: [String]

    /// How the objects sit together (= one short sentence).
    var arrangement: String

    /// The colours (= two or three words).
    var palette: [String]

    /// The mood (= one or two words).
    var mood: [String]

    init(
        register: String,
        style: String,
        brush: String,
        motifs: [String],
        arrangement: String,
        palette: [String],
        mood: [String]
    ) {
        self.register = register
        self.style = style
        self.brush = brush
        self.motifs = motifs
        self.arrangement = arrangement
        self.palette = palette
        self.mood = mood
    }

    /// The subject line for the picture (= what the model is told to
    /// draw).
    ///
    /// The motifs are named, and then the arrangement says how they
    /// sit together, because the model draws the ARRANGEMENT better
    /// than it draws a list.
    var subjectLine: String {
        let names = motifs.joined(separator: "、")
        return "\(motifs.count) 个元素：\(names)。\(arrangement)"
    }
}
