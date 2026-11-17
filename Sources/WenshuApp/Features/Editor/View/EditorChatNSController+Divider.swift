// EditorChatNSController+Divider.swift · Wenshu
//
// The divider (= the latch, the action, and the stored share).
//
// This file is one part of the editor's split container. The
// controller's declaration, its constants and its state live in
// `EditorChatNSController.swift`; the parts that live here are
// extensions of that class, and their bodies are the ones the
// controller had before the file was split.

import AppKit

extension EditorChatNSController {
    /// The divider's latch: the state that spans layout passes.
    ///
    /// Why it is a value type and not five fields on the controller:
    /// the latch's LIFECYCLE is where the defect lived (= the resize
    /// latch was set when the axis moved and was released only by a
    /// repair write, = so a resize that ended ON the asserted share
    /// left the latch set, = and the user's NEXT drag was then
    /// answered with a repair that overwrote the drag), and a
    /// lifecycle can only be tested if it can be driven without a
    /// window.
    @MainActor
    struct DividerLatch {
        /// Whether the divider still has to be POSITIONED for the
        /// current arrangement (= the seed has not run yet).
        ///
        /// Why the divider is positioned once and not on every layout
        /// pass: a write into the split during the layout pass re-arms
        /// the window's "Update Constraints in Window" pass (= the pass
        /// AppKit's runaway-layout guard counts), and a resize delivers
        /// a layout pass per frame (= a zoom animation's frames, = a
        /// widening drag's steps). Measured on the running app: the
        /// guard's count crossed the window's view count (= 327 against
        /// a limit of 321) during exactly those frames.
        ///
        /// So the divider is positioned once, when the layout has
        /// settled, and AppKit scales it with the axis from there (= a
        /// divider positioned once holds its share through a 40-step
        /// zoom and a 40-step narrowing, = 0.3006 and 0.3002).
        private(set) var seedPending = true

        /// Whether a resize is waiting to be reconciled (= the axis
        /// moved and the layout has not settled onto the asserted
        /// share yet).
        ///
        /// Why it is released when the resize ends ON the share: the
        /// release used to happen only inside the repair write, so a
        /// resize that ended on the share left the latch set, and the
        /// next drift (= the user's next drag) was answered with a
        /// repair that overwrote the drag.
        private(set) var resizePending = false

        /// The number of consecutive layout passes whose axis extent did
        /// not change (= the layout has settled).
        ///
        /// Why the count and not a flag: the frames a layout pass reads
        /// are the PREVIOUS pass's frames (= the layout catches up one
        /// pass later), so the share read on the first pass whose axis
        /// has not moved is still the position from before the move.
        private(set) var settledPasses = 0

        /// The extent of the arrangement's axis (= the split's own extent
        /// on the axis the arrangement carries) as of the previous layout
        /// pass. A change means the axis MOVED (= a resize is in flight).
        private(set) var lastAxisExtent: CGFloat?

        /// The number of layout passes before the last write into the
        /// split shows up in the frames.
        ///
        /// Why it is counted: a write into the split changes the divider
        /// position, and the frames report it only on the NEXT layout pass
        /// (= the frames a pass reads are the previous pass's). Reading
        /// the share before the write has landed reports the position from
        /// before the write, and adopting it would undo the write.
        private(set) var framesPending = 0

        /// What one layout pass does with the divider.
        ///
        /// The shares are the LEADING pane's share (= the share the
        /// divider position and the fractions both express).
        ///
        /// - Parameters:
        ///   - axisExtent: the arrangement's axis extent now.
        ///   - observedLeading: the leading pane's thickness in the
        ///     frames the layout hands out (= the previous pass's).
        ///   - assertedShare: the share the divider is asserted at.
        mutating func pass(
            axisExtent: CGFloat,
            observedLeading: CGFloat,
            assertedShare: CGFloat
        ) -> EditorChatNSController.DividerAction {
            // Whether the axis MOVED since the previous layout pass (= a
            // resize is in flight).
            //
            // The frames a layout pass reads are the PREVIOUS pass's
            // frames (= the layout catches up one pass later), so the
            // share is read against the extent those frames were laid
            // out for (= the previous extent). Reading it against the
            // current extent would report a share the layout has not
            // reached.
            let previousExtent = lastAxisExtent
            let axisMoved = previousExtent.map {
                abs($0 - axisExtent) > EditorChatNSController.extentTolerance
            } ?? false
            if axisMoved {
                settledPasses = 0
                resizePending = true
            } else if previousExtent != nil {
                settledPasses += 1
            }
            lastAxisExtent = axisExtent

            let observedExtent = previousExtent ?? axisExtent
            guard observedExtent > 0 else { return .none }
            let observedShare = observedLeading / observedExtent

            let pendingFrames = framesPending
            let action = EditorChatNSController.dividerAction(
                axisMoved: axisMoved,
                settledPasses: settledPasses,
                seedPending: seedPending,
                resizePending: resizePending,
                framesPending: pendingFrames,
                observedShare: observedShare,
                assertedShare: assertedShare
            )
            framesPending = 0
            switch action {
            case .none:
                // The resize has ended and the layout still holds the
                // asserted share: nothing is owed, so the latch is
                // RELEASED here (= the repair was not needed).
                //
                // Why the release matters: the latch used to be
                // released only by the repair write, so it stayed set
                // after a resize that ended on the share, and the next
                // drift (= the user's next drag) was read as "the
                // resize left the share off" and answered with a
                // repair that overwrote the drag.
                //
                // The guard keeps the release out of the resize itself:
                // the settle count is reset on every pass whose axis
                // moved, so during a resize it is 0 and the latch
                // stays set (= the repair stays reachable).
                if resizePending && !axisMoved && settledPasses >= 1 && pendingFrames == 0 {
                    resizePending = false
                }
            case .adopt:
                break
            case .assertAt:
                seedPending = false
                resizePending = false
                framesPending = 1
            }
            return action
        }
    }

