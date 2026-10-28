import SwiftUI

/// The layout the client renders on a device.
///
/// The width picks the shape: a compact width is one column, a regular
/// width is two. The foldable-native API refines how the two columns are
/// drawn, and only where the system offers it and the display carries a
/// fold, so both sides of that gate draw the same shape.
struct AdaptiveLayout: Equatable, Sendable {
    /// The columns the layout draws.
    enum Shape: Equatable, Sendable {
        /// One column.
        case stack
        /// Two columns.
        case split
    }

    /// The container that draws the columns.
    enum Drawing: Equatable, Sendable {
        /// The size-class layout: the split an iPad gets.
        case sizeClassLayout
        /// The foldable-native arrangement: the columns sit on separate
        /// sides of a fold.
        case foldableArrangement
    }

    /// Whether a fold splits the display.
    enum Fold: Equatable, Sendable {
        /// One flat display: an iPad, or a foldable opened flat.
        case flat
        /// A fold splits the display into two regions.
        case folded
    }

    /// The columns the layout draws.
    var shape: Shape
    /// The container that draws the columns.
    var drawing: Drawing

    /// The layout for a width, the availability of the foldable-native API
    /// and the fold the display carries.
    ///
    /// The width picks the columns. The API only refines how the columns
    /// are drawn, so both sides of the availability gate render the same
    /// shape.
    ///
    /// The availability of the API is not evidence of a fold: it says the
    /// system can place views around one, not that one is there. A device
    /// opened flat carries no fold, so it draws the layout an iPad draws,
    /// and the native arrangement is reachable only where a fold actually
    /// splits the display.
    ///
    /// - Parameters:
    ///   - sizeClass: The horizontal size class of the current width. A
    ///     width the system does not classify takes the wider layout.
    ///   - foldableNativeAvailable: Whether the system offers the
    ///     foldable-native layout.
    ///   - fold: Whether a fold splits the display. A caller that does not
    ///     know the posture gets the flat display, which is the layout
    ///     every device without a fold draws.
    static func decide(
        sizeClass: UserInterfaceSizeClass?,
        foldableNativeAvailable: Bool,
        fold: Fold = .flat
    ) -> AdaptiveLayout {
        let shape: Shape = sizeClass == .compact ? .stack : .split
        let isFoldedLayout = shape == .split && foldableNativeAvailable && fold == .folded
        let drawing: Drawing = isFoldedLayout ? .foldableArrangement : .sizeClassLayout
        return AdaptiveLayout(shape: shape, drawing: drawing)
    }

    /// Whether the system offers the foldable-native layout.
    ///
    /// The product ships on a floor below these APIs, so the size-class
    /// layout is the layout on every system that does not offer them.
    static var foldableNativeAvailable: Bool {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }
}

/// The one container that holds the layout choice.
///
/// The decision is read from the width and the fold on every pass, so a
/// device that changes shape lands on the layout its current state asks
/// for: a foldable that unfolds takes the split, a foldable that folds
/// back takes the single column.
///
/// The caller hands over what each shape draws, so the container holds
/// the choice and not the content: the compact width never draws the
/// sidebar, and the two columns the split draws are the caller's.
struct AdaptiveLayoutContainer<Compact: View, Sidebar: View, Detail: View>: View {
    /// What the compact width draws.
    let compact: Compact
    /// The first column the split draws.
    let sidebar: Sidebar
    /// The second column the split draws.
    let detail: Detail

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hingeReportsFold = false
    @State private var divisionSplitsDisplay = false

    var body: some View {
        columns
            .modifier(HingeProbe(hingeReportsFold: $hingeReportsFold))
            .modifier(DivisionProbe(divisionSplitsDisplay: $divisionSplitsDisplay))
    }

    /// The fold the display carries.
    ///
    /// The hinge posture and the reserved division describe the same fold
    /// from two directions, and either one alone is enough to know a fold
    /// splits the display.
    private var fold: AdaptiveLayout.Fold {
        hingeReportsFold || divisionSplitsDisplay ? .folded : .flat
    }

    /// The layout the current width and fold ask for.
    private var layout: AdaptiveLayout {
        AdaptiveLayout.decide(
            sizeClass: horizontalSizeClass,
            foldableNativeAvailable: AdaptiveLayout.foldableNativeAvailable,
            fold: fold
        )
    }

    /// The columns the shape asks for.
    @ViewBuilder
    private var columns: some View {
        switch layout.shape {
        case .stack:
            compact
        case .split:
            splitColumns
        }
    }

    /// The two columns, drawn by the container the decision names.
    @ViewBuilder
    private var splitColumns: some View {
        switch layout.drawing {
        case .sizeClassLayout:
            sizeClassColumns
        case .foldableArrangement:
            foldableColumns
        }
    }

    /// The two columns drawn by the size-class layout.
    ///
    /// This is the layout on every system that does not offer the
    /// foldable-native arrangement, and it draws the same two columns the
    /// arrangement draws.
    private var sizeClassColumns: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    /// The two columns drawn by the foldable-native arrangement.
    ///
    /// The arrangement is what a folded display gets where the system
    /// offers it; the size-class layout is the layout everywhere else.
    @ViewBuilder
    private var foldableColumns: some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            FoldableColumns(sidebar: sidebar, detail: detail)
        } else {
            sizeClassColumns
        }
        #else
        sizeClassColumns
        #endif
    }
}

/// Reads the hinge posture the system reports.
///
/// The posture changes when the device folds, so this reading is what
/// makes the layout recomputed rather than latched.
private struct HingeProbe: ViewModifier {
    @Binding var hingeReportsFold: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                hingeReportsFold = context.hinge.map { $0.status != .fullyOpen } ?? false
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Reads the regions the display reserves.
///
/// The fold is a division: an area where content splits into separate
/// regions. The system hands back the divisions that overlap the view and
/// are active, so a display with no active division carries no fold and
/// reads as one flat display.
private struct DivisionProbe: ViewModifier {
    @Binding var divisionSplitsDisplay: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: Bool.self, of: { proxy in
                !proxy.reservedRegions(kind: .division).isEmpty
            }, action: { _, isDivided in
                divisionSplitsDisplay = isDivided
            })
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if os(iOS)
/// The two columns drawn by the foldable-native arrangement.
///
/// The arrangement places the columns on separate sides of the fold, so a
/// foldable held like a book keeps each column on its own side of the
/// crease. Apple asks that an arrangement view sit outside the other
/// containers that lay out views, so the columns are the plain views the
/// caller hands over.
///
/// The arrangement carries the fold on its own, so the client does not
/// place the columns around the division itself: Apple asks that two
/// related views use an arrangement view instead of a hand-placed split.
@available(iOS 27.1, *)
private struct FoldableColumns<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail

    var body: some View {
        ArrangementView {
            sidebar
        } secondary: {
            detail
        }
        .arrangementViewStyle(.split)
    }
}
#endif
