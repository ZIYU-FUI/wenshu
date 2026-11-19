//
// LabelSegmentedControl.swift wenshu
//
// The toolbar's 4-page Picker keeps using the SwiftUI `Picker(.segmented)`
// (= the canonical Apple HIG toolbar default style = the macOS-auto-picked
// rounded-rect capsule = the same visual Mail / Notes / Finder / Pages use
// in their toolbars).
//
// The macOS 27 native `NSSegmentedControl` belongs in the per-tool tab
// strip inside the inspector column body (= the per-page tool tabs like
// Foreshadowing / Placeholder / Plot Threads on Page 1; = all 4 pages get
// the same macOS 27 native control).
//
// Why this exists (= why SwiftUI `Picker(.segmented)` is NOT sufficient for
// the inspector body tabs): - SwiftUI `Picker(.segmented)` wraps
// NSSegmentedControl via NSBridge, but SwiftUI does NOT expose
// `NSSegmentedControl.Role` (a macOS 27 API_AVAILABLE attribute per Apple
// SDK header). - Without explicit `.role = .tabs`, the wrapped control
// falls back to `.automatic` (= the macOS 10.5 behavior; = the legacy
// "choose one" group; = visually identical to a pre-macOS-27 segmented
// control; = intrinsic-size, NOT full-width). - The macOS 27 Pages /
// Keynote / Numbers inspector tab visual uses `.role = .tabs` + the
// canonical `segmentStyle = .roundRect`, which SwiftUI does not expose.
//
// Renamed from `InspectorPageSegmentedControl` to `LabelSegmentedControl`
// (= generic over any selection type; the toolbar uses a Label-typed
// picker; = the editor tab strip uses a String-typed picker; = both
// delegate to the same underlying macOS 27 native NSSegmentedControl
// wrapper).
//
// Implementation: a SwiftUI `NSViewRepresentable` that hosts a native
// `NSSegmentedControl` and configures it with the macOS 27 Liquid Glass
// appearance: - `segmentStyle = .roundRect` (= the canonical segmented
// control visual; = matches the Apple HIG Pages / Numbers inspector tab
// style; = the macOS 10.10+ rounded-rect style is what Apple renders for
// the inspector tab strip even in macOS 27).
//
// THE MATERIAL: = the native control carries Apple's own Liquid Glass, =
// because Apple's own guidance says a standard component picks the material
// up automatically (= the HIG materials page: = "Standard components from
// system frameworks pick up the appearance and behavior of this material
// automatically"). = So the app asks for nothing and gets the material: =
// there is no `NSGlassEffectView` around the control, = and no hand-drawn
// material either. = MEASURED (= the control over a saturated host layer, =
// in the window's own appearance, = by
// `Tools/wenshu-devtool/probes/segmented_control_material.swift`): the
// control's cells do not paint an opaque fill, = so the backdrop reads
// through them (= the cell reads green-dominant, = while the same area
// under an opaque fill reads neutral grey). = A material container between
// the control and the backdrop would put a SECOND material there (= HIG's
// "do so sparingly"), = so the app adds none. - `role = .tabs` (=
// explicitly mark the control as a tab switcher; = macOS 27 NEW API; =
// Accessibility reads it as "page N of M"; = VoiceOver announces the page
// count; distinguishes the tabs role from the value-selection role at the
// AppKit level). - `segmentDistribution = .fillEqually` (= each segment
// receives equal width; = the N tabs divide the column width equally). -
// `trackingMode = .selectOne` (= one segment selected at a time; = standard
// tab strip behavior).
//
// Per-segment content: NSSegmentedControl's per-segment APIs in macOS 27
// are: - `setImage(_:forSegment:)` (NSImage) = the segment icon -
// `setLabel(_:forSegment:)` (NSString) = the segment text There is NO
// `setView` API on NSSegmentedControl (= the closest equivalent is the
// macOS 10.13+ `setToolTip(_:forSegment:)` which we use for accessibility /
// hover hint).
//
// Why macOS-only: `API_AVAILABLE(macos(27.0))` on Role (= only macOS 27
// supports the new role enum; = older OS would fall back to `.automatic`
// which the AppKit SDK gates behind API_AVAILABLE; = wrap with `if
// #available(macOS 27.0, *)` so older macOS (= the wenshu minimum target is
// 27.0 per AGENTS.md, so this guard is defensive; = SwiftUI
// `Picker(.segmented)` remains the fallback for any future macOS < 27
// target).

