// Geometry.swift · Wenshu · v0.28 followup TKT-028-013
//
// Boss 2026-08-29 OOB 'verbatim port from hermes app' = port the geometry helper
// from Hermes Desktop verbatim. Computes the native window controls
// rect (= macOS traffic lights top-left / Windows WSLg overlay top-right)
// + publishes workspace geometry (= the main pane's left/right edges
// in CSS var equivalents).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/geometry.ts
// = Rect + intersect() + windowControlsRect() + useWindowControlsOverlap()
//   + publishWorkspaceGeometry().

import Foundation
import CoreGraphics

// MARK: - Rect

/// AABB rect in viewport pixels (= matches hermes `Rect`).
public struct GeometryRect: Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - AABB intersection

/// AABB intersection. Returns nil when the rects don't overlap. Matches
/// hermes `intersect()` verbatim (= 1 helper replaces per-layout inset
/// special cases).
public func intersect(_ a: GeometryRect, _ b: GeometryRect) -> GeometryRect? {
    let x = max(a.x, b.x)
    let y = max(a.y, b.y)
    let right = min(a.x + a.width, b.x + b.width)
    let bottom = min(a.y + a.height, b.y + b.height)
    if right <= x || bottom <= y {
        return nil
    }
    return GeometryRect(x: x, y: y, width: right - x, height: bottom - y)
}

// MARK: - Native window controls

/// Height of the band the native controls live in. Matches Hermes
/// `CONTROLS_BAND_HEIGHT = 34`.
public let kControlsBandHeight: CGFloat = 34

/// Width of the macOS traffic-light cluster (= 3 buttons × 14 PT + spacing).
/// Matches Hermes `MACOS_LIGHTS_WIDTH = 58`.
public let kMacOSLightsWidth: CGFloat = 58

/// Fallback x-coordinate of the leftmost traffic-light button. Matches
/// Hermes `MACOS_FALLBACK_BUTTON_X = 24`.
public let kMacOSFallbackButtonX: CGFloat = 24

/// Connection-like surface that the geometry helper depends on. Wenshu
/// resolves these from `NSWindow` + `NSWindow.styleMask` (= the
/// Hermes-compatible abstraction).
public struct GeometryConnection: Equatable, Sendable {
    /// Position of the leftmost native window control (macOS traffic-light
    /// cluster). nil = no left-side controls (= Windows/Linux, macOS
    /// fullscreen, macOS Tahoe).
    public var windowButtonPosition: CGPoint?
    /// Width of the native right-side overlay (Windows WSLg). 0 = no overlay.
    public var nativeOverlayWidth: CGFloat
    /// macOS fullscreen = traffic lights hidden.
    public var isFullscreen: Bool

    public init(
        windowButtonPosition: CGPoint? = nil,
        nativeOverlayWidth: CGFloat = 0,
        isFullscreen: Bool = false
    ) {
        self.windowButtonPosition = windowButtonPosition
        self.nativeOverlayWidth = nativeOverlayWidth
        self.isFullscreen = isFullscreen
    }
}

/// The native window-control rectangle in viewport pixels (= nil when
/// there is nothing to dodge: fullscreen, secondary windows with hidden
/// controls, or non-Electron host). Matches Hermes `windowControlsRect()`
/// verbatim.
public func windowControlsRect(
    connection: GeometryConnection?,
    viewportWidth: CGFloat
) -> GeometryRect? {
    // Wenshu is macOS-only (= Apple stack exclusive per AGENTS.md §11).
    // Skip the `inElectron` check (= Wenshu is always a native window).
    guard let connection else { return nil }
    if connection.isFullscreen { return nil }

    // Windows / WSLg: native overlay on the top-right.
    let overlayWidth = connection.nativeOverlayWidth
    if overlayWidth > 0 {
        return GeometryRect(
            x: viewportWidth - overlayWidth,
            y: 0,
            width: overlayWidth,
            height: kControlsBandHeight
        )
    }

    // macOS: traffic lights on the top-left. windowButtonPosition === nil
    // means the platform has no left-side controls at all.
    let pos = connection.windowButtonPosition
    if pos == nil { return nil }

    let x = pos?.x ?? kMacOSFallbackButtonX
    return GeometryRect(
        x: 0,
        y: 0,
        width: x + kMacOSLightsWidth,
        height: kControlsBandHeight
    )
}

// MARK: - Workspace geometry (= published to chrome via env vars)

/// The geometry of the main pane (= `--workspace-left` + `--workspace-right`
/// in Hermes CSS vars). Chrome that aligns to the main pane reads these
/// via SwiftUI Environment instead of threading rects through every
/// caller. Matches Hermes `publishWorkspaceGeometry` verbatim.
public struct WorkspaceGeometry: Equatable, Sendable {
    /// Left edge of the workspace (= main pane). Always 0 in wenshu
    /// (= full bleed; no macOS sidebar reservation at root level).
    public var left: CGFloat
    /// Right edge of the workspace (= main pane right edge).
    public var right: CGFloat
    /// Total viewport width.
    public var viewportWidth: CGFloat
    /// Total viewport height.
    public var viewportHeight: CGFloat

    public init(left: CGFloat, right: CGFloat, viewportWidth: CGFloat, viewportHeight: CGFloat) {
        self.left = left
        self.right = right
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
    }
}

/// Compute the workspace geometry from a viewport rect + main pane rect.
public func computeWorkspaceGeometry(
    viewport: GeometryRect,
    mainPane: GeometryRect
) -> WorkspaceGeometry {
    return WorkspaceGeometry(
        left: mainPane.x,
        right: viewport.width - (mainPane.x + mainPane.width),
        viewportWidth: viewport.width,
        viewportHeight: viewport.height
    )
}

// MARK: - Inset calculation (= for content under traffic lights)

/// The inset (= padding) that content needs to apply to avoid being
/// covered by the native window controls. Chrome that draws under the
/// traffic lights (= titlebar fill, drag strip) reads this inset.
public struct NativeControlsInset: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var trailing: CGFloat
    public var bottom: CGFloat

    public init(top: CGFloat, leading: CGFloat, trailing: CGFloat, bottom: CGFloat) {
        self.top = top
        self.leading = leading
        self.trailing = trailing
        self.bottom = bottom
    }

    /// Zero inset (= no native controls to dodge).
    public static let zero = NativeControlsInset(top: 0, leading: 0, trailing: 0, bottom: 0)
}

/// Compute the inset (= padding) that content needs to dodge the native
/// window controls. Matches Hermes `useWindowControlsOverlap()`.
public func nativeControlsInset(
    connection: GeometryConnection?,
    viewportWidth: CGFloat
) -> NativeControlsInset {
    guard let rect = windowControlsRect(connection: connection, viewportWidth: viewportWidth) else {
        return .zero
    }
    return NativeControlsInset(
        top: rect.height,
        leading: rect.x,
        trailing: viewportWidth - (rect.x + rect.width),
        bottom: 0
    )
}