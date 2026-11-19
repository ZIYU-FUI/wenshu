//
// ValuePopUpButton.swift · Wenshu
//
// One value out of a list of them, = shown and chosen by AppKit's own
// pop-up button.
//
// WHY THIS CONTROL
//
// A pop-up button is what Apple ships for "a flat list of mutually
// exclusive options or states" (= HIG, = pop-up-buttons, = alert-date
// 2023-10-24, = macOS), = and it is the control that "can update its
// content to indicate the current selection" (= same page). = The value it
// shows, = the menu it opens and = the state of both are the system's:
// = this file draws nothing, = sets no colour, = and chooses no radius, =
// so the control follows the OS release, = the accent colour and = the
// reader's text size the way a control is supposed to.
//
// WHY IT IS BRIDGED AND THE SEGMENTED CONTROL NEXT DOOR IS NOT
//
// MEASURED, = in this app's own process, = with the same reader the tests
// use (= `InspectorAXTree`):
//
//   * A SwiftUI `Picker(…).pickerStyle(.segmented)` IS AppKit's control
//     underneath (= the view tree carries a real `NSSegmentedControl`
//     subclass), = and it publishes itself: = an `AXRadioGroup` with one
//     `AXRadioButton` per choice, = each carrying its own selected value.
//     = Nothing is added by this app.
//   * A SwiftUI `Picker(…).pickerStyle(.menu)` renders a pop-up button and
//     publishes NOTHING (= its hosting view reads as one empty `AXGroup`,
//     = and so would it read to VoiceOver). = A value a reader cannot hear
//     and a test cannot read is not finished, = so the knob goes to the
//     AppKit control directly.
//
// The precedent for that move is this folder's own
// `LabelSegmentedControl`, = which wraps `NSSegmentedControl` for the same
// reason: = the requirement sits below what SwiftUI exposes.
//

import AppKit
import SwiftUI

/// AppKit's pop-up button, = bound to one value out of a list.
///
/// Generic over the selection type the CALLER's model holds (= `Hashable`),
/// so a caller hands it its own raw values rather than the strings drawn
/// beside them: = the label is what the reader sees, = and the selection is
/// what the model reads back.
struct ValuePopUpButton<Selection: Hashable>: NSViewRepresentable {
    /// One choice: = the value the model gets back, = and the word the
    /// menu shows.
    struct Option {
        let selection: Selection
        let label: String
    }

    /// The choices, = in the order the menu lists them.
    let options: [Option]

    /// The value the control shows as chosen.
    let selection: Selection

    /// The control's name for a reader (= what the surrounding row's label
    /// would say, = carried onto the button so VoiceOver says the knob and
    /// its position, = not one bare word).
    let name: String

    /// What happens when the reader chooses a value.
    let onChoose: (Selection) -> Void

    /// The control's size (= AppKit's own; = `.regular` is what an
    /// inspector's row carries, = and it is the only knob that changes the
    /// drawn bezel's height, = because AppKit fills the control's height).
    var controlSize: NSControl.ControlSize = .regular

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = controlSize
        button.target = context.coordinator
        button.action = #selector(Coordinator.chosen(_:))
        button.setAccessibilityLabel(name)
        //  AppKit answers a pop-up button's accessible name out of its CELL
        //  (= MEASURED: with the control's own label set, the tree still
        //  published an `AXPopUpButton` with no name), = so the name goes to
        //  both, = and VoiceOver says the knob and its position rather than
        //  one bare word.
        button.cell?.setAccessibilityLabel(name)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.controlSize = controlSize
        button.setAccessibilityLabel(name)
        button.cell?.setAccessibilityLabel(name)
        reload(button)
        select(button)
    }

    /// The size the control is given.
    ///
    /// A representable's own frame is NOT set by a SwiftUI `.frame` modifier
    /// (= MEASURED, = and recorded in `LabelSegmentedControl`), = so the size
    /// is decided here. = The control takes its own fitting width, = and never
    /// grows into the row: = a pop-up that fills an inspector's value column
    /// reads as a field waiting for text, = while a pop-up sized to its own
    /// longest choice reads as the control it is (= what Apple's own
    /// inspectors ship). = A narrower proposal is honoured, = because a row
    /// that cannot fit the control must not have it drawn over its neighbour.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView button: NSPopUpButton,
        context: Context
    ) -> CGSize? {
        let fitting = button.intrinsicContentSize
        return CGSize(width: proposal.width ?? fitting.width, height: fitting.height)
    }

    /// The menu's items, = rebuilt only when the choices actually changed
    /// (= a menu rebuilt on every pass would close under the reader's hand
    /// while it was open).
    private func reload(_ button: NSPopUpButton) {
        let labels = options.map(\.label)
        guard button.itemTitles != labels else { return }
        button.removeAllItems()
        for (index, label) in labels.enumerated() {
            button.addItem(withTitle: label)
            button.item(at: index)?.tag = index
        }
    }

    /// Which item carries the chosen value.
    private func select(_ button: NSPopUpButton) {
        guard let index = options.firstIndex(where: { $0.selection == selection }) else {
            //  A value the list does not carry is the caller's state, = not
            //  the control's to invent: = no item is marked chosen, = and
            //  the button reads its first title rather than a lie. = (No
            //  caller of this control is built that way today; = the knob's
            //  position always comes from the same list.)
            button.selectItem(at: -1)
            return
        }
        button.selectItem(at: index)
    }

    /// The button's own action, = which is where AppKit's choice becomes
    /// the caller's value (= `@MainActor`, = the same shape
    /// `LabelSegmentedControl`'s coordinator carries, = because AppKit fires
    /// a control's action on the main thread and the caller's model lives
    /// there).
    @MainActor
    final class Coordinator: NSObject {
        var parent: ValuePopUpButton

        init(parent: ValuePopUpButton) {
            self.parent = parent
        }

        @objc func chosen(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.options.indices.contains(index) else { return }
            parent.onChoose(parent.options[index].selection)
        }
    }
}

// MARK: - Measuring the column

extension ValuePopUpButton where Selection == String {
    /// How wide the system's own button would be for these words.
    ///
    /// The page asks the control, = and the control asks AppKit: = the
    /// number comes back out of `NSPopUpButton.intrinsicContentSize`,
    /// = which already carries the bezel, = the chevrons and = the font
    /// the reader is running under. = Five knobs in one column cannot
    /// agree on a width by guessing one; = they agree by measuring the
    /// widest thing all five buttons can be asked to say.
    @MainActor
    static func fittingWidth(forTitles titles: [String], controlSize: NSControl.ControlSize = .regular) -> CGFloat {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = controlSize
        for title in titles { button.addItem(withTitle: title) }
        return button.intrinsicContentSize.width
    }
}
