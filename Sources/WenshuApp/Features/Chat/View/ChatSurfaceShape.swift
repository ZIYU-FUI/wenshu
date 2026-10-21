//
//  ChatSurfaceShape.swift
//
//  One outline for every chat surface (= the composer field + the
//  outgoing message band). The radius tracks half the surface height
//  up to a cap, so a short surface reads as a capsule and a grown
//  surface stays a rounded rectangle (= never an ellipse the glyphs
//  spill out of).
//

import SwiftUI

/// Shared chat-surface outline.
///
/// The composer field and the user's own message band wear this shape,
/// so the two surfaces agree by construction instead of by coincidence.
/// The radius = min(half the height, the resting-height cap): a short
/// surface reads as the canonical Apple Messages capsule, a surface
/// that grew stays a rounded rectangle.
struct ChatSurfaceShape: Shape {
    /// Maximum corner radius (= half of the 36 PT resting chat-surface
    /// height `DesignTokens.controlHeightLarge`; = the canonical Apple
    /// Messages "rounded chip" cap).
    private let maxCorner: CGFloat

    @MainActor
    init() {
        maxCorner = DesignTokens.controlHeightLarge / 2
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height / 2, maxCorner)
        return Path(roundedRect: rect, cornerRadius: radius)
    }
}
