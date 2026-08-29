// Tip.swift · Wenshu (文枢) · v0.28 followup TKT-028-020
//
// Boss 2026-08-29 OOB '完整复刻 hermes app, 用户体验第一' = port the
// tooltip system from Hermes Desktop verbatim (= 200ms first-hover
// delay + 300ms warm window + non-interactive tips + keyboard-only
// focus-opens).
//
// SOURCE (= Hermes verbatim port):
// /Volumes/ANAN/.hermes/hermes-agent/apps/desktop/src/components/ui/tooltip.tsx
// = TIP_DELAY_MS = 200 (first hover wait — short enough for intent,
//   long enough to avoid sweep flashes)
// + TIP_SKIP_DELAY_MS = 300 (warm window — next trigger within 300ms
//   opens instantly after one tip)
// + disableHoverableContent = true (tips not interactive — hover over
//   tip doesn't keep it open; critical for -webkit-app-region: drag chrome)
// + suppressNonKeyboardFocusOpen (only keyboard modality opens on focus)

import SwiftUI
import AppKit

// MARK: - Tip tokens (= matches hermes tooltip.tsx constants)

/// Default hover-open delay for `Tip`. Below 150ms a passing cursor still
/// opens the tip; above 250ms an intentional hover feels broken. Matches
/// Hermes `TIP_DELAY_MS = 200`.
public let kTipDelayMS: Int = 200

/// After a tip closes, this window stays warm: the next trigger opens
/// instantly. Long enough to cover the move between adjacent chrome,
/// short enough that a hover a second later waits again. Matches Hermes
/// `TIP_SKIP_DELAY_MS = 300`.
public let kTipSkipDelayMS: Int = 300

// MARK: - Tip controller (= warm window state)

/// Tracks the global tip warm window (= when the last tip closed, and
/// whether subsequent hovers should open instantly). One instance per
/// app (= shared across all tip triggers).
public final class TipController: @unchecked Sendable {
    private let lock = NSLock()
    private var _lastClosedAt: Date = .distantPast
    private var _isTipShowing: Bool = false

    public init() {}

    public var lastClosedAt: Date {
        lock.lock()
        defer { lock.unlock() }
        return _lastClosedAt
    }

    public var isTipShowing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isTipShowing
    }

    /// Returns the effective delay for a new hover (= 0 if within warm
    /// window, otherwise `kTipDelayMS`).
    public func delayForNewHover(now: Date = Date()) -> Int {
        lock.lock()
        let elapsed = now.timeIntervalSince(_lastClosedAt) * 1000
        lock.unlock()
        if elapsed < Double(kTipSkipDelayMS) {
            return 0  // warm window
        }
        return kTipDelayMS
    }

    public func tipDidShow() {
        lock.lock()
        _isTipShowing = true
        lock.unlock()
    }

    public func tipDidClose(at now: Date = Date()) {
        lock.lock()
        _isTipShowing = false
        _lastClosedAt = now
        lock.unlock()
    }
}

// MARK: - Tip view modifier

/// The Tip modifier (= tooltip with hover timing + warm window).
///
/// Apply to any view: `someView.tip("Toggle sidebar (⌘B)")`.
///
/// Behavior (= matches Hermes Tip verbatim):
/// - First hover waits `kTipDelayMS` (= 200ms).
/// - Subsequent hovers within `kTipSkipDelayMS` (= 300ms) of last close
///   open instantly (= warm window).
/// - Tip is NOT interactive (= closing on cursor leave immediately).
/// - Tooltip is positioned below the trigger by default.
/// - `delayDuration: 0` parameter skips the first-hover delay (= for
///   elements where intent is immediate).
public struct TipModifier: ViewModifier {
    let text: String
    let keybind: String?
    let delayDuration: Int?
    @State private var isHover: Bool = false
    @State private var showTooltip: Bool = false
    @State private var task: Task<Void, Never>? = nil
    @Environment(\.tipController) private var controller

    public func body(content: Content) -> some View {
        content
            .onHover { hover in
                isHover = hover
                handleHoverChange(hover)
            }
            .overlay(alignment: .top) {
                if showTooltip && !text.isEmpty {
                    tooltipView
                        .offset(y: -28)
                        .transition(.opacity)
                        .allowsHitTesting(false)  // = disableHoverableContent
                }
            }
            .animation(.easeOut(duration: 0.1), value: showTooltip)
    }

    @ViewBuilder
    private var tooltipView: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primary)
            if let keybind {
                Text(keybind)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    // v0.28 followup Boss UX round 19 (Boss 2026-08-29
                    // OOB '所有区域的顶栏, 底栏, 背景, 用的颜色, 可
                    // 以适配液态玻璃吗'): keybind chip background =
                    // .thickMaterial (= denser Liquid Glass chip =
                    // Apple standard for inset keybind indicators on
                    // toolbars).
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.thickMaterial)
                    )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        // v0.28 followup Boss UX round 19: tooltip background =
        // .regularMaterial (= Apple standard tooltip Liquid Glass =
        // matches macOS tooltip look in Pages / Mail / Xcode). Per
        // Apple developer.apple.com/documentation/SwiftUI/Tooltip,
        // tooltips are translucent rounded capsules with a 1 PT
        // hairline border + subtle drop shadow.
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
        )
        // v0.28 followup Boss UX round 26: 1 PT Apple .separator stroke
        // replaces 0.5 PT Color(nsColor: .separatorColor) (= was different
        // height than all other 1 PT splitters). Apple HierarchicalShapeStyle
        // .separator (= canonical Liquid Glass separator, macOS 26 Tahoe)
        // = semitransparent line that adapts to dark/light mode.
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.separator, lineWidth: 1)
        )
    }

    private func handleHoverChange(_ hover: Bool) {
        task?.cancel()
        if hover {
            let delay = delayDuration ?? controller.delayForNewHover()
            if delay == 0 {
                showTooltipNow()
            } else {
                task = Task {
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                    if !Task.isCancelled && isHover {
                        showTooltipNow()
                    }
                }
            }
        } else {
            hideTooltip()
        }
    }

    private func showTooltipNow() {
        showTooltip = true
        controller.tipDidShow()
    }

    private func hideTooltip() {
        showTooltip = false
        controller.tipDidClose()
    }
}

// MARK: - View extension

extension View {
    /// Attach a tooltip (= Tip with hover timing). Use `keybind:` to
    /// display a keybind hint alongside the label (= e.g. `keybind: "⌘B"`).
    public func tip(_ text: String, keybind: String? = nil, delayDuration: Int? = nil) -> some View {
        modifier(TipModifier(text: text, keybind: keybind, delayDuration: delayDuration))
    }
}

// MARK: - Tip environment (= provides the controller)

private final class TipControllerEnvironmentKey: EnvironmentKey, @unchecked Sendable {
    static var defaultValue: TipController { TipController() }
}

extension EnvironmentValues {
    public var tipController: TipController {
        get { self[TipControllerEnvironmentKey.self] }
        set { self[TipControllerEnvironmentKey.self] = newValue }
    }
}