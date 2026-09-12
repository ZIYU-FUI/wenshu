//
//  InspectorPageSegmentedControl.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-11 OOB 'Mac OS 27 的控件是我们首选':
//  per the boss's request, this file provides the macOS 27
//  native inspector page switcher (= a NSSegmentedControl with
//  `role = .tabs` = the macOS 27 new role API that explicitly
//  marks the control as a tab switcher, distinct from the
//  pre-macOS-27 `.automatic` role; = the Pages / Keynote /
//  Numbers inspector tab semantic).
//
//  Why this exists (= why SwiftUI `Picker(.segmented)` is NOT
//  sufficient):
//  - SwiftUI `Picker(.segmented)` wraps NSSegmentedControl via
//    NSBridge, but SwiftUI does NOT expose
//    `NSSegmentedControl.Role` (a macOS 27 API_AVAILABLE
//    attribute per Apple SDK header).
//  - Without explicit `.role = .tabs`, the wrapped control falls
//    back to `.automatic` (= the macOS 10.5 behavior; = the
//    legacy "choose one" group; = visually identical to a
//    pre-macOS-27 segmented control; = intrinsic-size, NOT
//    full-width).
//  - The macOS 27 Pages / Keynote / Numbers inspector tab visual
//    (= the boss's reference) uses `.role = .tabs` + the
//    canonical `segmentStyle = .roundRect`, which SwiftUI does
//    not expose.
//
//  Implementation: a SwiftUI `NSViewRepresentable` that hosts a
//  native `NSSegmentedControl` and configures it with the
//  macOS 27 Liquid Glass appearance:
//  - `segmentStyle = .roundRect` (= the canonical segmented
//    control visual; = matches the Apple HIG Pages / Numbers
//    inspector tab style; = the macOS 10.10+ rounded-rect style
//    is what Apple renders for the inspector tab strip even
//    in macOS 27 = the Liquid Glass material is applied to the
//    window chrome, not to the segmented control itself).
//  - `role = .tabs` (= explicitly mark the control as a tab
//    switcher; = macOS 27 NEW API; = Accessibility reads it as
//    "page N of M"; = VoiceOver announces the page count;
//    = distinguishes the tabs role from the value-selection
//    role at the AppKit level).
//  - `segmentDistribution = .fillEqually` (= each segment
//    receives equal width; = the 4 pages divide the column
//    width equally; = satisfies the boss's '随右栏宽度自动
//    拉满' requirement that SwiftUI's `.frame(maxWidth:
//    .infinity)` could not deliver inside the previous
//    SwiftUI Picker).
//  - `trackingMode = .selectOne` (= one segment selected at a
//    time; = standard tab strip behavior).
//
//  Per-segment content: NSSegmentedControl's per-segment APIs
//  in macOS 27 are:
//  - `setImage(_:forSegment:)` (NSImage) = the segment icon
//  - `setLabel(_:forSegment:)` (NSString) = the segment text
//  There is NO `setView` API on NSSegmentedControl (= that was
//  a mistake in my initial implementation; = the closest
//  equivalent is the macOS 10.13+ `setToolTip(_:forSegment:)`
//  which we use for accessibility / hover hint).
//
//  Why macOS-only: `API_AVAILABLE(macos(27.0))` on Role (= only
//  macOS 27 supports the new role enum; = older OS would fall
//  back to `.automatic` which the AppKit SDK gates behind
//  API_AVAILABLE; = wrap with `if #available(macOS 27.0, *)`
//  so older macOS (= the wenshu minimum target is 27.0 per
//  AGENTS.md, so this guard is defensive; = SwiftUI
//  `Picker(.segmented)` remains the fallback for any future
//  macOS < 27 target).
//
//  Why we keep the selection binding typed as InspectorPage:
//  the wrapped NSSegmentedControl reads/writes an Int (segment
//  index); the component handles the Int ↔ InspectorPage
//  mapping internally; the caller's API surface stays typed.

import SwiftUI
import AppKit

