//
//  Features/Editor/View/PreviewPaneCardCoverMenu.swift
//
//   : CardCoverMenu.
//  The cover items one card's right-click menu offers.
//
//  The menu is a RULE and not a pile of `if`s in a view: it is a pure
//  function of what the card holds and of what the user has switched
//  on, so a test can ask what the menu says without a window.
//
//  THREE RULES:
//
//  1. An item that MAKES a cover appears only while the automatic
//     cover switch is on. The switch is the user's answer to "make
//     covers for me", and a menu that offers to spend an allowance the
//     user has not asked for is noise the user dismisses every time.
//  2. An item that REMOVES a cover appears whenever there is something
//     to remove, whatever the switch says. The switch governs what the
//     app may CREATE, never what the user may DELETE: a cover the user
//     does not want stays removable, and so does a moving cover.
//  3. "Make it move" appears only when the card has a picture and no
//     clip. A card that already carries a clip is one the user has
//     already paid for, so the menu offers the removal instead of a
//     second clip.
//
//  Rule 3 is the app's own decision and NOT Apple's: Apple's
//  context-menus article says nothing about a card that already carries
//  a clip, and the video allowance is a handful of clips a day that
//  only the user may spend.
//

import Foundation

/// The cover items one card's right-click menu offers.
struct CardCoverMenu: Equatable {
    /// What the user can do to the card's cover.
    enum Action: Hashable {
        /// Draw a cover for a card that has none.
        case generateCover

        /// Draw a new cover for a card that has one.
        case regenerateCover

        /// Remove the card's picture.
        case removeCover

        /// Make the card's picture move.
        case makeDynamicCover

        /// Remove the card's moving cover.
        case removeDynamicCover
    }

    /// What failed, and why.
    enum Failure: Hashable {
        /// The picture's last attempt failed.
        case still(String)

        /// The clip's last attempt failed.
        case clip(String)
    }

    /// The actions, in the order the menu shows them.
    ///
    /// The order groups the two kinds: what the app MAKES first (= the
    /// picture, then the motion), and what the user DISCARDS after it
    /// (= the picture, then the motion). The two removals sit together
    /// because they are one decision about one cover.
    var actions: [Action] = []

    /// The failures the card carries, with their reasons.
    var failures: [Failure] = []

    /// Whether the menu has nothing at all to say about the cover.
    var isEmpty: Bool {
        actions.isEmpty && failures.isEmpty
    }
}

extension Card {
    /// The cover items this card's menu offers.
    ///
    /// The facts come from the caller (= the card does not know which
    /// card it is), and the switch is read HERE (= the menu opens long
    /// after the card was drawn, and the switch lives in another
    /// window, so a card drawn before the user flipped it must not
    /// carry the old answer into the menu).
    var coverMenu: CardCoverMenu {
        var menu = CardCoverMenu()
        let generationEnabled = isCoverGenerationEnabled()
        if generationEnabled, onGenerateCover != nil {
            menu.actions.append(hasCover ? .regenerateCover : .generateCover)
        }
        if generationEnabled, hasCover, !hasDynamicCover, onMakeDynamicCover != nil {
            menu.actions.append(.makeDynamicCover)
        }
        if hasCover, onRemoveCover != nil {
            menu.actions.append(.removeCover)
        }
        if hasDynamicCover, onRemoveDynamicCover != nil {
            menu.actions.append(.removeDynamicCover)
        }
        if let stillError = coverErrorMessage, !stillError.isEmpty {
            menu.failures.append(.still(stillError))
        }
        if let clipError = coverClipErrorMessage, !clipError.isEmpty {
            menu.failures.append(.clip(clipError))
        }
        return menu
    }

    /// Whether this card carries a moving cover.
    ///
    /// The clip's own file decides (= a clip whose file is gone is no
    /// clip), and the caller hands the card that file's URL.
    var hasDynamicCover: Bool {
        coverVideoURL != nil
    }
}
