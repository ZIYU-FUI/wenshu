//
//  LabelSegmentedControl.swift
//  wenshu
//
//  The toolbar's 4-page Picker keeps using the SwiftUI
//  `Picker(.segmented)` (= the canonical Apple HIG toolbar default
//  style = the macOS-auto-picked rounded-rect capsule = the same
//  visual Mail / Notes / Finder / Pages use in their toolbars).
//
//  The macOS 27 native `NSSegmentedControl` belongs in the
//  per-tool tab strip inside the inspector column body (= the
//  per-page tool tabs like Foreshadowing / Placeholder / Plot
//  Threads on Page 1; = all 4 pages get the same macOS 27 native
//  control).
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
//    uses `.role = .tabs` + the canonical `segmentStyle =
//    .roundRect`, which SwiftUI does not expose.
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
//    width equally).
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

/// macOS 27's native segmented tab control.
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
    /// Icon style applied before an `NSImage` is supplied to
    /// `NSSegmentedControl`. AppKit's segmented control scales images
    /// independently from SwiftUI text, so callers pass the same central
    /// style used by the surrounding toolbar instead of relying on
    /// `NSImage(systemSymbolName:)` defaults.
    let iconStyle: IconStyle

    /// AppKit weight counterpart used to configure `NSImage`
    /// symbols before they enter `NSSegmentedControl`.
    var symbolWeight: NSFont.Weight {
        iconStyle.fontWeight == .thin ? .thin : .regular
    }

    /// Per-segment display strings (= the `String` shown in
    /// `setLabel(_:forSegment:)`; = default uses
    /// `String(describing: labels[index])`; = callers can
    /// override for localized labels when Selection is a
    /// non-String Hashable like a custom enum).
    let displayStrings: [String]
    /// Per-segment symbol provider.
    let icon: ((Selection) -> NSImage?)?
    /// 2026-10-14 v3:
    /// per-segment
    /// fixed-width
    /// override
    /// (= the
    /// parent
    /// `EditorTabStrip`
    /// passes a
    /// non-zero
    /// value when
    /// the tabs
    /// overflow
    /// the column;
    /// = the
    /// control
    /// uses
    /// `segmentDistribution = .fit`
    /// + `setWidth(fixedSegmentWidth, forSegment: i)`
    /// so the
    /// per-segment
    /// width
    /// stays
    /// at the
    /// given
    /// value).
    var fixedSegmentWidth: CGFloat = 0
    /// Double-click callback (= the user double-clicks a
    /// segment; = the callback receives the
    /// zero-indexed segment position; = the
    /// `LabelSegmentedControl` is in the editor
    /// tab strip in this role, the callback
    /// closes the corresponding tab = the
    /// wenshu 1:1 Safari canonical "double-click
    /// a tab to close it" behavior). RATIONALE:
    /// the segmented control wires
    /// `NSClickGestureRecognizer(numberOfClicksRequired: 2)`;
    /// = the gesture's `target` fires
    /// `onDoubleClickSegment` (= the canonical
    /// way to bridge SwiftUI's `NSViewRepresentable`
    /// to AppKit's double-click event).
    /// SwiftUI HStack tab strip could have had a
    /// SwiftUI `.onTapGesture(count: 2)` modifier;
    /// = the AppKit `NSSegmentedControl` does NOT
    /// auto-bridge SwiftUI gestures; = we need
    /// an AppKit `NSClickGestureRecognizer`
    /// (= the macOS canonical native double-click
    /// detector) wired up to fire the callback).
    let onDoubleClickSegment: ((Int) -> Void)?

    init(
        selection: Binding<Selection>,
        labels: [Selection],
        displayStrings: [String]? = nil,
        iconStyle: IconStyle = .paneTab,
        icon: ((Selection) -> NSImage?)? = nil,
        onDoubleClickSegment: ((Int) -> Void)? = nil,
        fixedSegmentWidth: CGFloat = 0
    ) {
        self.selection = selection
        self.labels = labels
        self.displayStrings = displayStrings ?? labels.map { String(describing: $0) }
        self.iconStyle = iconStyle
        self.icon = icon
        self.onDoubleClickSegment = onDoubleClickSegment
        self.fixedSegmentWidth = fixedSegmentWidth
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        configure(control, coordinator: context.coordinator)
        // RATIONALE 2026-10-13: the AppKit
        // `NSSegmentedControl` does NOT auto-bridge
        // SwiftUI gestures (= the previous SwiftUI
        // HStack tab strip could have used
        // `.onTapGesture(count: 2)`; = the AppKit
        // native control needs an explicit
        // `NSClickGestureRecognizer` to fire on
        // double-click). The recognizer
        // (= `numberOfClicksRequired = 2`) calls
        // `handleDoubleClick` on the coordinator
        // (= which forwards the click location
        // → segment index → `onDoubleClickSegment`).
        // The recognizer is attached once at
        // make-time (= not in `updateNSView` to
        // avoid stacking duplicates; = the
        // recognizer's target is the coordinator
        // which captures the latest `parent` via
        // `coordinator.parent = self` in
        // `configure`).
        if onDoubleClickSegment != nil {
            let dblClick = NSClickGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleDoubleClick(_:))
            )
            dblClick.numberOfClicksRequired = 2
            dblClick.delaysPrimaryMouseButtonEvents = false
            control.addGestureRecognizer(dblClick)
        }
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        configure(control, coordinator: context.coordinator)
    }

    /// Configure the control to fill its container with
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
            // Use the per-page tab's display string (= the per-tab String
            // label; = matches the existing SwiftUI Picker(.segmented)
            // label washing).
            let display = index < displayStrings.count ? displayStrings[index] : String(describing: label)
            control.setLabel(display, forSegment: index)
            if let iconProvider = icon,
               let image = iconProvider(label) {
                control.setImage(
                    image.withSymbolConfiguration(
                        NSImage.SymbolConfiguration(
                            pointSize: iconStyle.pointSize,
                            weight: symbolWeight,
                            scale: .medium
                        )
                    ),
                    forSegment: index
                )
            }
            // Also set tooltip (= the canonical Apple HIG
            // inspector tab tooltip; = appears on hover).
            control.setToolTip(display, forSegment: index)
        }

        // Apply the macOS 27 native appearance. Wrapped in
        // `if #available(macOS 27.0, *)` (= the macOS minimum
        // target is 27.0 per AGENTS.md, so the guard is defensive;
        // = any future macOS < 27 target falls back to the legacy
        // rounded style).
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

        // Distribute segments to fill the available width equally
        // (= `segmentDistribution = .fillEqually`; = each segment
        // takes 1/N of the column width when N pages;
        // = NSSegmentedControl auto-stretches with the column drag).
        // 2026-10-14 v3.5:
        // back to
        // `.fillEqually`
        // (= the
        // canonical
        // equal-width
        // distribution
        // that
        // matches
        // Safari
        // tab-strip
        // visuals).
        // The
        // previous
        // v3.4
        // `.fit` mode
        // (= the
        // boss's
        // "framework
        // built-in
        // don't
        // auto-grow"
        // path) had
        // a
        // secondary
        // bug: the
        // ScrollView
        // wrap
        // introduces
        // a
        // multi-pass
        // layout
        // cycle
        // for the
        // inner
        // `NSViewRepresentable`
        // `NSSegmentedControl`
        // (= the
        // boss 2026-10-14
        // "tab 现在位置
        // 很飘"
        // symptom;
        // = the
        // tab
        // strip
        // visually
        // jumps
        // between
        // renders
        // as
        // SwiftUI
        // re-lays
        // out
        // the
        // ScrollView
        // viewport
        // on
        // every
        // body
        // re-evaluation;
        // = the
        // previous
        // v3.1
        // attempt
        // (= .fillEqually
        // +
        // GeometryReader
        // +
        // .frame(maxWidth: .infinity))
        // was the
        // only
        // stable
        // layout
        // the
        // boss
        // signed
        // off
        // on).
        // The
        // v3.5
        // fix:
        // drop
        // the
        // ScrollView
        // wrap
        // (=
        // the
        // `EditorTabStrip`
        // now
        // uses
        // the
        // plain
        // `LabelSegmentedControl`
        // with
        // no
        // wrapping
        // `Group`
        // /
        // no
        // `ScrollView`/
        // no
        // `ScrollViewReader`;
        // = the
        // NSSegmentedControl
        // is
        // laid
        // out
        // in
        // a
        // single
        // SwiftUI
        // pass
        // with
        // the
        // outer
        // `.frame(maxWidth: .infinity,
        // alignment: .leading)`
        // proposal;
        // = no
        // position
        // jump
        // = no
        // "飘"
        // symptom).
        // The
        // boss
        // already
        // signed
        // off
        // on
        // the
        // v3.1
        // "N
        // 多
        // 时
        // 拉
        // 宽
        // 窗
        // 口"
        // symptom
        // (= the
        // NSSegmentedControl
        // with
        // `.fillEqually`
        // +
        // parent
        // `.frame(maxWidth: .infinity)`
        // grows
        // the
        // window
        // to
        // fit
        // all
        // segments
        // when
        // N
        // is
        // large;
        // = the
        // boss
        // accepted
        // that
        // trade-off
        // before;
        // = the
        // v3.5
        // trade-off
        // is
        // "stable
        // layout
        // but
        // window
        // grows
        // with
        // N").
        // The
        // `fixedSegmentWidth
        // > 0`
        // path
        // is
        // dropped
        // (=
        // the
        // per-segment
        // width
        // override
        // is
        // no
        // longer
        // needed;
        // = the
        // .fillEqually
        // distribution
        // handles
        // the
        // per-segment
        // width
        // automatically).
        control.segmentDistribution = .fillEqually
        // 2026-10-14 v3.5: pin
        // `controlSize = .small`
        // (= the macOS
        // 27 canonical
        // "small" control
        // size; = ~22 PT
        // segment height
        // + ~60-80 PT
        // segment width
        // for a typical
        // 2-character
        // Chinese label;
        // = the
        // NSSegmentedControl
        // reports a
        // smaller
        // `intrinsicContentSize`
        // in the
        // `.fillEqually`
        // mode; = the
        // window still
        // grows to fit
        // all segments
        // when N is
        // large, but
        // the per-segment
        // size is
        // smaller than
        // the v3.1 default
        // `.large` size;
        // = the boss
        // accepts the
        // window-grow
        // trade-off for
        // a more compact
        // tab strip =
        // the canonical
        // macOS 27
        // Inspector tab
        // visual).
        control.controlSize = .small
        // Spread tracking mode = distribute leftover space
        // (= when control is wider than the sum of intrinsic
        // widths; = equivalent to NSSegmentedControl's
        // 'fillProportionally' default but applies to .fillEqually).
        // RATIONALE: `controlSize = .large`
        // (= the wenshu 1:1 macOS 27
        // Tahoe inspector-body tab pill
        // canonical; = 32 PT height;
        // = the inspector body uses
        // the same control size for
        // consistency). The segment
        // distribution is `.fillEqually`
        // so each segment takes 1/N of
        // the column width (= NSSegmentedControl
        // auto-stretches with the column
        // drag during NSV resize).
        // `.large` (= 30 PT; = the macOS 27
        // canonical "large" control size; = the
        // closest canonical size to the 32 PT
        // target; = using `.large` is preferable
        // to a custom `NSSegmentedControl` height
        // because the size affects Apple's
        // accessibility math, the standard hit
        // area, and the system-supplied
        // Liquid Glass rendering at the OS
        // level). The two call sites (= the
        // inspector body and the editor tab
        // strip) both move up by 10 PT (= the
        // delta from `.regular` to `.large`; =
        // a small visual change for the
        // inspector; = the expected change for
        // the tab strip).
        control.controlSize = .large

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

        @objc func handleDoubleClick(_ sender: NSClickGestureRecognizer) {
            // RATIONALE 2026-10-13: the
            // `NSClickGestureRecognizer` fires
            // AFTER the underlying control's
            // `target/action` (=
            // `segmentChanged`) runs (= the
            // first click selects the segment
            // via AppKit's normal
            // single-click handler; = the
            // second click fires the gesture
            // recognizer). By the time
            // `handleDoubleClick` runs, the
            // control's `selectedSegment`
            // (= the `Int` index of the
            // segment the user just clicked
            // on) is already up-to-date.
            // The `selectedSegment` is -1 if
            // no segment is selected (= the
            // click missed; = we guard).
            guard let control = sender.view as? NSSegmentedControl else { return }
            let segmentIndex = control.selectedSegment
            guard segmentIndex >= 0 && segmentIndex < parent.labels.count else { return }
            parent.onDoubleClickSegment?(segmentIndex)
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
