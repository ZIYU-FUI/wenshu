// EditorChatNSController+ChatZone.swift · Wenshu
//
// The chat zone's visibility (= one fact, one owner).
//
// WHY THIS FILE EXISTS
// ====================
//
// "Is the chat zone showing?" had TWO answers, and they were not
// connected:
//
//   * the AppKit split item's own `.isCollapsed` (= = the thing that
//     draws the zone, animates it, persists it, and reports it), and
//   * `WorkspaceUIState.chatVisible` (= = a flag the View menu wrote
//     and the LLM-can-edit gate read).
//
// The menu's setter wrote the flag and NOTHING read it to change the
// picture, so pressing (⌥⌘K) moved no pixels while it DID move the
// gate (= = `EditorView`'s `surface.isEditable`) = = the user's document
// silently became read-only and the screen stayed the same. And the
// other direction: the reader dragging the zone shut (= = or the
// autosave restoring it closed at launch) changed the picture and left
// the flag saying "visible", so the gate read "editable" while the
// LLM-editing condition was visually in force.
//
// THIS FILE MAKES THE SPLIT ITEM THE OWNER:
//
//   * the menu ASKS (`WorkspaceUIState.requestChatZoneToggle()`), and
//     this controller carries the request out (= = `toggleChatZone()`,
//     = = AppKit's own collapse, with its own animation);
//   * the split item's state is mirrored back
//     (`workspaceUI.chatVisible`), and that mirror is what the SwiftUI
//     side reads (= = the menu's checkmark, the gate).
//
// So the menu's checkmark and the picture cannot disagree, and neither
// can the gate.
//
// HOW THE MIRROR IS KEPT TRUE
// ===========================
//
// The mirror is written from ONE place: `splitViewDidResizeSubviews`.
// That is the split's own report that the subviews moved (= = a
// collapse, an expand, a drag, a layout) = = and it fires for the
// drag path and for the restore path too (= = not only for the menu),
// which is what the old flag could not be.
//
// Why NOT the notification: `NSSplitViewDidResizeSubviewsNotification`
// is posted by the split view (= = `splitView`), and this controller
// IS the split view's delegate (= = `NSSplitViewController` is its own
// split view's delegate). Swapping the delegate to get the callback
// would take away AppKit's own answers about the divider and the
// automatic bounds, = = a second behaviour change wearing the costume
// of a wiring fix. The delegate method is the same fact, read from
// the same place, with no second mechanism.

import AppKit
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "editorchatnscontroller")

extension EditorChatNSController {
    /// The workspace's UI state (= the chat zone's mirror and the
    /// reader's toggle request), when the host handed one over.
    private var workspaceUIForChatZone: WorkspaceUIState? {
        environment.workspaceUI
    }

    /// Wake the layout so a pending request is ANSWERED.
    ///
    /// WHY THIS EXISTS: the request is read in the layout pass (= = the
    /// split must not be moving, = = the collapse animates), but a
    /// layout pass only happens when something ELSE moves. So the ask
    /// needed its own wake, and without it the request sat unread
    /// (= = the menu row toggled its checkmark and the zone stayed
    /// exactly where it was).
    ///
    /// THE WAKE IS THE PLATFORM'S OWN: `needsLayout` schedules the next
    /// layout pass (= = "mark the receiver as needing layout"), and
    /// `viewDidLayout` is that pass. This is the same shape as the
    /// transcript's own follow (= = the request's id is READ in a body
    /// and the wake is EXPLICIT; = = its comment records that without
    /// the wake the request "never happened").
    ///
    /// It is idempotent: a second wake before the pass changes nothing
    /// (= = the layout pass runs once, = = and the answer is written
    /// once, = = because the answer is keyed on the request's own id).
    func wakeForChatZoneToggleRequestIfPending(_ asked: Int) {
        guard asked != answeredChatZoneToggleRequest else { return }
        view.needsLayout = true
        wenshuLogger.info("[wenshu.editorChat] the chat zone's toggle request \(asked) wakes the layout")
    }

    /// Answer the reader's toggle request, if there is one waiting.
    ///
    /// It is called from the layout pass (= = after the split has
    /// settled), because a collapse ANIMATES: the request must not be
    /// answered while the split is still moving (= = and the answer
    /// (= = the mirror) is written by the resize callback, = = which
    /// fires when the animation ends).
    func answerChatZoneToggleRequestIfAny() {
        guard let ui = workspaceUIForChatZone else { return }
        let asked = ui.chatZoneToggleRequest
        guard asked != answeredChatZoneToggleRequest else { return }
        answeredChatZoneToggleRequest = asked
        wenshuLogger.info("[wenshu.editorChat] the chat zone's toggle request \(asked) is answered")
        toggleChatZone()
    }

    /// The split says its subviews moved (= = a collapse, an expand, a
    /// drag, a layout): the chat zone's visibility is whatever the
    /// split item says it is.
    ///
    /// This is the ONE writer of the mirror (= = `WorkspaceUIState`'s
    /// `chatVisible`), and it is the AppKit side, = = because the
    /// split item is the owner of the fact.
    ///
    /// It is an OVERRIDE of the split's own delegate method (= = the
    /// split view's delegate is this controller, = = by Apple's own
    /// design: "The NSSplitViewController is set as the delegate of its
    /// managed NSSplitView"), and it calls `super` first (= = Apple's
    /// header asks for exactly that: "Any overrides of NSSplitViewDelegate
    /// methods must call super"), so AppKit's own answers about the
    /// divider and the automatic bounds still happen.
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        // Only our own split (= = the report is about the split view
        // that changed).
        guard let split = notification.object as? NSSplitView,
              split === splitView
        else { return }
        mirrorChatZoneVisibility()
    }

    /// Start mirroring the chat zone's visibility.
    ///
    /// There is nothing to REGISTER: `NSSplitViewController` IS the
    /// delegate of the split view it manages (Apple's own header: "The
    /// NSSplitViewController is set as the delegate of its managed
    /// NSSplitView"), so the split's report arrives at
    /// `splitViewDidResizeSubviews(_:)` below (= = which the controller
    /// overrides, = = as Apple's header asks: "Any overrides of
    /// NSSplitViewDelegate methods must call super").
    ///
    /// Taking the delegate over would have been the wrong way round: the
    /// header also says that changing the split's delegate "will cause
    /// an exception to be thrown".
    func startWatchingChatZoneVisibility() {
        // The zone may already be collapsed (= = the autosave restored it
        // that way), so the mirror starts from the split item's own
        // state (= = not from a default).
        mirrorChatZoneVisibility()
    }

    /// Write the split item's own visibility into the mirror.
    func mirrorChatZoneVisibility() {
        guard let ui = workspaceUIForChatZone else { return }
        let visible = isChatZoneVisible
        guard ui.chatVisible != visible else { return }
        ui.chatVisible = visible
        wenshuLogger.info("[wenshu.editorChat] the chat zone's mirror follows the split item (visible: \(visible))")
    }
}