import AppKit
import SwiftUI

/// macOS 27's native segmented tab control.
///
/// Generic over the selection type `Selection` (= Hashable; = the caller
/// binds the segmented control to a typed selection; the toolbar uses
/// `[Label]` (= String segments) for its picker; = the editor tab strip
/// uses `[String]` (= tab ids); both delegate to the same
/// NSViewRepresentable wrapper).
///
/// Usage:
///
/// ```swift // Page picker (toolbar): LabelSegmentedControl( selection:
/// $page, labels: ["A", "B", "C", "D"] )
///
/// // Inspector body tabs (per-page tools): LabelSegmentedControl(
/// selection: $currentTool, labels: ["Foreshadowing", "Placeholder", "Plot
/// Threads"] ) .frame(maxWidth: .infinity) // stretches to column width ```
///
/// Each segment's image is supplied via the `icon` closure (= NSImage? =
/// nil = no icon for that segment). The label is supplied as `String` (=
/// the segments[selection] value).
struct LabelSegmentedControl<Selection: Hashable>: NSViewRepresentable {
    let selection: Binding<Selection>
    /// The selection values (= one per segment; = the binding writes back
    /// the selected value; = the array order determines the left-to-right
    /// segment order).
    let labels: [Selection]
    /// Icon style applied before an `NSImage` is supplied to
    /// `NSSegmentedControl`. AppKit's segmented control scales images
    /// independently from SwiftUI text, so callers pass the same central
    /// style used by the surrounding toolbar instead of relying on
    /// `NSImage(systemSymbolName:)` defaults.
    let iconStyle: IconStyle

    /// AppKit weight counterpart used to configure `NSImage` symbols before
    /// they enter `NSSegmentedControl`.
    var symbolWeight: NSFont.Weight {
        iconStyle.fontWeight == .thin ? .thin : .regular
    }

    /// macOS 27 segmented-control role. The role decides how the SELECTED
    /// segment is drawn.
    ///
    /// `.valueSelection` is the default because a text label inside a
    /// `.tabs` segment is not painted (the selected segment becomes a dark
    /// inset with an invisible label). `.tabs` suits a strip whose segments
    /// carry SYMBOLS, where the symbol carries the state.
    var role: NSSegmentedControl.Role = .valueSelection

