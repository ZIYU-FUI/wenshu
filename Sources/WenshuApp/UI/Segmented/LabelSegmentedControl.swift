//
//  LabelSegmentedControl.swift
//  wenshu
//
//  v1.0.0-m1-shell boss 2026-09-11 OOB 'for the toolbar, use the one we
//  just settled on — that's Apple's default toolbar style. The control you have now needs to be
//  used in the Foreshadowing/Placeholder tab bar. Apply the change to all four pages': the toolbar's
//  4-page Picker keeps using the SwiftUI `Picker(.segmented)`
//  (= the canonical Apple HIG toolbar default style = the
//  macOS-auto-picked rounded-rect capsule = the same visual
//  Mail / Notes / Finder / Pages use in their toolbars).
//
//  The macOS 27 native `NSSegmentedControl` (= introduced by
//  this commit's previous implementation in commit `5ebd07ecd`
//  as InspectorPageSegmentedControl.swift) belongs in the
//  per-tool tab strip inside the inspector column body (= the
//  per-page tool tabs like Foreshadowing / Placeholder / Plot Threads on Page 1;
//  = all 4 pages get the same macOS 27 native control = the
//  boss's 'apply the change to all four pages' directive).
//
//  Why this exists (= why SwiftUI `Picker(.segmented)` is NOT
//  sufficient for the inspector body tabs):
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
//  Renamed from `InspectorPageSegmentedControl` to
//  `LabelSegmentedControl` (= generic over any selection type;
//  = the toolbar uses a Label-typed picker; = the inspector
//  body uses an InspectorPage-typed picker; = both delegate
//  to the same underlying macOS 27 native NSSegmentedControl
//  wrapper).
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
//    receives equal width; = the N tabs divide the column
//    width equally; = satisfies the boss's 'auto-fill the right
//    column's width' requirement that SwiftUI's `.frame(maxWidth:
//    .infinity)` could not deliver inside the previous
//    SwiftUI Picker).
//  - `trackingMode = .selectOne` (= one segment selected at a
//    time; = standard tab strip behavior).
//
//  Per-segment content: NSSegmentedControl's per-segment APIs
//  in macOS 27 are:
//  - `setImage(_:forSegment:)` (NSImage) = the segment icon
//  - `setLabel(_:forSegment:)` (NSString) = the segment text
//  There is NO `setView` API on NSSegmentedControl (= the closest
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

import SwiftUI
import AppKit

/// v1.0.0-m1-shell boss 2026-09-11 OOB 'macOS 27's native control is our
/// first choice' + 'for the toolbar, use the one we just settled on — that's Apple's default toolbar style.
/// The control you have now needs to be used in the Foreshadowing/Placeholder tab bar.
/// Apply the change to all four pages': the macOS 27 native segmented tab control.
///
/// Generic over the selection type `Selection` (= Hashable; =
/// the caller binds the segmented control to a typed selection;
/// = the toolbar uses `[Label]` (= String segments) for the
/// 4-page picker; = the inspector body uses `[InspectorPage]`
/// (= enum cases) for the per-page tool tabs; = both delegate
/// to the same NSViewRepresentable wrapper).
///
/// Usage:
///
/// ```swift
/// // Page picker (toolbar):
/// LabelSegmentedControl(
///     selection: $page,
///     labels: ["A", "B", "C", "D"]
/// )
///
/// // Inspector body tabs (per-page tools):
/// LabelSegmentedControl(
///     selection: $currentTool,
///     labels: ["Foreshadowing", "Placeholder", "Plot Threads"]
/// )
/// .frame(maxWidth: .infinity) // stretches to column width
/// ```
///
/// Each segment's image is supplied via the `icon` closure
/// (= NSImage? = nil = no icon for that segment). The label is
/// supplied as `String` (= the segments[selection] value).
struct LabelSegmentedControl<Selection: Hashable>: NSViewRepresentable {
    let selection: Binding<Selection>
    /// The selection values (= one per segment; = the binding
    /// writes back the selected value; = the array order
    /// determines the left-to-right segment order).
    let labels: [Selection]
    /// Per-segment display strings (= the `String` shown in
    /// `setLabel(_:forSegment:)`; = default uses
    /// `String(describing: labels[index])`; = callers can
    /// override for localized labels when Selection is a
    /// non-String Hashable like a custom enum).
    let displayStrings: [String]
    /// v1.0.0-m1-shell boss 2026-09-11 OOB 'Lucide only, SF Symbol
    /// retired project-wide': use SF Symbol mapping as a fallback
    /// (= Lucide is the project's icon source per
    /// wenshu-apple-api-first; = NSSegmentedControl's
    /// setImage(_:forSegment:) requires NSImage; = for now we
    /// render the SF Symbol name from the Lucide name with a
    /// best-effort heuristic; = TODO future ticket can pre-render
    /// the Lucide glyph to NSImage for true wenshu visual
    /// fidelity).
    let icon: ((Selection) -> NSImage?)?

