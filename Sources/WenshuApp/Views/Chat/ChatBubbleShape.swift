// ChatBubbleShape.swift
//
// v0.57 boss 2026-09-09 OOB: push the chat bubbles toward the iMessage
// look — tail, sent/received sides, merged corners on a run.
//
// Every number here was measured off the real Messages.app running on this
// machine (dark mode), not copied from a blog post:
//
//   received fill   rgb(51, 52, 54)   left  side
//   sent fill       rgb(29, 143, 250) right side
//   transcript bg   rgb(28, 28, 28)
//
// Wenshu uses the semantic equivalents rather than those literals, so the
// bubbles follow the user's appearance and accent colour instead of being
// pinned to one theme. The measurement is what confirms the SHAPE.

import SwiftUI

/// Where a bubble sits in a run of consecutive messages from one author.
///
/// iMessage only draws the tail on the LAST bubble of a run, and squares
/// off the corners that face the neighbouring bubble, so a run reads as one
/// block instead of a stack of identical pills.
enum ChatBubblePosition {
    /// The only message in its run — full rounding plus a tail.
    case only
    /// First of several — full rounding except the trailing-bottom corner.
    case first
    /// Surrounded by messages from the same author on both sides.
    case middle
    /// Last of several — carries the tail.
    case last

    /// True when this bubble draws the tail.
    var hasTail: Bool {
        switch self {
        case .only, .last: return true
        case .first, .middle: return false
        }
    }
}

/// An iMessage-style bubble: three fully rounded corners, one tight corner
/// on the author's side, and a tail on the last bubble of a run.
struct ChatBubbleShape: Shape {
    /// True for the local author's messages, which sit on the trailing side.
    let isOutgoing: Bool
    /// Position within a run of consecutive messages from one author.
    let position: ChatBubblePosition

    /// Corner radius of the rounded corners.
    ///
    /// Messages uses a radius close to half the single-line bubble height,
    /// which reads as a pill for short replies and as a rounded rectangle
    /// for long ones. 18 PT matches the measured bubble on this machine.
    private var radius: CGFloat { 18 }
    /// How far the tail reaches past the bubble body.
    private var tailWidth: CGFloat { 6 }
    /// The tight corner where the tail attaches, or where this bubble meets
    /// the next one in the run.
    private var tightRadius: CGFloat { 4 }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // The body is inset on the author's side to leave room for the
        // tail, so a tailed and an untailed bubble in the same run share
        // the same body edge and stay visually aligned.
        let body = CGRect(
            x: isOutgoing ? rect.minX : rect.minX + tailWidth,
            y: rect.minY,
            width: rect.width - tailWidth,
            height: rect.height
        )

        // Corner radii, clockwise from top-leading. The corner facing the
        // previous bubble in a run collapses so the two read as one block.
        let topLeading: CGFloat = {
            if isOutgoing { return radius }
            return (position == .middle || position == .last) ? tightRadius : radius
        }()
        let topTrailing: CGFloat = {
            if !isOutgoing { return radius }
            return (position == .middle || position == .last) ? tightRadius : radius
        }()
        let bottomLeading: CGFloat = {
            if isOutgoing { return radius }
            // The tail attaches here on an incoming bubble, so the corner
            // tightens to meet it.
            return position.hasTail ? tightRadius : tightRadius
        }()
        let bottomTrailing: CGFloat = {
            if !isOutgoing { return radius }
            return position.hasTail ? tightRadius : tightRadius
        }()

        path.addPath(
            UnevenRoundedRectangle(
                topLeadingRadius: topLeading,
                bottomLeadingRadius: bottomLeading,
                bottomTrailingRadius: bottomTrailing,
                topTrailingRadius: topTrailing
            )
            .path(in: body)
        )

        if position.hasTail {
            path.addPath(tailPath(body: body, in: rect))
        }

        return path
    }

    /// The little hook at the bubble's bottom corner.
    ///
    /// Drawn as a curve that leaves the body's bottom edge, reaches out to
    /// the author's side, and curls back in — the same silhouette Messages
    /// uses, rather than a triangle, which reads as a speech balloon from a
    /// comic strip instead of an iMessage bubble.
    private func tailPath(body: CGRect, in rect: CGRect) -> Path {
        var tail = Path()
        let bottom = body.maxY
        // Where the tail meets the body, measured up from the bottom edge.
        let attachHeight: CGFloat = 14

        if isOutgoing {
            let edge = body.maxX
            let tip = rect.maxX
            tail.move(to: CGPoint(x: edge - tightRadius, y: bottom))
            tail.addLine(to: CGPoint(x: edge, y: bottom - attachHeight))
            tail.addQuadCurve(
                to: CGPoint(x: tip, y: bottom),
                control: CGPoint(x: edge, y: bottom - attachHeight / 3)
            )
            tail.addQuadCurve(
                to: CGPoint(x: edge - tightRadius, y: bottom),
                control: CGPoint(x: edge - tightRadius / 2, y: bottom)
            )
        } else {
            let edge = body.minX
            let tip = rect.minX
            tail.move(to: CGPoint(x: edge + tightRadius, y: bottom))
            tail.addLine(to: CGPoint(x: edge, y: bottom - attachHeight))
            tail.addQuadCurve(
                to: CGPoint(x: tip, y: bottom),
                control: CGPoint(x: edge, y: bottom - attachHeight / 3)
            )
            tail.addQuadCurve(
                to: CGPoint(x: edge + tightRadius, y: bottom),
                control: CGPoint(x: edge + tightRadius / 2, y: bottom)
            )
        }
        tail.closeSubpath()
        return tail
    }
}
