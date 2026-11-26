//
//  ChatSurfaceShape.swift
//
//  The outline the chat input field wears, shared with the
//  inspector's output sheet. The radius tracks half the surface
//  height, so a surface at the resting chat height reads as a
//  capsule; the cap only binds on a surface far taller than any
//  chat surface. The outgoing message band is not one of them.
//

import SwiftUI

/// The chat input field's capsule outline.
///
/// The composer field wears this shape; the outgoing message band
/// does not (= that band is clipped to a rounded rectangle at
/// `DesignTokens.surfaceCornerRadiusCard`). The radius = min(half
/// the height, the cap): a field at its resting height rounds its
/// ends all the way (= a true capsule), and only a surface grown
/// past the cap stays a rounded rectangle (= never a stadium the
/// glyphs spill out of).
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