/// v1.0.0-m1-shell boss 2026-09-11 OOB 'Mac OS 27 的控件是我们
/// 首选': the macOS 27 native inspector page switcher.
///
/// Usage:
///
/// ```swift
/// InspectorPageSegmentedControl(
///     selection: $inspectorPage,
///     pages: InspectorPage.allCases,
///     icon: { page in NSImage(systemSymbolName: page.icon, accessibilityDescription: page.localizedTitle) },
///     label: { page in page.localizedTitle }
/// )
/// .frame(height: 28) // macOS 27 segmented pill canonical height
/// ```
///
/// `icon` and `label` are pure Swift closures (= the caller
/// composes both from the page data; = full control over
/// segment content; = matches the NSSegmentedControl API).
///
/// `selection` is `Binding<InspectorPage>` (= NOT `Int`; = the
/// component handles the Int ↔ InspectorPage mapping internally;
/// = the caller's API surface stays typed).
struct InspectorPageSegmentedControl: NSViewRepresentable {
    let selection: Binding<InspectorPage>
    let pages: [InspectorPage]
    /// Returns the icon to display for the given page (= NSImage
    /// = the AppKit-native image type; = render via
    /// `NSImage(systemSymbolName:accessibilityDescription:)` or
    /// any other NSImage provider).
    let icon: (InspectorPage) -> NSImage?
    /// Returns the label text to display for the given page.
    let label: (InspectorPage) -> String

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        configure(control, coordinator: context.coordinator)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        configure(control, coordinator: context.coordinator)
    }

    /// v1.0.0-m1-shell boss 2026-09-11 OOB '随右栏宽度自动
    /// 拉满': configure the control to fill its container with
    /// equally-sized segments (= `segmentDistribution =
    /// .fillEqually`).
    private func configure(_ control: NSSegmentedControl, coordinator: Coordinator) {
        // Segment count + per-segment image + label.
        // NOTE: NSSegmentedControl segments are 0-indexed;
        // we use `pages.firstIndex(of:)` to map
        // InspectorPage ↔ Int.
        if control.segmentCount != pages.count {
            control.segmentCount = pages.count
        }
        for (index, page) in pages.enumerated() {
            control.setImage(icon(page), forSegment: index)
            control.setLabel(label(page), forSegment: index)
            // Also set tooltip (= the canonical Apple HIG
            // inspector tab tooltip; = appears on hover).
            control.setToolTip(label(page), forSegment: index)
        }

        // v1.0.0-m1-shell boss 2026-09-11 OOB 'Mac OS 27
        // 的控件是我们首选': apply the macOS 27 native
        // appearance. Wrapped in `if #available(macOS 27.0, *)`
        // (= the macOS minimum target is 27.0 per AGENTS.md,
        // so the guard is defensive; = any future macOS < 27
        // target falls back to the legacy rounded style).
        //
        // Note: `NSSegmentStyle` has NO `.glass` member (= the
        // common confusion source: `NSBezelStyle.glass` IS a
        // macOS 26+ API, but it lives on `NSButton` / NSButtonCell,
        // not on NSSegmentedControl). For NSSegmentedControl on
        // macOS 27, the canonical inspector tab visual is the
        // existing `.roundRect` style (= the rounded-rect
        // capsule = what Apple Pages / Numbers inspector tab
        // strips actually render with).
        if #available(macOS 27.0, *) {
            control.segmentStyle = .roundRect
            // macOS 27 NEW role API: `.tabs` explicitly
            // marks the control as a tab switcher (= vs
            // `.automatic` = the pre-macOS-27 generic group
            // selection = the visual difference is subtle
            // but Accessibility / VoiceOver reads it as
            // "page N of M"; = semantically correct).
            control.role = .tabs
        } else {
            // Defensive fallback (= NSSegmentedControl.role
            // is macOS 27 only; = older OS gets the legacy
            // automatic role = the macOS 10.5 visual).
            control.segmentStyle = .rounded
        }

        // Tracking = select one at a time (= the tab strip
        // behavior; = matches SwiftUI Picker(.segmented)).
        control.trackingMode = .selectOne

        // v1.0.0-m1-shell boss 2026-09-11 OOB '随右栏宽度自动
        // 拉满': distribute segments to fill the available
        // width equally (= `segmentDistribution = .fillEqually`;
        // = the boss's verbatim ask; = each segment takes 1/4
        // of the column width when 4 pages; = NSSegmentedControl
        // auto-stretches with the column drag).
        control.segmentDistribution = .fillEqually
        // Spread tracking mode = distribute leftover space
        // (= when control is wider than the sum of intrinsic
        // widths; = equivalent to NSSegmentedControl's
        // 'fillProportionally' default but applies to .fillEqually).
        control.controlSize = .regular

        // Sync selection state (= in case SwiftUI re-evaluates
        // the body and `selection` changed but the control is
        // still mounted).
        if let index = pages.firstIndex(of: selection.wrappedValue),
           control.selectedSegment != index {
            control.selectedSegment = index
        }

        // Wire target / action (= SwiftUI's NSViewRepresentable
        // does not auto-bridge `@Binding` writes back; = use the
        // classic AppKit target/action pattern; = the coordinator
        // captures the latest Binding and writes the new page).
        coordinator.parent = self
        control.target = coordinator
        control.action = #selector(Coordinator.segmentChanged(_:))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: InspectorPageSegmentedControl
        init(parent: InspectorPageSegmentedControl) {
            self.parent = parent
        }

        @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0 && index < parent.pages.count else { return }
            // Write the new page back to the caller's Binding.
            // (= propagates through SwiftUI's normal state
            // pipeline; = the inspector body re-renders with
            // the new page's filtered tools; = same binding
            // contract as SwiftUI Picker.)
            parent.selection.wrappedValue = parent.pages[index]
        }
    }
}
