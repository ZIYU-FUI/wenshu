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
    ///
    /// Everything here is a BAN, not a description. The measured
    /// failure was a draw that turned the pale paper of the still
    /// into a wall and a table with a hard beam of window light, so
    /// the light changed and the colour warmed. "The light stays soft
    /// and even" is a description of the light and did not stop
    /// either: a model reads a description as something it may
    /// arrange. It reads a ban as a rule.
    ///
    /// The camera list names "no roll" and "no zoom" because the
    /// measured move was a sideways pan and a push, and neither word
    /// was in the list.
    static let head = """
        The camera is completely locked: no push, no pull, no pan, no tilt, no roll, no zoom, no shake, no cut, no change of framing. The composition, the objects, the background, the light and the colour stay exactly as they are in the first frame.
        """

    /// The tail of the prompt.
    ///
    /// The ground is named as "the ground", not as paper and not as a
    /// table: the picture's ground is decided by the art direction
    /// (a plain light ground), and a prompt that names the wrong one
    /// asks the model to redraw the picture.
    ///
    /// The movement carries a MAGNITUDE, not a mood. "Slow subtle
    /// movement" is a hint; "a few millimetres at most, a barely
    /// perceptible sway" is a size, and a model reads a size as a
    /// size. The forbidden words are there for the same reason: the
    /// model matches "sweep" to a sweep.
    static let tail = """
        The movement is slight and minimal. Every moving thing shifts by a few millimetres at most: a slight, barely perceptible sway, never a sweep, never a swing, never a change of pose. The movement is slow and continuous.
        The light does not change: no new light, no shadow moves, no beam of sunlight appears, and the white of the paper stays the same white. The colour temperature does not change: nothing warms up, nothing cools down, no hue shifts. Nothing appears, nothing disappears, nothing is added or removed. The ground stays exactly as it is in the first frame.
        """

    /// The sentence that names what moves, and by how much.
    ///
    /// The movement is a CYCLE, because the clip ends on the picture
    /// it started from: the endpoint is given the same still as the
    /// first and the last frame, so the model has to come back. Saying
    /// so in the motion sentence gives it the arc to plan.
    static func movingLine(_ things: [String]) -> String {
        """
        These move, and only these move: \(things.joined(separator: "; ")). Each of them \
        moves by a few millimetres at most, a slight, barely perceptible sway that drifts \
        and returns to where it started.
        """
    }

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
            lines.append(movingLine(moving))
        }
        let holding = plan.holding.map(\.thing)
        if !holding.isEmpty {
            lines.append("These do not move at all: \(holding.joined(separator: "; ")).")
        }
        lines.append(tail)

        return lines.joined(separator: "\n")
    }
}
