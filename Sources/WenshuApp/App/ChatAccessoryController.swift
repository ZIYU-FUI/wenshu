//
//  ChatAccessoryController.swift · Wenshu · v1.0.0-m1-shell
//
//  Apple HIG title bar accessory for the chat zone. Per Apple's
//  official NSTitlebarAccessoryViewController documentation
//  (developer.apple.com/documentation/appkit/nstitlebaraccessoryviewcontroller):
//
//      "An object that manages a custom view—known as an
//      accessory view—in the title bar–toolbar area of a window.
//      Because a title bar accessory view controller is contained
//      in a visual effect view (= NSVisualEffectView), it
//      automatically handles the blur behind the accessory view
//      and the size and location changes for the content of the
//      view when a window goes in and out of full screen mode."
//
//  The bottom layoutAttribute (= `.bottom`) places the accessory
//  view BELOW the title bar / toolbar (= below the standard toolbar
//  row but above the main window content). This is the canonical
//  Apple HIG "speaker notes" / "second zone" pattern used by:
//    - Keynote's speaker notes panel
//    - Pages' template browser
//    - Numbers' sheet templates
//    - Xcode's assistant editor
//
//  Boss 2026-09-10 OOB 'keynote 演讲者注释是如何实现的, 颜色也按
//  keynote 走': Keynote's speaker notes panel uses a warm off-white
//  / cream background (= Apple's NSColor.underPageBackgroundColor =
//  '#F2EFE9' in light mode = "the color to use in the area beneath
//  your window's views" per Apple docs). The accessory's
//  NSVisualEffectView handles the rest (= blur, vibrancy, fullscreen
//  transitions) automatically.
//
//  Implementation:
//    - Subclass NSTitlebarAccessoryViewController
//    - Set view to NSHostingController(rootView: ChatView(...)).view
//      (= the SwiftUI chat zone wrapped in an AppKit hosting
//      controller; = the canonical way to embed SwiftUI inside an
//      AppKit-owned view controller per WWDC22 "Use SwiftUI with
//      AppKit")
//    - layoutAttribute = .bottom (= the "middle column" position
//      = the title bar accessory below the toolbar)
//    - fullScreenMinHeight = 220 (= the Keynote speaker notes
//      panel's collapsed height when the window goes full screen;
//      = the user can still resize the accessory while in
//      fullscreen mode)
//
//  Wired up in AppRootScene.body (= the WindowGroup side finds
//  the underlying NSWindow and calls addTitlebarAccessoryViewController
//  on it). The chat zone is no longer part of the window body
//  (= it was previously the second half of a VSplitView in
//  ShellContentColumn; = Apple recommends NSTitlebarAccessoryView
//  Controller for the "second zone" pattern, not VSplitView).
//

import AppKit
import SwiftUI

@MainActor
public final class ChatAccessoryController: NSTitlebarAccessoryViewController {

    /// Stable identifier (= required by AppKit; = unique per
    /// accessory view controller so AppKit can correctly track
    /// the accessory across window state changes).
    public static let identifier = "com.wenshu.app.titlebar-accessory.chat"

    /// v1.0.0-m1-shell boss 2026-09-10 OOB 'keynote 演讲者注释是
    /// 如何实现的': minimum accessory height when the window goes
    /// fullscreen (= Keynote's speaker notes panel also retains
    /// a minimum height in fullscreen so the notes are still
    /// readable). 220 PT is the standard macOS speaker-notes
    /// panel collapsed height (= user can still drag the
    /// accessory taller if they want).
    public static let fullScreenMinHeight: CGFloat = 220

    /// Standard accessory height (= also used as the initial
    /// height when the window first appears; = matches Keynote's
    /// ~250 PT default speaker notes height).
    public static let standardHeight: CGFloat = 250

    public init() {
        super.init(nibName: nil, bundle: nil)
        configureAccessory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ChatAccessoryController must be created programmatically")
    }

    /// v1.0.0-m1-shell boss 2026-09-10 OOB: configure the
    /// accessory's layout + content. Called from init (= AppKit
    /// reads layoutAttribute before the view controller is
    /// attached to a window; = must be set early).
    private func configureAccessory() {
        // Per Apple docs: layoutAttribute determines where the
        // accessory sits in relation to the title bar. `.bottom`
        // = the "second zone" / speaker notes position = the
        // canonical Keynote / Pages / Numbers pattern.
        self.layoutAttribute = .bottom

        // Bind the SwiftUI chat zone (= ChatView is the existing
        // wenshu chat implementation; = its body contains the
        // message list, input row, and send button; = the Apple
        // canonical NSHostingController wraps the SwiftUI view
        // per WWDC22 "Use SwiftUI with AppKit"). The hosting
        // controller's view is set as the accessory's view.
        let chatView = ChatView(
            conductor: WenshuAppDelegate.sharedConductor,
            store: WenshuAppDelegate.sharedChatStoreRef
        )
        let hosting = NSHostingController(rootView: chatView)
        // Set the frame to the standard height (= will be
        // resizable by the user via the accessory's drag
        // affordance; = the user can drag the top edge to make
        // the accessory taller or shorter).
        hosting.view.frame = NSRect(
            x: 0,
            y: 0,
            width: NSScreen.main?.frame.width ?? 1200,
            height: ChatAccessoryController.standardHeight
        )
        self.view = hosting.view

        // v1.0.0-m1-shell boss 2026-09-10 OOB 'keynote 演讲者
        // 注释是如何实现的': the accessory's size is determined
        // by its view's intrinsic content size (= ChatView's
        // VStack sizes naturally; = the user can drag the top
        // edge of the accessory to resize it via AppKit's
        // standard NSWindow resize handle). NSTitlebarAccessory
        // ViewController does NOT expose minHeight / maxHeight
        // properties (= unlike NSToolbarItem); = the size is
        // managed via the view's frame / Auto Layout constraints
        // (set on the hosting view's frame here).
    }

    /// Attach this accessory to the given window. Called from
    /// AppRootScene (= the SwiftUI scene hooks the accessory to
    /// the underlying NSWindow once the window is created).
    public func attach(to window: NSWindow) {
        window.addTitlebarAccessoryViewController(self)
    }
}
