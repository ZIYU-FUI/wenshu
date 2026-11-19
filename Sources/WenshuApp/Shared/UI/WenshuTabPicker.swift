//
// WenshuTabPicker.swift wenshu
//
// The house's tab switcher = Apple's own macOS 27 tab control.
//
// WHY IT IS AN APPKIT CONTROL AND NOT A SWIFTUI PICKER: = SwiftUI ships
// the tab style (= `TabsPickerStyle`, = `.pickerStyle(.tabs)`), = and it
// draws exactly the right thing: = the liquid-glass plate under the
// selected tab, = the system's morph, = and the label inside the plate.
// MEASURED 2026-11-19: = that style sizes ITSELF to its content (= 3 tabs
// = 207 PT, = 12 tabs = 706 PT) and CENTRES itself, = and no SwiftUI
// modifier stretches it (= `.frame(width:)`, = `.fixedSize`, = = both
// measured to leave it at its own width). = The band, however, is a
// COLUMN: = the tabs must divide it (= the 2026-11-12 ruling), = so the
// width has to be pinned. = ⇒ ⇒ ⇒ So the app hosts the system's own
// `NSSegmentedControl` in the macOS 27 TAB ROLE (= `role = .tabs`, = the
// role SwiftUI's own tab style sets on its control), = and pins the
// frame. = The system's drawing is untouched: = the plate under the
// selected tab is the system's own glass (= the layer tree carries the
// same `CABackdropLayer` + `CASDFElementLayer` a SwiftUI `.tabs` picker
// carries), = and the app draws nothing.
//
// THE SETTINGS, = AND WHY EACH ONE: - `role = .tabs` (= the tab role,
// = macOS 27): = the value-selection role paints the selected cell in the
// app's ACCENT colour (= the theme-blue plate the boss rejected), = and
// the tab role paints the system's glass plate with the label in it.
// - `segmentStyle = .automatic` (= Apple's own default, = "the appearance
// is chosen depending on the type of window and the control's position
// inside it"): = a pinned `.roundRect` would be a DEVIATION from Apple's
// default, = and the round-rect plate is the shape the boss accepted.
// - `segmentDistribution = .fillEqually`: = the tabs divide the frame the
// app pinned, = and no tab has a minimum width (= a narrow band shortens
// a tab's title, = which is Apple's own truncation).
// - `trackingMode = .selectOne`: = one tab at a time.
//
// THE WIDTH: = the control's frame is pinned to the width the band
// PROPOSES (= `sizeThatFits` is what pins it, = because a SwiftUI
// `.frame(width:)` does NOT set an `NSViewRepresentable`'s frame), = so
// the switcher fills the band it is given, = and `.fillEqually` divides
// that width. = A caller whose band proposes nothing (= a horizontal
// scroll view, = where the proposal is unbounded) passes the width it
// measured instead. = The control's HEIGHT is always the system's own
// (= `.small` = 20 PT), = so the band centres the plate and every
// column's plate lands on the same line.
//
import AppKit
import SwiftUI

/// SwiftUI's size knob in AppKit's own enum.
///
/// SwiftUI has one size AppKit does not (= `.extraLarge`), = so the
/// mapping takes the nearest size AppKit ships. = The ladder is the
/// system's own, = so the plate keeps the height the size names.
private func appKitControlSize(_ size: ControlSize) -> NSControl.ControlSize {
    switch size {
    case .mini: .mini
    case .small: .small
    case .regular: .regular
    case .large: .large
    case .extraLarge: .large
    @unknown default: .regular
    }
}

/// The switcher as the app uses it: = the system's tab control, = pinned
/// to the width of the band it sits in.
struct WenshuTabPicker<Selection: Hashable>: View {
    /// The pick, = read and written by the caller's own state.
    let selection: Binding<Selection>
    /// One tab per entry, = in this order, = left to right.
    let labels: [Selection]
    /// The text drawn in each tab (= same index, = same count as
    /// `labels`; = the display text is localized by the caller and is not
    /// the case name).
    let displayStrings: [String]
    /// The system's size knob. A column-top chrome switcher takes
    /// `.small`, = the size Apple ships for a compact switcher, = so the
    /// plate leaves air inside the band row.
    var controlSize: ControlSize = .small