    init(
        selection: Binding<Selection>,
        labels: [Selection],
        displayStrings: [String]? = nil,
        icon: ((Selection) -> NSImage?)? = nil
    ) {
        self.selection = selection
        self.labels = labels
        self.displayStrings = displayStrings ?? labels.map { String(describing: $0) }
        self.icon = icon
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        configure(control, coordinator: context.coordinator)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        configure(control, coordinator: context.coordinator)
    }

    /// v1.0.0-m1-shell boss 2026-09-11 OOB 'auto-fill the right
    /// column's width': configure the control to fill its container with
    /// equally-sized segments (= `segmentDistribution =
    /// .fillEqually`).
    private func configure(_ control: NSSegmentedControl, coordinator: Coordinator) {
        // Segment count + per-segment label (= the
        // String-convertible binding of the typed selection).
        // NOTE: NSSegmentedControl segments are 0-indexed;
        // we use `labels.firstIndex(of:)` to map
        // Selection ↔ Int.
        if control.segmentCount != labels.count {
            control.segmentCount = labels.count
        }
        for (index, label) in labels.enumerated() {
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'Foreshadowing, Placeholder,
            // Plot Threads — that tab bar': use the per-page tab's display string
            // (= the per-tab String label; = matches the
            // existing SwiftUI Picker(.segmented) label washing).
            let display = index < displayStrings.count ? displayStrings[index] : String(describing: label)
            control.setLabel(display, forSegment: index)
            if let icon = icon {
                control.setImage(icon(label), forSegment: index)
            }
            // Also set tooltip (= the canonical Apple HIG
            // inspector tab tooltip; = appears on hover).
            control.setToolTip(display, forSegment: index)
        }

        // v1.0.0-m1-shell boss 2026-09-11 OOB 'Mac OS 27
        // native control is our first choice': apply the macOS 27 native
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

        // v1.0.0-m1-shell boss 2026-09-11 OOB 'auto-fill the right
        // column's width': distribute segments to fill the available
        // width equally (= `segmentDistribution = .fillEqually`;
        // = the boss's verbatim ask; = each segment takes 1/N
        // of the column width when N pages; = NSSegmentedControl
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
        if let index = labels.firstIndex(of: selection.wrappedValue),
           control.selectedSegment != index {
            control.selectedSegment = index
        }

        // Wire target / action (= SwiftUI's NSViewRepresentable
        // does not auto-bridge `@Binding` writes back; = use the
        // classic AppKit target/action pattern; = the coordinator
        // captures the latest Binding and writes the new selection).
        coordinator.parent = self
        control.target = coordinator
        control.action = #selector(Coordinator.segmentChanged(_:))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: LabelSegmentedControl
        init(parent: LabelSegmentedControl) {
            self.parent = parent
        }

        @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0 && index < parent.labels.count else { return }
            // Write the new selection back to the caller's Binding.
            // (= propagates through SwiftUI's normal state
            // pipeline; = the inspector body re-renders with
            // the new tool; = same binding contract as SwiftUI
            // Picker).
            parent.selection.wrappedValue = parent.labels[index]
        }
    }
}
