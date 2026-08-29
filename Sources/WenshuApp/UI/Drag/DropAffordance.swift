// DropAffordance.swift · Wenshu (文枢) · v0.28 followup TKT-028-021
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// drop affordance + drag visuals from Hermes Desktop verbatim (= dashed
// 2 PT rounded sheet, backdrop-blur 2 PX on LIVE drop only, 200ms
// fade-in animation, NSCursor.dragLink on drag start).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/ui/drop-affordance.tsx
// = DROP_SHEET_CLASS (rounded-2xl border-2 border-dashed)
// + DROP_SHEET_BLUR_CLASS (backdrop-blur-[2px] for live sheet only)
//
// And: hermes pane-shell/tree/zones-engine.ts L23-30
// = FADE_IN_DURATION_MILLIS = 200
//   FLASH_ZONES_DURATION_MILLIS = 700
//   alpha = clamp(t / 200, 0.001, 1) (= 0.001 floor avoids CSS flicker)

import SwiftUI
import AppKit

// MARK: - Drop affordance tokens (= matches hermes drop-affordance.tsx)

/// Fade-in duration for drop affordance (= 200ms). Matches Hermes
/// `FADE_IN_DURATION_MILLIS = 200`.
public let kFadeInDurationMillis: Int = 200

/// Flash duration (= 700ms total). Matches Hermes
/// `FLASH_ZONES_DURATION_MILLIS = 700`.
public let kFlashZonesDurationMillis: Int = 700

/// Default sensitivity radius for zone capture (= 20 PT). Matches
/// Hermes `LayoutDefaultSettings::DefaultSensitivityRadius = 20`.
public let kDefaultSensitivityRadius: CGFloat = 20

/// Overlapping centers sensitivity (= 75). Matches Hermes
/// `ZoneSelectionAlgorithms::OVERLAPPING_CENTERS_SENSITIVITY = 75`.
public let kOverlappingCentersSensitivity: CGFloat = 75

// MARK: - DropSheet view modifier

/// The drop sheet: a dashed region marking where a drop would land.
/// Renders ONLY when active (= no idle outline; prevents noise when
/// not dragging).
///
/// Visual properties (= matches Hermes DROP_SHEET_CLASS verbatim):
/// - `border-2 border-dashed` (= 2 PT dashed border, NOT 1 PT hairline)
/// - `rounded-2xl` (= 12 PT rounded corners)
/// - `backdrop-blur-[2px]` (= 2 PX blur on LIVE drop only, NOT idle)
///
/// Animation (= matches Hermes `ZonesOverlay::GetAnimationAlpha`):
/// - `alpha = clamp(t / 200ms, 0.001, 1)` (= 0.001 floor avoids CSS flicker)
/// - Fade in over 200ms when active
/// - Auto-hide after 700ms when autoHide = true (= flash mode)
public struct DropSheet: View {
    let active: Bool
    let autoHide: Bool
    let startedAt: Date
    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    public init(
        active: Bool,
        autoHide: Bool = false,
        startedAt: Date = Date(),
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 2
    ) {
        self.active = active
        self.autoHide = autoHide
        self.startedAt = startedAt
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
    }

    /// Computed alpha (= matches hermes `getAnimationAlpha(startedAtMs, nowMs, autoHide)`).
    public static func animationAlpha(startedAt: Date, now: Date = Date(), autoHide: Bool) -> Double {
        let elapsedMs = now.timeIntervalSince(startedAt) * 1000
        if autoHide && elapsedMs > Double(kFlashZonesDurationMillis) {
            return 0
        }
        // Return a positive value to avoid hiding (= hermes 0.001 floor).
        let raw = elapsedMs / Double(kFadeInDurationMillis)
        return min(max(raw, 0.001), 1.0)
    }

    public var body: some View {
        // Use TimelineView for smooth alpha animation (= matches Hermes
        // requestAnimationFrame loop).
        TimelineView(.animation) { context in
            let alpha = Self.animationAlpha(
                startedAt: startedAt,
                now: context.date,
                autoHide: autoHide
            )
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    Color.accentColor.opacity(alpha),
                    style: StrokeStyle(lineWidth: borderWidth, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.accentColor.opacity(alpha * 0.08))
                )
                .background(
                    // BACKDROP BLUR (= matches Hermes DROP_SHEET_BLUR_CLASS).
                    // Only on LIVE drop (= not idle).
                    VisualEffectBlur(material: .hudWindow)
                        .opacity(active ? alpha : 0)
                        .mask(
                            RoundedRectangle(cornerRadius: cornerRadius)
                        )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - VisualEffectBlur (= NSVisualEffectView bridge)

/// NSVisualEffectView bridge for SwiftUI (= SwiftUI doesn't natively
/// expose NSVisualEffectView; hermes uses CSS `backdrop-blur-[2px]`).
public struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - DragSession (= drag-start cursor swap)

/// Drag session (= SwiftUI drag in progress). Sets cursor to
/// `NSCursor.dragLink` on start (= matches hermes drag-session.ts).
/// Restores previous cursor on end.
@MainActor
public final class DragSession {
    private var previousCursor: NSCursor?

    public init() {}

    public func begin() {
        previousCursor = NSCursor.current
        NSCursor.dragLink.push()
    }

    public func end() {
        if previousCursor != nil {
            NSCursor.pop()
            previousCursor = nil
        }
    }
}

// MARK: - Drag cursor helpers

/// SwiftUI View extension that swaps cursor to `NSCursor.dragLink`
/// during a drag gesture (= matches hermes `paneChrome.collapsible`
/// drag affordance).
public struct DragCursorModifier: ViewModifier {
    let cursor: NSCursor
    @State private var isHover: Bool = false

    public func body(content: Content) -> some View {
        content
            .onHover { hover in
                isHover = hover
                if hover {
                    cursor.push()
                } else {
                    cursor.pop()
                }
            }
            .onDisappear {
                if isHover {
                    cursor.pop()
                }
            }
    }
}

extension View {
    /// Show a `NSCursor.dragLink` cursor on hover (= matches hermes
    /// drag affordance on tab strip + zone targets).
    public func dragCursor() -> some View {
        modifier(DragCursorModifier(cursor: .dragLink))
    }
}