// TitlebarStatusbarPolish.swift · Wenshu (文枢) · v0.28 followup TKT-028-023
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = polish
// refinements to AppTitlebar + AppStatusbar based on hermes verbatim
// patterns.
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/app/shell/titlebar.ts
// = titlebarButtonClass (text-muted-foreground/85 hover:bg-control-hover)
// + titlebarToolClusterClass (pointer-events-auto [-webkit-app-region:no-drag])
// + titlebarControlsYNudge (= pre-Tahoe macOS optical center)
// + MACOS_TAHOE_DARWIN_MAJOR = 25
//
// And: hermes app/shell/statusbar-controls.tsx
// = STATUSBAR_ACTION_CLASS (inline-flex h-full items-center gap-1
//   rounded-none px-1.5 text-(--ui-text-tertiary) transition-colors
//   hover:bg-(--chrome-action-hover) hover:text-foreground
//   disabled:cursor-default disabled:opacity-45)

import SwiftUI
import AppKit

// MARK: - Titlebar control hover state (= hermes titlebarButtonClass)
//
// `TitlebarControlStyle` REMOVED in v0.34 Apple-API-first #3: zero callers
// (only the equivalent hover/pressed wash is achieved via `.background(.regularMaterial)`
// inline at each titlebar button site). Apple HIG canonical pressed-state
// background = `.background(Color(nsColor: .controlBackgroundColor))` or
// `.background(.regularMaterial)` direct (= no wrapper needed).

// MARK: - Pre-Tahoe macOS Y-nudge (= hermes titlebarControlsYNudge)

/// macOS traffic-light row only: nudge the left toolbar cluster down to
/// sit on the same optical center as the native buttons on pre-Tahoe
/// macOS (= Darwin < 25). Returns 0 for macOS Tahoe (= Darwin >= 25)
/// where the nudge is no longer needed. Matches Hermes
/// `titlebarControlsYNudge({darwinMajor, isFullscreen, windowButtonPosition})`.
@MainActor
public func titlebarControlsYNudge(
    darwinMajor: Int = 0,
    isFullscreen: Bool = false,
    windowButtonPosition: CGPoint?
) -> CGFloat {
    if isFullscreen || windowButtonPosition == nil || darwinMajor >= 25 {
        return 0
    }
    // Pre-Tahoe: nudge down by ~4.5 PT (= matches Hermes TITLEBAR_MAC_TRAFFIC_LIGHTS_Y_NUDGE).
    return kTitlebarMacTrafficLightsYNudge
}

// MARK: - Right-cluster inset (= hermes titlebarToolsRightCss)

/// Right-cluster inset (= for native overlay / fullscreen handling).
/// Matches Hermes `titlebarToolsRightCss(nativeOverlayWidth, {darwinMajor, isFullscreen})`.
@MainActor
public func titlebarToolsRightInset(
    nativeOverlayWidth: CGFloat,
    darwinMajor: Int = 0,
    isFullscreen: Bool = false
) -> CGFloat {
    if nativeOverlayWidth > 0 {
        return nativeOverlayWidth
    }
    if isFullscreen && darwinMajor > 0 {
        return kTitlebarEdgeInset
    }
    // Default (= macOS fullscreen / no overlay) = 12 PT (= matches
    // Hermes `0.75rem`).
    return 12.0
}

// MARK: - Statusbar action class (= hermes STATUSBAR_ACTION_CLASS)

/// Statusbar per-item hover modifier (= matches Hermes
/// `STATUSBAR_ACTION_CLASS` verbatim). Apply to any statusbar item to
/// get the canonical hover wash + disabled styling.
public struct StatusbarActionStyle: ViewModifier {
    let disabled: Bool
    @State private var isHover: Bool = false

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, LayoutTokens.chromePaddingMedium)
            // v0.32 boss 2026-09-02 OOB ('全走 apple api 默认'):
            // use bare Apple Material catalog directly (= the
            // canonical SwiftUI .thinMaterial from the Material
            // enum). The previous RegionHoverWashStyle wrapper
            // added an extra type with no semantic value.
            .background {
                if isHover && !disabled {
                    Color.clear.overlay(.thinMaterial)
                } else {
                    Color.clear
                }
            }
            .opacity(disabled ? 0.45 : 1.0)
            .onHover { hover in
                isHover = hover
            }
    }
}

extension View {
    /// Apply the standard statusbar item hover wash + disabled styling.
    public func statusbarActionStyle(disabled: Bool = false) -> some View {
        modifier(StatusbarActionStyle(disabled: disabled))
    }
}

// MARK: - Titlebar cluster (= pointer-events-auto, no drag region)

/// Titlebar cluster container (= matches Hermes
/// `titlebarToolClusterClass = "fixed z-70 flex flex-row items-center
/// pointer-events-auto select-none [-webkit-app-region:no-drag]"`).
/// Tools are inside (= clickable), but the titlebar outside the tools
/// is the drag region.
public struct TitlebarCluster: ViewModifier {
    let side: TitlebarToolSide

    public func body(content: Content) -> some View {
        content
            .frame(
                alignment: side == .left ? .leading : .trailing
            )
            .allowsHitTesting(true)
    }
}

extension View {
    /// Wrap in a titlebar cluster (= left or right alignment).
    public func titlebarCluster(_ side: TitlebarToolSide) -> some View {
        modifier(TitlebarCluster(side: side))
    }
}

// MARK: - macOS Tahoe detection (= hermes MACOS_TAHOE_DARWIN_MAJOR = 25)

/// macOS Tahoe = Darwin 25+. Returns true if running on Tahoe or later.
/// Matches Hermes `darwinMajor >= MACOS_TAHOE_DARWIN_MAJOR`.
@MainActor
public func isMacOSTahoe() -> Bool {
    var sysinfo = utsname()
    uname(&sysinfo)
    let release = withUnsafeBytes(of: &sysinfo.release) { raw in
        String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
    }
    // Parse "YY.M.x" or similar (= e.g. "24.0.0" = Darwin 24 = macOS 15 Sequoia).
    let parts = release.split(separator: ".")
    if let major = parts.first, let majorNum = Int(major) {
        return majorNum >= 25
    }
    return false
}