    /// Per-segment display strings (= the `String` shown in
    /// `setLabel(_:forSegment:)`; = default uses `String(describing:
    /// labels[index])`; = callers can override for localized labels when
    /// Selection is a non-String Hashable like a custom enum).
    let displayStrings: [String]
    /// Per-segment symbol provider.
    let icon: ((Selection) -> NSImage?)?
    /// The width the control's frame is PINNED to (= the region the caller
    /// was given; = zero = the control keeps its own fitting width, = which
    /// is what the toolbar picker and the inspector body tabs want).
    ///
    /// The pin is what makes the division work, and it is NOT a SwiftUI
    /// `.frame(width:)` modifier: that modifier does NOT set an
    /// `NSViewRepresentable`'s frame (= MEASURED: a 160 PT `.frame` left
    /// the control at its own fitting width of 240 PT, = and at 1056 PT for
    /// 16 tabs). The frame is pinned by `sizeThatFits` below, = the public
    /// API for the size a representable is given.
    ///
    /// With the frame pinned, `NSSegmentDistributionFillEqually` divides it
    /// exactly (= AppKit's own header: the segments "will be sized to fill
    /// the available space, and kept the same size as each other").
    /// MEASURED on the real control in a real app: 16 tabs in a 200 PT
    /// region step by 12.5 PT (= 200 / 16), 30 tabs in a 120 PT region step
    /// by 4.0 PT (= 120 / 30), 16 tabs in a 40 PT region step by 2.5 PT (=
    /// 40 / 16). The division is unbounded, = and a tab label below its own
    /// fitting width is simply not drawn (= which the boss's rule allows:
    /// "a tab may end up showing not one character").
    var regionWidth: CGFloat = 0
    /// The AppKit control size (= the segment's own height and hit area; =
    /// `NSControl.ControlSize`).
    ///
    /// The shared default is `.large` (= the macOS 27 Tahoe inspector-body
    /// tab pill canonical; = 28 PT; = what the inspector body and the
    /// editor tab strip have always used). A call site that wants the
    /// smaller control passes `.small` (= 20 PT; = the size Apple ships for
    /// a compact switcher). The control size is the ONLY knob that changes
    /// the drawn capsule's height: AppKit draws the capsule to fill the
    /// control's height, so a caller cannot shrink the drawn pill by
    /// constraining the SwiftUI frame alone.
    let controlSize: NSControl.ControlSize
    /// Fired when the pointer clicks the Safari-style X inside a segment (=
    /// the segment's index).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS OPT-IN: = a nil closure means the strip has no close
    /// path, = and then no X is drawn (= the chat zone's session bar and
    /// the inspector's switcher keep their own shape). = The X is drawn by
    /// the CONTROL, = not by a SwiftUI button per tab: = that shape crashed
    /// this app (= the window's "Update Constraints in Window" pass count),
    /// = and one segmented control is the shape that survived.
    var onCloseSegment: ((Int) -> Void)?

    /// Whether the strip answers a right-click with a menu.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS OPT-IN PER CALL SITE: = the editor's tab strip asks
    /// for it, = and the chat zone's session bar and the inspector's
    /// switcher do not (= the boss's own ruling: = the editor's area only).
    var showsContextMenu: Bool = false

    init(
        selection: Binding<Selection>,
        labels: [Selection],
        displayStrings: [String]? = nil,
        iconStyle: IconStyle = .paneTab,
        icon: ((Selection) -> NSImage?)? = nil,
        onCloseSegment: ((Int) -> Void)? = nil,
        showsContextMenu: Bool = false,
        regionWidth: CGFloat = 0,
        role: NSSegmentedControl.Role = .valueSelection,
        controlSize: NSControl.ControlSize = .large
    ) {
        self.selection = selection
        self.labels = labels
        self.displayStrings = displayStrings ?? labels.map { String(describing: $0) }
        self.iconStyle = iconStyle
        self.icon = icon
        self.onCloseSegment = onCloseSegment
        self.showsContextMenu = showsContextMenu
        self.regionWidth = regionWidth
        self.role = role
        self.controlSize = controlSize
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        // ⇒ ⇒ ⇒ AND THE CLOSE CONTROL IS ONLY FOR A CALLER THAT ASKS FOR
        // A CLOSE PATH: = the close control draws the tab strip's TITLE
        // LADDER (= the title that gives up its room for the X), = = and a
        // consumer that never asked for an X = = the inspector's page
        // switcher, = = the library sidebar's switcher, = = the chat zone's
        // bar = = must draw WHOLE titles again (= MEASURED: = the review's
        // own probe, = = 2026-11-18: = = they drew "Sub-Age…" and
        // "Reference Libr…" = = because the ladder truncated them).
        //
        // ⇒ ⇒ ⇒ ⇒ AND THE PLAIN CONTROL KEEPS ITS OWN TITLE: = the
        // ladder is the close control's own drawing, = = and a plain
        // `NSSegmentedControl` draws the whole title it was given.
        let control: NSSegmentedControl
        if onCloseSegment != nil {
            let closeControl = PaneTabStripCloseControl(frame: .zero)
            closeControl.onCloseSegment = onCloseSegment
            control = closeControl
        } else {
            control = NSSegmentedControl(frame: .zero)
        }
        configure(control, coordinator: context.coordinator)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        configure(control, coordinator: context.coordinator)
    }

