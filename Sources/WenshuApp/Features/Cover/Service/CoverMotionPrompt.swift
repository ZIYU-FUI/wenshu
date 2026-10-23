//
//  Features/Cover/Service/CoverMotionPrompt.swift
//
//   : CoverMotionPrompt.
//  Builds the clip's prompt out of a motion plan.
//
//  Pure: the plan goes in and the prompt comes out, so the prompt can
//  be read in a test without a model and without a network.
//
//  The shape of the prompt is fixed and the content of it is not.
//  The fixed part carries the three things the measurement showed the
//  endpoint needs:
//
//  - the endpoint's own fixed-camera instruction, `[fixed]`, which is
//    one of the fifteen camera instructions its documentation names.
//    Measured 2026-10-23: without it the camera drifts across a
//    still life;
//  - the plain-language restatement of it, because the endpoint also
//    reads natural language and the two together are stronger than
//    either alone;
//  - the closing constraint that the ground stays the ground. The
//    measurement caught the model inventing a table, a wall and a
//    hard beam of sunlight that were not in the still, so the picture
//    and the clip were two different pictures.
//
//  The variable part is the plan: what moves, what holds still, and
//  how the breeze passes through. That is what makes the clip the
//  same picture rather than a guess.
//

import Foundation

/// Builds the clip's prompt from a plan.
enum CoverMotionPrompt {

    /// The fixed-camera instruction, in the endpoint's own form.
    ///
    /// The endpoint's documentation names fifteen camera instructions
    /// in this bracketed form, and this is the one that says "do not
    /// move the camera".
    static let fixedCameraInstruction = "[固定]"

    /// The head of the prompt.
    static let head = """
        The camera is completely locked: no push, no pull, no pan, no tilt, no shake, no cut, no change of framing. The composition, the objects and the background stay exactly as they are in the first frame.
        """

    /// The tail of the prompt.
    ///
    /// The ground is named as "the ground", not as paper and not as a
    /// table: the picture's ground is decided by the art direction
    /// (a plain light ground), and a prompt that names the wrong one
    /// asks the model to redraw the picture.
    static let tail = """
        The movement is small, slow and continuous, like watching a real breeze from a seat at the table. Nothing appears, nothing disappears, nothing is added or removed. The light stays soft and even, and the ground stays exactly as it is in the first frame: no new scenery appears (no wall, no window, no furniture, no hard beam of sunlight).
        """

    /// Builds the prompt.
    ///
    /// - Parameter plan: what the breeze may move, what must hold
    ///   still, and how it passes through.
    static func make(plan: CoverMotionPlan) -> String {
        var lines: [String] = []

        let picture = plan.picture.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("\(fixedCameraInstruction) \(picture.isEmpty ? "a still life" : picture).")
        lines.append(head)
        lines.append(plan.wind)

        let moving = plan.moving.map(\.thing)
        if !moving.isEmpty {
            lines.append("These move, and only these move: \(moving.joined(separator: "; ")).")
        }
        let holding = plan.holding.map(\.thing)
        if !holding.isEmpty {
            lines.append("These do not move at all: \(holding.joined(separator: "; ")).")
        }
        lines.append(tail)

        return lines.joined(separator: "\n")
    }
}
