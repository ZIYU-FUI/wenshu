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
//  = the toolbar uses a Label-typed picker; = the editor tab
//  strip uses a String-typed picker; = both delegate to the
//  same underlying macOS 27 native NSSegmentedControl wrapper).
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
/// = the toolbar uses `[Label]` (= String segments) for its
/// picker; = the editor tab strip uses `[String]` (= tab ids);
/// = both delegate to the same NSViewRepresentable wrapper).
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

    /// macOS 27 segmented-control role. The role decides how the
    /// SELECTED segment is drawn.
    ///
    /// `.valueSelection` is the default because a text label inside a
    /// `.tabs` segment is not painted (the selected segment becomes a
    /// dark inset with an invisible label). `.tabs` suits a strip whose
    /// segments carry SYMBOLS, where the symbol carries the state.
    var role: NSSegmentedControl.Role = .valueSelection

    /// Per-segment display strings (= the `String` shown in
    /// `setLabel(_:forSegment:)`; = default uses
    /// `String(describing: labels[index])`; = callers can
    /// override for localized labels when Selection is a
    /// non-String Hashable like a custom enum).
    let displayStrings: [String]
    /// Per-segment symbol provider.
    let icon: ((Selection) -> NSImage?)?
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
    /// The AppKit control size (= the segment's own height and hit
    /// area; = `NSControl.ControlSize`).
    ///
    /// The shared default is `.large` (= the macOS 27 Tahoe
    /// inspector-body tab pill canonical; = 28 PT; = what the
    /// inspector body and the editor tab strip have always used).
    /// A call site that wants the smaller control passes `.small`
    /// (= 20 PT; = the size Apple ships for a compact switcher).
    /// The control size is the ONLY knob that changes the drawn
    /// capsule's height: AppKit draws the capsule to fill the
    /// control's height, so a caller cannot shrink the drawn pill by
    /// constraining the SwiftUI frame alone.
    let controlSize: NSControl.ControlSize
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
        fixedSegmentWidth: CGFloat = 0,
        role: NSSegmentedControl.Role = .valueSelection,
        controlSize: NSControl.ControlSize = .large
    ) {
        self.selection = selection
        self.labels = labels
        self.displayStrings = displayStrings ?? labels.map { String(describing: $0) }
        self.iconStyle = iconStyle
        self.icon = icon
        self.onDoubleClickSegment = onDoubleClickSegment
        self.fixedSegmentWidth = fixedSegmentWidth
        self.role = role
        self.controlSize = controlSize
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
            // macOS 27 role API. The role decides how the SELECTED
            // segment is drawn, and the two roles are not
            // interchangeable for a text-labelled strip:
            //
            // - `.tabs` draws the selected segment as a dark inset and
            //   leaves its LABEL UNPAINTED (measured on macOS 27.0.1:
            //   the selected segment's max luminance is 46 and it has
            //   ZERO pixels above 140, while the unselected segments
            //   peak at 223). The role exists for ICON segments, where
            //   the symbol carries the state; a text label inside a
            //   `.tabs` segment is invisible.
            // - `.valueSelection` paints the selected segment's label
            //   normally (max luminance 227, 1049 pixels above 140) and
            //   still marks the selection with the dark inset.
            //
            // So a strip whose segments carry TEXT must use
            // `.valueSelection`; a strip whose segments carry SYMBOLS may
            // use `.tabs`.
            control.role = role
        } else {
            // Defensive fallback (= NSSegmentedControl.role
            // is macOS 27 only; = older OS gets the legacy
            // automatic role = the macOS 10.5 visual).
            control.segmentStyle = .rounded
        }

        // Tracking = select one at a time (= the tab strip
        // behavior; = matches SwiftUI Picker(.segmented)).
        control.trackingMode = .selectOne

        // Segment width: an explicit per-segment width when the caller
        // supplied one, otherwise an equal share of the whole track.
        //
        // `NSSegmentDistributionFit` honours `setWidth(_:forSegment:)`
        // per segment; `NSSegmentDistributionFill` divides the track
        // equally and ignores it. A strip that carries its own widths
        // therefore has to be told which mode it is in.
        if fixedSegmentWidth > 0 {
            control.segmentDistribution = .fit
            for index in 0..<control.segmentCount {
                control.setWidth(fixedSegmentWidth, forSegment: index)
            }
        } else {
            control.segmentDistribution = .fillEqually
        }
        // The control size (= the segment's own height, hit area and
        // label font) is the per-call-site knob; = the shared default
        // is `.large` (= the macOS 27 Tahoe inspector-body tab pill
        // canonical; = the inspector body and the editor tab strip
        // both use it). RATIONALE: the size affects Apple's
        // accessibility math, the standard hit area, and the
        // system-supplied Liquid Glass rendering at the OS level; = a
        // control size is preferable to a custom `NSSegmentedControl`
        // height. AppKit draws the capsule to FILL the control's
        // height, so a caller that wants a shorter drawn pill must ask
        // for a smaller control size (= constraining the SwiftUI frame
        // alone leaves the capsule at full height).
        control.controlSize = controlSize

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