    /// The width to pin the frame to when the band cannot propose one.
    ///
    /// `nil` (= the usual case) = the band's own proposal is the width. =
    /// A caller passes a width only when the switcher sits INSIDE a
    /// horizontal scroll container, = where the proposal is unbounded
    /// and the only width that means anything is the viewport's, = which
    /// the caller measures outside the container.
    var regionWidth: CGFloat?

    var body: some View {
        TabControl(
            selection: selection,
            labels: labels,
            displayStrings: displayStrings,
            controlSize: controlSize,
            regionWidth: regionWidth ?? 0
        )
        // The switcher takes the width the band proposes (= the
        // `sizeThatFits` below turns that proposal into the control's
        // frame), and its OWN height, so the band's own
        // `.frame(height:)` centres the plate. = The two are one rule:
        // every column's plate sits on the same line in the same 28 PT
        // band (= the chat zone's bar is the baseline).
        .frame(maxWidth: .infinity)
    }
}

/// The system's tab control, = hosted and pinned.
private struct TabControl<Selection: Hashable>: NSViewRepresentable {
    let selection: Binding<Selection>
    let labels: [Selection]
    let displayStrings: [String]
    let controlSize: ControlSize
    /// The width the control's frame is PINNED to (= the band's width).
    let regionWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(frame: .zero)
        control.controlSize = appKitControlSize(controlSize)
        control.segmentStyle = .automatic
        control.role = .tabs
        control.segmentDistribution = .fillEqually
        control.trackingMode = .selectOne
        control.target = context.coordinator
        control.action = #selector(Coordinator.pickChanged(_:))
        context.coordinator.applyLabels(to: control)
        context.coordinator.applySelection(to: control)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyLabels(to: control)
        context.coordinator.applySelection(to: control)
    }

    /// The size the control is GIVEN, = and so the width AppKit's
    /// `.fillEqually` divides.
    ///
    /// A SwiftUI `.frame(width:)` modifier does NOT set an
    /// `NSViewRepresentable`'s frame, = so the frame is pinned here. = The
    /// width is the proposal the band makes (= the band's own width, =
    /// which is why the switcher fills it), = and where the band proposes
    /// nothing (= inside a horizontal scroll view, = where the proposal is
    /// unbounded) it is the width the caller measured instead.
    ///
    /// The HEIGHT is always the system's own fitting height: = the plate
    /// keeps the size its control size names, = and the band centres it,
    /// = so every column's plate lands on the same line (= the 2026-11-12
    /// alignment rule the chat zone's bar is the baseline of).
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSSegmentedControl,
        context: Context
    ) -> CGSize? {
        let height = nsView.fittingSize.height
        if regionWidth > 0 {
            return CGSize(width: regionWidth, height: height)
        }
        guard let width = proposal.width, width > 0, !width.isInfinite else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Keeps the control's cells in step with the app's state.
    final class Coordinator: NSObject {
        var parent: TabControl
        /// The titles the control currently carries, = so the cells are
        /// rebuilt only when the page list itself changed (= rewriting a
        /// cell would reset the selection).
        private var appliedTitles: [String] = []

        init(parent: TabControl) {
            self.parent = parent
        }

        /// Write the page titles into the control's cells.
        func applyLabels(to control: NSSegmentedControl) {
            let titles = parent.displayStrings
            guard titles != appliedTitles else { return }
            appliedTitles = titles
            while control.segmentCount > titles.count {
                control.segmentCount = control.segmentCount - 1
            }
            while control.segmentCount < titles.count {
                control.segmentCount = control.segmentCount + 1
            }
            for (index, title) in titles.enumerated() {
                control.setLabel(title, forSegment: index)
            }
        }

        /// Write the app's pick into the control.
        ///
        /// A value that names no page leaves the control with NO selection
        /// (= `selectedSegment = -1`), = so the drawn plate can never name
        /// a different value than the bound one.
        func applySelection(to control: NSSegmentedControl) {
            let wanted = parent.labels.firstIndex(of: parent.selection.wrappedValue) ?? -1
            guard control.selectedSegment != wanted else { return }
            control.selectedSegment = wanted
        }

        /// The user picked a tab.
        @objc func pickChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard index >= 0, index < parent.labels.count else { return }
            parent.selection.wrappedValue = parent.labels[index]
        }
    }
}
