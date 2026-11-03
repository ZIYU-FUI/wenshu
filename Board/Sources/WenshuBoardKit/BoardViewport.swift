//
//  BoardViewport.swift
//  WenshuBoard
//
//  The viewport of an infinite canvas: a world coordinate space, and the
//  transform that maps it to the screen.
//
//  Apple ships the pieces (a canvas surface, a magnify gesture, a drag
//  gesture, a scroll geometry) and not the product, so the product is this:
//  one number for the scale, one point for the offset, and the arithmetic
//  that keeps the world under the cursor under the cursor.
//
//  The arithmetic is a pure function of the viewport, which is why it lives
//  here and not in the view: it is the part that can be tested without a
//  window.
//

import CoreGraphics

/// The mapping between a board's world coordinates and the screen.
public struct BoardViewport: Equatable, Sendable {

    /// The world-to-screen scale.
    public var scale: CGFloat
    /// Where the world's origin sits on the screen.
    public var offset: CGPoint

    /// The scale bounds. Below the floor the board cannot be read; above the
    /// ceiling it stops being a board.
    public static let minimumScale: CGFloat = 0.2
    public static let maximumScale: CGFloat = 4.0

    public init(scale: CGFloat = 1, offset: CGPoint = .zero) {
        self.scale = min(max(scale, Self.minimumScale), Self.maximumScale)
        self.offset = offset
    }

    /// The screen point of a world point.
    public func screenPoint(for world: CGPoint) -> CGPoint {
        CGPoint(x: world.x * scale + offset.x, y: world.y * scale + offset.y)
    }

    /// The world point under a screen point.
    public func worldPoint(for screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - offset.x) / scale, y: (screen.y - offset.y) / scale)
    }

    /// The same viewport, zoomed to `newScale` with the world point under
    /// `anchor` staying under `anchor`.
    ///
    /// This is the whole reason a zoom has to be computed and not applied:
    /// a zoom about the view's centre moves the thing the user is looking at
    /// out from under the cursor, and a board that does that feels broken.
    public func zoomed(to newScale: CGFloat, about anchor: CGPoint) -> BoardViewport {
        let clamped = min(max(newScale, Self.minimumScale), Self.maximumScale)
        guard clamped != scale else { return self }
        let anchorInWorld = worldPoint(for: anchor)
        return BoardViewport(
            scale: clamped,
            offset: CGPoint(
                x: anchor.x - anchorInWorld.x * clamped,
                y: anchor.y - anchorInWorld.y * clamped
            )
        )
    }

    /// The same viewport, panned by a screen-space delta.
    public func panned(by delta: CGSize) -> BoardViewport {
        BoardViewport(
            scale: scale,
            offset: CGPoint(x: offset.x + delta.width, y: offset.y + delta.height)
        )
    }

    /// The same viewport, panned by the movement between two screen points.
    ///
    /// The delta is measured from the PREVIOUS point, not from the start of
    /// the gesture. `panned(by:)` adds to the offset, so a caller that keeps
    /// sending the displacement from the gesture's start makes the world
    /// accelerate away from the cursor: the second event re-sends the first
    /// event's movement, and the tenth sends nine times as much.
    public func panned(from previous: CGPoint, to current: CGPoint) -> BoardViewport {
        panned(by: CGSize(width: current.x - previous.x, height: current.y - previous.y))
    }

    /// The same viewport, zoomed by a pinch magnification RELATIVE to it.
    ///
    /// A magnify gesture's magnification is a ratio that starts at 1, not a
    /// target scale, so it cannot be handed to `zoomed(to:about:)` as if it
    /// were one: the first callback would reset the board to 1.0.
    ///
    /// The multiplication happens here so that the caller applies it to the
    /// viewport the gesture STARTED from. Applying a relative magnification to
    /// the already-zoomed viewport compounds the zoom on every frame.
    public func zoomed(by magnification: CGFloat, about anchor: CGPoint) -> BoardViewport {
        zoomed(to: scale * magnification, about: anchor)
    }

    /// The part of the world that is on screen, in world coordinates.
    ///
    /// The culling bound: an item outside this rect is not drawn and not hit
    /// tested. A board with thousands of items is only fast because most of
    /// them are off screen.
    public func visibleWorldRect(in size: CGSize) -> CGRect {
        let origin = worldPoint(for: .zero)
        let far = worldPoint(for: CGPoint(x: size.width, y: size.height))
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: far.x - origin.x,
            height: far.y - origin.y
        )
    }

    /// Whether an item at a world rect is on screen.
    public func isVisible(_ worldRect: CGRect, in size: CGSize) -> Bool {
        visibleWorldRect(in: size).intersects(worldRect)
    }
}
