//
//  ChatSurfaceShape.swift
//
//  One outline for every chat surface (= the composer field + the
//  outgoing message bubble). The radius tracks half the surface
//  height, so a surface at the resting chat height reads as a
//  capsule; the cap only binds on a surface far taller than any
//  chat surface.
//

import SwiftUI

/// Shared chat-surface outline.
///
/// The composer field and the user's own message bubble wear this
/// shape, so the two surfaces agree by construction instead of by
/// coincidence. The radius = min(half the height, the cap): a bubble
/// at its resting height rounds its ends all the way (= the canonical
/// Apple Messages capsule), and only a surface grown past the cap
/// stays a rounded rectangle (= never a stadium the glyphs spill
/// out of).
struct ChatSurfaceShape: Shape {
    /// Maximum corner radius (= the resting chat-surface height
    /// `DesignTokens.controlHeightLarge`; = the cap that keeps a very
    /// tall surface from degenerating into a stadium, while a
    /// bubble-sized surface still rounds its ends all the way).
    private let maxCorner: CGFloat

    @MainActor
    init() {
        maxCorner = DesignTokens.controlHeightLarge
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height / 2, maxCorner)
        return Path(roundedRect: rect, cornerRadius: radius)
    }
}
