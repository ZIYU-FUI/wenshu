// NativeControlsInspector.swift · Wenshu (文枢) · v0.28 followup TKT-028-022
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// native window controls inspector + drag strip from Hermes Desktop
// verbatim (= traffic-light rect, fullscreen handling, workspace
// geometry publishing).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/pane-shell/geometry.ts
// = windowControlsRect(connection, viewportWidth) → Rect | null
//   (= macOS traffic lights top-left OR Windows WSLg overlay top-right
//    OR nil for fullscreen / no controls)
// + publishWorkspaceGeometry (= publishes --workspace-left/right CSS vars
//   for plain-CSS alignment to main pane edges)
// + useWindowControlsOverlap (= chrome reserves drag strip)
//
// macOS-specific: Wenshu is macOS-only (= per AGENTS.md §11 Apple stack
// exclusive). This file provides:
// 1. `inspectNativeControls(for: NSWindow)` → GeometryRect? (= live
//    traffic-light rect from NSWindow).
// 2. `windowDragStrip(for: NSWindow, viewportWidth: CGFloat)` → CGFloat
//    (= width of the drag strip from window left edge to first tool).
// 3. `WorkspaceGeometryPublisher` View modifier (= publishes workspace
//    geometry to descendants via SwiftUI environment).

import SwiftUI
import AppKit

// MARK: - Native controls inspector (= live traffic-light rect)

/// Inspect the NSWindow (= wenshu's macOS-only native window) and
/// return the live native controls rect (= matches Hermes
/// `windowControlsRect(connection, viewportWidth)` for the
/// Wenshu-specific NSWindow source). Returns nil when there's
/// nothing to dodge (= fullscreen / secondary windows).
@MainActor
public func inspectNativeControls(
    for window: NSWindow?,
    viewportWidth: CGFloat
) -> GeometryRect? {
    guard let window else { return nil }
    let connection = GeometryConnection(
        windowButtonPosition: windowButtonPosition(of: window),
        nativeOverlayWidth: nativeOverlayWidth(of: window),
        isFullscreen: window.styleMask.contains(.fullScreen)
    )
    return windowControlsRect(connection: connection, viewportWidth: viewportWidth)
}

/// Read the macOS traffic-light position from NSWindow (= private API,
/// wrapped for safety). Returns nil when the window has no left-side
/// controls (= Windows/Linux, or macOS fullscreen, or macOS Tahoe).
@MainActor
private func windowButtonPosition(of window: NSWindow) -> CGPoint? {
    // NSWindow exposes `.standardWindowButton(.closeButton)` etc., but
    // not the position. Use private API via reflection (= hermes
    // equivalent on Electron side is `windowButtonPosition` from the
    // HermesConnection IPC).
    // For wenshu's purposes, we approximate via the close button frame.
    if window.styleMask.contains(.fullScreen) {
        return nil
    }
    if let closeButton = window.standardWindowButton(.closeButton) {
        let origin = closeButton.frame.origin
        // Convert to window-relative coords.
        return CGPoint(x: origin.x, y: closeButton.frame.maxY)
    }
    // Fallback (= no left-side controls detected).
    return nil
}

/// Read the macOS native right-side overlay width (= 0 unless WSLg).
/// Wenshu is macOS-only, so this is always 0.
@MainActor
private func nativeOverlayWidth(of window: NSWindow) -> CGFloat {
    // No WSLg equivalent on macOS (= native traffic lights on left).
    return 0
}

// MARK: - Drag strip (= width of strip from window left to first tool)

/// Compute the width of the drag strip from the window's left edge to
/// where the first titlebar tool should sit (= matches Hermes
/// `titlebarControlsPosition(windowButtonPosition, isFullscreen)`).
@MainActor
public func windowDragStripWidth(
    for window: NSWindow?,
    firstToolOffset: CGFloat = 74
) -> CGFloat {
    guard let rect = inspectNativeControls(for: window, viewportWidth: 0) else {
        // No controls (= fullscreen) → drag strip is the entire
        // titlebar. Tools should sit at the left edge (= Apple HIG
        // canonical 12 PT symmetric cluster edge inset; canonical
        // value, not a project token, per boss 2026-09-02 OOB
        // '用 api 默认间距, 不用换算, 不用管值').
        return 12
    }
    // Drag strip = width of controls rect (= the entire traffic-light band).
    // User can drag the window by hovering over this strip.
    return rect.width
}

// MARK: - WorkspaceGeometryPublisher (= publishes main pane edges)

/// SwiftUI View modifier that publishes the current workspace geometry
/// (= main pane's left + right edges) to descendants via environment.
/// Matches Hermes `publishWorkspaceGeometry()` (= publishes
/// `--workspace-left` + `--workspace-right` CSS vars).
public struct WorkspaceGeometryPublisher: ViewModifier {
    let viewport: GeometryRect
    let mainPane: GeometryRect

    public func body(content: Content) -> some View {
        content
            .environment(\.workspaceGeometry, computeWorkspaceGeometry(
                viewport: viewport,
                mainPane: mainPane
            ))
    }
}

extension View {
    /// Publish workspace geometry to descendants (= so chrome can align
    /// to main pane edges via `\.workspaceGeometry`).
    public func publishWorkspaceGeometry(viewport: GeometryRect, mainPane: GeometryRect) -> some View {
        modifier(WorkspaceGeometryPublisher(viewport: viewport, mainPane: mainPane))
    }
}

// MARK: - Workspace geometry environment (= mirrors hermes --workspace-left/right)

private struct WorkspaceGeometryEnvironmentKey: EnvironmentKey {
    static let defaultValue: WorkspaceGeometry = WorkspaceGeometry(
        left: 0, right: 0,
        viewportWidth: 1920, viewportHeight: 1080
    )
}

extension EnvironmentValues {
    public var workspaceGeometry: WorkspaceGeometry {
        get { self[WorkspaceGeometryEnvironmentKey.self] }
        set { self[WorkspaceGeometryEnvironmentKey.self] = newValue }
    }
}