    /// What a layout pass does with the divider.
    enum DividerAction: Equatable {
        /// Write nothing (= the layout is mid-resize, or it already
        /// agrees with the assert).
        case none
        /// The user moved the divider: adopt this share as their own.
        case adopt(CGFloat)
        /// Position the divider at this share (= the seed, or a repair
        /// after a resize left the share off).
        case assertAt(CGFloat)
    }

    /// The decision a layout pass makes about the divider.
    ///
    /// Why it is a pure function of the pass's facts: the decision is
    /// the whole fix (= a write into the split during the layout pass
    /// re-arms the window's update-constraints pass, and that count
    /// is what AppKit's runaway-layout guard counts), and a decision
    /// that cannot be exercised without a window cannot be tested.
    ///
    /// The shares are the LEADING pane's share (= the share the
    /// divider position and the fractions both express).
    static func dividerAction(
        axisMoved: Bool,
        settledPasses: Int,
        seedPending: Bool,
        resizePending: Bool,
        framesPending: Int,
        observedShare: CGFloat,
        assertedShare: CGFloat,
        tolerance: CGFloat = shareTolerance
    ) -> DividerAction {
        // A RESIZE is in flight: the axis changes on every frame of
        // the animation (= a zoom's frames, = a widening drag's
        // steps), and writing the target on every one of those frames
        // re-arms the window's update-constraints pass once per frame.
        // AppKit scales the divider with the axis (= measured: a
        // divider positioned once holds its share through a 40-step
        // zoom and a 40-step narrowing), so the share survives the
        // animation without a write per frame.
        if axisMoved {
            return .none
        }

        // The layout has not settled yet: the frames a pass reads are
        // the previous pass's, so the first pass whose axis has not
        // moved still reads the position from before the move.
        guard settledPasses >= 1 else { return .none }

        // The last write has not shown up in the frames yet: reading
        // the share now reports the position from before the write,
        // and adopting it would undo the write.
        guard framesPending == 0 else { return .none }

        let drifted = abs(observedShare - assertedShare) > tolerance

        // The resize has ended and the layout did not land on the
        // asserted share (= a pane hit its floor). The share is put
        // back ONCE, here, and not on every frame.
        if resizePending {
            return drifted ? .assertAt(assertedShare) : .none
        }

        // The seed: the divider is positioned once, when the layout has
        // settled, and AppKit scales it with the axis from there.
        if seedPending {
            return .assertAt(assertedShare)
        }

        // The axis has been still and the divider is somewhere else:
        // the user dragged it. The drag is adopted (= the assert must
        // never write over it, = the drag is eaten otherwise).
        return drifted ? .adopt(observedShare) : .none
    }

    /// The share of the axis the divider holds, as the stored
    /// payload records it.
    ///
    /// AppKit writes the frames as an array of strings under
    /// "NSSplitView Subview Frames <name>", each "x, y, width,
    /// height, collapsed, ...". The split's axis carries the panes'
    /// thickness: the editor is above the chat, so the axis is the
    /// height.
    func storedShare(for name: String) -> CGFloat? {
        let key = "NSSplitView Subview Frames \(name)"
        guard let frames = UserDefaults.standard.object(forKey: key) as? [String] else {
            return nil
        }
        return Self.share(fromFrames: frames)
    }

    /// The share of the axis the divider holds, read from AppKit's
    /// stored frames.
    ///
    /// `setPosition(p)` sets the FIRST pane's thickness (= measured
    /// against the running split), so the share is the first pane's
    /// thickness over the two panes' thickness together.
    ///
    /// The frames are in the panes' own order (= the editor first,
    /// because the editor is above the chat), and the axis is the
    /// height (= the divider runs across).
    ///
    /// The numbers carry a space after every comma, so they have to
    /// be trimmed before they parse (= Swift's `Double(" 0.0")` is
    /// nil, and an untrimmed parse silently reads no share at all,
    /// which puts the divider back at the middle and reintroduces
    /// the runaway layout).
    static func share(fromFrames frames: [String]) -> CGFloat? {
        guard frames.count >= 2 else { return nil }
        func numbers(_ frame: String) -> [CGFloat] {
            frame.components(separatedBy: ",").compactMap {
                Double($0.trimmingCharacters(in: .whitespaces)).map { CGFloat($0) }
            }
        }
        let first = numbers(frames[0])
        let second = numbers(frames[1])
        guard first.count >= 4, second.count >= 4 else { return nil }
        let firstThickness = first[3]
        let secondThickness = second[3]
        let total = firstThickness + secondThickness
        guard total > 0 else { return nil }
        return firstThickness / total
    }
}