    /// The size the control is GIVEN (= the frame it is pinned to).
    ///
    /// A SwiftUI `.frame(width:)` modifier does NOT set an
    /// `NSViewRepresentable`'s frame (= MEASURED: a 160 PT `.frame` left
    /// the control at its own fitting width of 240 PT, = and at 1056 PT for
    /// 16 tabs, = so the strip overflowed its column). `sizeThatFits` is
    /// the public API for the size a representable is given, = and it is
    /// what pins the frame.
    ///
    /// The width is the caller's REGION (= the column the strip was given),
    /// not the proposal's: the proposal is unbounded inside the strip's
    /// horizontal scroll container (= a horizontal scroll view proposes no
    /// width), = so the proposal could never pin the frame.
    ///
    /// A zero region means the strip has not been measured yet, = and the
    /// control keeps its own fitting width until the first measurement
    /// lands.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView _: NSSegmentedControl,
        context _: Context
    ) -> CGSize? {
        // ⇒ ⇒ ⇒ AND THE HEIGHT IS THE CAPSULE'S OWN MEASURED SIZE: the
        // segmented control's own size is a CONSTRAINT-SOLVER product (=
        // MEASURED: = the editor's strip read `fittingSize` (0, 0) at the
        // moment this method was called, = and (138, 20) after it), = and a
        // control sized to 0 draws NO interior (= the cell draws no
        // segment, = and the X has no pixels to land in).
        //
        // ⇒ ⇒ ⇒ AND THE PROPOSAL IS THE HOST'S ANSWER: = the strip's band
        // gives the control its row's height (=
        // `DesignTokens.paneTabHotArea`).
        let proposedHeight = proposal.height ?? 0
        let height = proposedHeight > 0 ? proposedHeight : PaneTabStripClose.capsuleHeight
        guard regionWidth > 0 else { return nil }
        return CGSize(width: regionWidth, height: height)
    }

    /// Configure the control to fill its container with equally-sized
    /// segments (= `segmentDistribution = .fillEqually`).
    ///
    /// Internal (= not private) so a test can drive the PRODUCTION write
    /// path with a real `NSSegmentedControl`. A test that only calls the
    /// pure index helper does not guard the fix: the write here could be
    /// reverted to its old form (= writing nothing when the bound value
    /// names no segment) and every pure assertion would still pass.
    func configure(_ control: NSSegmentedControl, coordinator: Coordinator) {
        // Segment count + per-segment label (= the String-convertible
        // binding of the typed selection). NOTE: NSSegmentedControl
        // segments are 0-indexed; we use `labels.firstIndex(of:)` to map
        // Selection ↔ Int.
        if control.segmentCount != labels.count {
            control.segmentCount = labels.count
        }
        // The width ONE segment takes (= the region's share).
        //
        // The strip divides the region it was given (= `PaneTabStripWidth`
        // is the owner of that rule), = so the share is the region's width
        // over the segment count. = A zero region means the strip has not
        // been measured yet, = and then the control is on its own fitting
        // width (= every title fits), = so the title stays whole.
        let share = PaneTabStripWidth.segmentWidth(
            columnWidth: regionWidth,
            segmentCount: labels.count
        )
        // The font the control draws its label with.
        //
        // MEASURED: the label font is the system font at 13 PT at both
        // control sizes (= the control size changes the cell's height and
        // the drawn capsule, = not the label's type), = and the control
        // knows it before its first layout pass, = so the width the app
        // measures is the width AppKit draws.
        let labelFont = control.font ?? PaneTabStripClose.titleFont()
        // The titles every segment carries (= the whole titles, = and the
        // ladder decides what is drawn).
        //
        // ⇒ ⇒ ⇒ AND WHEN THE CONTROL CARRIES THE X, = IT OWNS THE TITLES: =
        // the ladder's answer depends on the hover (= the X takes the
        // hovered segment's title room), = so the drawing cannot live in
        // this caller, = which re-runs only when SwiftUI updates.
        let titles = labels.indices.map { index in
            index < displayStrings.count ? displayStrings[index] : String(describing: labels[index])
        }
        if let closeControl = control as? PaneTabStripCloseControl {
            // ⇒ ⇒ ⇒ AND THE STRIP ANSWERS A RIGHT-CLICK ONLY WHEN ITS CALL
            // SITE ASKS FOR IT: = the editor's tab strip does, = and the
            // other columns' own switchers do not.
            closeControl.showsContextMenu = showsContextMenu
            closeControl.setDisplayStrings(
                titles,
                share: share,
                font: labelFont,
                // The X's mark: = nil when the strip has no close path, =
                // and then no X is drawn at all.
                closeGlyph: onCloseSegment == nil
                    ? nil
                    : NSImage(
                        systemSymbolName: PaneTabStripClose.glyphName,
                        accessibilityDescription: nil
                    )
            )
            // ⇒ ⇒ ⇒ AND THE SELECTED TAB IS THE ONE THAT CARRIES THE X: =
            // the boss's ruling (= only the SELECTED tab carries the X), =
            // so the control is told which segment the selection names.
            let selected = LabelSegmentedControl.selectedSegmentIndex(
                for: selection.wrappedValue,
                in: labels
            )
            // ⇒ ⇒ ⇒ AND THE SELECTION COMES FIRST: = the titles are fitted
            // against the widths, = and the widths are the collapse's
            // answer, = so the order is the selection, = the collapse, =
            // and then the titles.
            closeControl.setSelectedSegment(selected)
            // ⇒ ⇒ ⇒ AND THE WIDTHS WAIT FOR THE CONTROL'S OWN FRAME: = the
            // collapse divides the COLUMN, = and the column is the
            // control's own frame (= the one AppKit divides), = and the
            // caller's region can be a STALE one (= the region is written
            // on every SwiftUI update).
        }
        for (index, label) in labels.enumerated() {
            // Use the per-page tab's display string (= the per-tab String
            // label; = matches the existing SwiftUI Picker(.segmented)
            // label washing).
            let display = index < displayStrings.count ? displayStrings[index] : String(describing: label)
            // The title the segment DRAWS.
            //
            // AppKit truncates a title that does not fit (= it keeps the
            // start of it and adds an ellipsis, = and when even the
            // ellipsis does not fit it draws the lone ellipsis, = which the
            // boss ruled out: = "缩到一定程度，那个...就没有意义
            // 了，不如只能显示...的时候，连...都不显示"). = So the app decides the title
            // itself, = and `PaneTabStripTitle` is the one place that
            // decision is made (= one door per question = the editor's
            // strip and the chat zone's bar cannot drift).
            //
            // The TOOLTIP keeps the WHOLE title (= the canonical Apple HIG
            // inspector tab tooltip, = which is what a narrow tab needs: =
            // the drawn title is short, = and the hover still names the
            // document). The title the segment DRAWS is the ladder's
            // answer, = and the control that carries the X owns it (= the
            // hover changes it), = so it is set there and not here.
            if !(control is PaneTabStripCloseControl) {
                let drawn = PaneTabStripTitle.fitted(
                    display,
                    share: share,
                    font: labelFont
                )
                control.setLabel(drawn, forSegment: index)
            }
            if let iconProvider = icon,
               let image = iconProvider(label)
            {
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
            // Also set tooltip (= the canonical Apple HIG inspector tab
            // tooltip; = appears on hover).
            control.setToolTip(display, forSegment: index)
        }

        // Apply the macOS 27 native appearance. Wrapped in `if
        // #available(macOS 27.0, *)` (= the macOS minimum target is 27.0
        // per AGENTS.md, so the guard is defensive; any future macOS < 27
        // target falls back to the legacy rounded style).
        //
        // Note: `NSSegmentStyle` has NO `.glass` member (= the common
        // confusion source: `NSBezelStyle.glass` IS a macOS 26+ API, but it
        // lives on `NSButton` / NSButtonCell, not on NSSegmentedControl).
        // For NSSegmentedControl on macOS 27, the canonical inspector tab
        // visual is the existing `.roundRect` style (= the rounded-rect
        // capsule = what Apple Pages / Numbers inspector tab strips
        // actually render with).
        if #available(macOS 27.0, *) {
            control.segmentStyle = .roundRect
            // macOS 27 role API. The role decides how the SELECTED segment
            // is drawn, and the two roles are not interchangeable for a
            // text-labelled strip:
            //
            // - `.tabs` draws the selected segment as a dark inset and
            // leaves its LABEL UNPAINTED (measured on macOS 27.0.1: the
            // selected segment's max luminance is 46 and it has ZERO pixels
            // above 140, while the unselected segments peak at 223). The
            // role exists for ICON segments, where the symbol carries the
            // state; a text label inside a `.tabs` segment is invisible. -
            // `.valueSelection` paints the selected segment's label
            // normally (max luminance 227, 1049 pixels above 140) and still
            // marks the selection with the dark inset.
            //
            // So a strip whose segments carry TEXT must use
            // `.valueSelection`; a strip whose segments carry SYMBOLS may
            // use `.tabs`.
            control.role = role
        } else {
            // Defensive fallback (= NSSegmentedControl.role is macOS 27
            // only; = older OS gets the legacy automatic role = the macOS
            // 10.5 visual).
            control.segmentStyle = .rounded
        }

        // Tracking = select one at a time (= the tab strip behavior; =
        // matches SwiftUI Picker(.segmented)).
        control.trackingMode = .selectOne

        // Segment width: an equal share of the region the caller was given,
        // = or the control's own fitting width when no region was given (=
        // the toolbar picker and the inspector body tabs, = which are sized
        // by their content).
        //
        // `NSSegmentDistributionFillEqually` divides the control's OWN
        // frame equally, = so the frame is what the segments share. The
        // frame is pinned to the region by `sizeThatFits` below, = so the
        // strip fills its column exactly, at any tab count, with no
        // per-cell minimum.
        //
        // The distribution stays `.fillEqually`: = it is AppKit's own rule
        // that the segments share the control's frame equally.
        control.segmentDistribution = .fillEqually

        // The segment WIDTHS (= none is set: the distribution divides the
        // frame).
        //
        // ⇒ ⇒ ⇒ `setWidth(_:forSegment:)` looks like the answer and is not:
        // AppKit CLAMPS an explicit width to its own minimum (= MEASURED:
        // 20.5 PT at the `.small` control size), = so a share below that
        // floor comes back as 20.5 PT per cell, = and the strip then
        // overflows the column it was given. = SO NO SEGMENT WIDTH IS SET
        // HERE, = and `.fillEqually` divides the frame instead.
        //
        // ⇒ ⇒ ⇒ MEASURED on the REAL strip, hosted (= its layer tree): =
        // with the widths set, = a share of 18.50 PT (12 tabs in a 222 PT
        // column) drew a 240 PT track (= 18 PT over the column, = and the
        // last cell clipped), = and a share of 19.76 PT (23 tabs in a 454.5
        // PT column) drew 460 PT (= 5.5 PT over). = THE BAND 18.2 TO 19.9
        // PT IS EXACTLY WHERE THE CLAMP BITES.
        //
        // ⇒ ⇒ ⇒ AND `.fillEqually` ALONE IS EXACT THERE (= MEASURED:
        // 454.50, 222.00 and 190.00 PT of track for those geometries, = and
        // exact at every other tab count too), = BUT ONLY WHILE NO LABEL IS
        // WIDER THAN ITS CELL: = a label the control cannot fit makes the
        // cell `label + 20.5 PT` wide (= MEASURED: 3 tabs in a 200 PT
        // region with 60 PT labels drew 239 PT of track), = which is why
        // the title budget is the share MINUS that inset
        // (`PaneTabStripTitle.fitted`). The control size (= the segment's
        // own height, hit area and label font) is the per-call-site knob; =
        // the shared default is `.large` (= the macOS 27 Tahoe
        // inspector-body tab pill canonical; = the inspector body and the
        // editor tab strip both use it). RATIONALE: the size affects
        // Apple's accessibility math, the standard hit area, and the
        // system-supplied Liquid Glass rendering at the OS level; = a
        // control size is preferable to a custom `NSSegmentedControl`
        // height. AppKit draws the capsule to FILL the control's height, so
        // a caller that wants a shorter drawn pill must ask for a smaller
        // control size (= constraining the SwiftUI frame alone leaves the
        // capsule at full height).
        control.controlSize = controlSize

        // The drawn bezel's shape. `borderShape`'s DEFAULT is not the same
        // shape at every control size: at `.small` the default is a rounded
        // rectangle (its corner radius is small, so the bezel's top row is
        // nearly full width), while at `.large` the default is already a
        // capsule (the radius IS half the height, so the top row is inset
        // by about half of it). Asking for the capsule makes the drawn
        // shape the same at every size; at `.large` it renders the same
        // bytes as the default, so the editor's tab strip is unaffected.
        control.borderShape = .capsule

        // Sync selection state (= in case SwiftUI re-evaluates the body and
        // `selection` changed but the control is still mounted).
        //
        // The bound value names a segment (= the common case): the control
        // selects it.
        //
        // The bound value names NO segment (= the segment was closed, the
        // caller's "nothing is selected" value): the control must have NO
        // selection either. It used to keep whatever segment it had, which
        // was the segment of a DIFFERENT value: the bound value said one
        // thing and the drawn selection said another. AppKit clamps the
        // index to -1 when the segment COUNT shrinks (measured 2026-10-27),
        // so the out-of-range case never survived the shrink; but the count
        // does not have to shrink for the bound value to stop naming a
        // segment (= the caller's value changed to one that is not in the
        // list), and then the stale segment stayed drawn and selectable.
        //
        // -1 is AppKit's own "no segment is selected" value (it is what the
        // control reports after its count shrinks; = measured 2026-10-27),
        // so writing it is the canonical way to say "nothing is selected".
        //
        // THE WRITE IS GUARDED (= only write when the value differs)
        // because writing a segment index into a control during a layout
        // pass re-arms the window's update-constraints pass.
        //
        // -1 is AppKit's "no segment is selected" and is accepted by the
        // control (= measured 2026-10-27). An out-of-range index THROWS
        // (`NSRangeException`), so the index must always be one the control
        // has (= the guarantee is load-bearing).
        let selectedIndex = Self.selectedSegmentIndex(for: selection.wrappedValue, in: labels)
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
        }

        // Wire target / action (= SwiftUI's NSViewRepresentable does not
        // auto-bridge `@Binding` writes back; = use the classic AppKit
        // target/action pattern; = the coordinator captures the latest
        // Binding and writes the new selection).
        coordinator.parent = self
        control.target = coordinator
        control.action = #selector(Coordinator.segmentChanged(_:))
    }

    /// The segment index the control must show as selected for a bound
    /// value.
    ///
    /// -1 (= AppKit's "no segment is selected") when the bound value names
    /// no segment: the caller's value was closed, or it is the caller's own
    /// "nothing is selected" sentinel. The control must then have NO
    /// selection, so the drawn selection can never name a DIFFERENT value
    /// than the bound one.
    ///
    /// Pure (= no control, no window): the caller writes the result into
    /// the control's `selectedSegment`.
    static func selectedSegmentIndex(for value: Selection, in labels: [Selection]) -> Int {
        labels.firstIndex(of: value) ?? -1
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
            guard index >= 0, index < parent.labels.count else { return }
            // Write the new selection back to the caller's Binding. (=
            // propagates through SwiftUI's normal state pipeline; = the
            // inspector body re-renders with the new tool; = same binding
            // contract as SwiftUI Picker).
            parent.selection.wrappedValue = parent.labels[index]
        }
    }
}
