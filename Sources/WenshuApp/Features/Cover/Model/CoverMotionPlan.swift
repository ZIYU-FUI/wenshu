//
//  Features/Cover/Model/CoverMotionPlan.swift
//
//   : CoverMotionPlan.
//  What a breeze may move in one picture, and what must hold still.
//
//  The clip's prompt used to be one sentence that said "a breeze",
//  so the model decided what moved and, on a still life, it invented
//  a camera move. The plan replaces that guess with an answer: one
//  entry per motif, saying whether a light breeze may move it.
//
//  The plan is measured, not designed. The picture's own description
//  (= the motifs the picture was drawn from) is the input, and the
//  chat model reads it: on the nine covers in the real library it
//  called the inkstone an inkstone, the Boshan censer a censer whose
//  smoke rises, the river lantern a thing that floats, and the yellow
//  chrysanthemum a chrysanthemum. Five of the nine have nothing that
//  can move at all, and for those the plan puts the wind on the
//  light.
//
//  The "thing" is an ENGLISH phrase, because it goes straight into
//  the English video prompt. The motif's own name is kept beside it,
//  copied exactly as the picture's description has it, so an entry
//  can be matched back to the picture.
//

import Foundation

/// What a breeze may move in one picture.
struct CoverMotionPlan: Codable, Equatable, Sendable {

    /// What kind of thing an item is, by physics.
    ///
    /// The class decides what moves when the picture offers more than
    /// one candidate. The user asked for it directly (= "prefer the
    /// plant, and when there is no plant, let something else move"),
    /// because a plant is what the model renders well: the measured
    /// good clip moved a branch (a corner/whole motion ratio of
    /// 0.06) and the measured bad one drifted the camera (0.94) on a
    /// picture where the model had nothing living to move.
    enum Movability: String, Codable, Equatable, Sendable {

        /// Something that grows: leaves, branches, grass, vines,
        /// flowers, moss, bamboo, pine needles, reeds, a tendril.
        case plant

        /// Something that is only in the air: smoke, steam, mist,
        /// dust in the light.
        case air

        /// Something light and loose: paper, cloth, cord, ribbon,
        /// tassel, hair, a hanging edge, a thread.
        case light

        /// Something solid that stands on a surface: vessels,
        /// pottery, bronze, books, stone, tools, heavy fruit.
        case solid

        /// Whether a breeze may move this kind of thing.
        var moves: Bool {
            self != .solid
        }
    }

    /// One motif, and what the breeze may do with it.
    struct Item: Codable, Equatable, Sendable {

        /// The motif's own name, as the picture's description has it.
        var motif: String

        /// How the thing is identified in the picture, in English.
        ///
        /// It is the phrase that goes into the video prompt, so it
        /// names the thing itself: what it is, what it looks like,
        /// and where it is. When the moving thing is the smoke over a
        /// censer, this names THE SMOKE and not the censer, because
        /// a prompt that says the censer moves gets the censer
        /// slid across the table.
        var thing: String

        /// Whether a light breeze may move it.
        var moves: Bool

        /// What kind of thing it is, by physics.
        ///
        /// It is the safe default that a plan written before the
        /// classification existed reads as (= `solid`), so an old
        /// plan never invents a mover.
        var movability: Movability

        init(
            motif: String,
            thing: String,
            moves: Bool,
            movability: Movability = .solid
        ) {
            self.motif = motif
            self.thing = thing
            self.moves = moves
            self.movability = movability
        }
    }

    /// The whole picture in one English phrase.
    ///
    /// Its style, its medium and its ground (= "a Shang bronze ritual
    /// display of three animal-shaped vessels on an altar"). It goes
    /// into the video prompt, so the prompt does not have to guess a
    /// style: the art direction draws in three cultures and a prompt
    /// that says "Chinese ink-and-colour" is wrong for the other two.
    var picture: String

    /// One entry per motif.
    var items: [Item]

    /// The breeze, in one sentence.
    var wind: String

    init(picture: String, items: [Item], wind: String) {
        self.picture = picture
        self.items = items
        self.wind = wind
    }

    /// The things a breeze may move.
    var moving: [Item] { items.filter(\.moves) }

    /// The things that must hold still.
    var holding: [Item] { items.filter { !$0.moves } }

    /// Which item moves, and where it sits in the plan.
    ///
    /// The clip gets ONE mover, and the picture decides which one:
    ///
    ///  - a PLANT, when the picture has one (= the user asked for a
    ///    plant-growth animation whenever there is a plant to grow);
    ///  - otherwise the lightest thing that can move (= smoke, dust,
    ///    paper, cloth, a cord);
    ///  - otherwise nothing moves (= the wind falls on the light,
    ///    which the plan's wind sentence already says).
    ///
    /// One mover, not a list: a list of movers is what let the model
    /// decide what to animate, and the measured bad clip drifted the
    /// camera because the model had nothing living to move.
    var moverIndex: Int? {
        let candidates = items.enumerated().filter { $0.element.moves }
        if let plant = candidates.first(where: { $0.element.movability == .plant }) {
            return plant.offset
        }
        if let light = candidates.first(where: {
            $0.element.movability == .air || $0.element.movability == .light
        }) {
            return light.offset
        }
        return nil
    }

    /// The one thing that moves.
    var mover: Item? { moverIndex.map { items[$0] } }
}
