//
//  GlassIconButton.swift · Wenshu · v1.64f
//
//  v1.64f boss 2026-09-20 'apply the prototype to wenshu directly':
//  extract the Apple macOS 27 native NSButton(bezelStyle: .glass)
//  NSViewRepresentable bridge from the v1.64e spike prototype into
//  a shared file (= the canonical chat input button used by
//  ChatView for attach / agent path / turn counter / sub-agent /
//  send / goal).
//
//  Per developer.apple.com/documentation/appkit/nsbutton/bezelstyle-
//  swift.enum/glass + iTerm2 PSMTahoeOverflowButton reference impl:
//  the canonical 'NSToolbar circular Liquid Glass icon button'
//  (= the same chrome Apple's NSToolbar uses for its icon items)
//  requires THREE settings on NSButton:
//    1. bezelStyle = .glass — the Liquid Glass bezel material
//    2. borderShape = .circle — the circular border shape (= without
//       this the glass bezel renders as a rectangular panel)
//    3. imagePosition = .imageOnly — hide the title, show only the
//       SF Symbol
//  PLUS a heightAnchor constraint = 32 PT (= Apple HIG
//  NSControl.controlSize = .regular chat input tap target).
//
//  No SwiftUI chain modifiers needed (= no .buttonStyle /
//  .buttonBorderShape / .controlSize / .labelStyle / .tint /
//  .glassEffect) — the NSButton handles all the chrome itself.
//

import SwiftUI
import AppKit

/// A SwiftUI wrapper for the Apple macOS 27 native circular Liquid Glass
/// icon button (= the same chrome NSToolbar uses for its toolbar items).
///
/// Usage:
/// ```swift
/// GlassIconButton(systemName: "paperclip", help: "Attach") { /* action */ }
/// GlassIconButton(systemName: "paperplane", help: "Send") { /* action */ }
/// ```
///
/// The button is 32 PT tall (= Apple HIG canonical chat input tap target).
struct GlassIconButton: NSViewRepresentable {
    let systemName: String
    let help: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        // 1. Liquid Glass bezel (= the macOS 26+ glass material).
        button.bezelStyle = .glass
        // 2. Circular border shape (= without this, the glass bezel
        //    renders as a rectangular panel = the bug fixed in v1.64e).
        button.borderShape = .circle
        // 3. Icon-only rendering (= the macOS 26+ HIG default for
        //    toolbar items that carry a single SF Symbol).
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: help)
        button.target = context.coordinator
        button.action = #selector(Coordinator.tap(_:))
        button.toolTip = help
        button.contentTintColor = NSColor.labelColor
        // Pin the button size to 36 PT (= boss 2026-09-23 '按钮文本框的高度，
        // 统一一下，改成 36'). Apple HIG NSButton with bezelStyle=.glass
        // is constrained by its BEZEL'S intrinsicContentSize (= ~28 PT
        // for the glass bezel). Height-only heightAnchor alone is
        // ignored: the button's intrinsic size wins, and SwiftUI sees
        // a ~28-32 PT button.
//
// Apple HIG-correct approach for a fixed-size NSButton in SwiftUI:
//   1. Set translatesAutoresizingMaskIntoConstraints = false
//      (= the button respects constraints; = no autoresizing mask)
//   2. Pin both width AND height with explicit constraints
//      (= SwiftUI no longer falls back to intrinsicContentSize)
//   3. Set content hugging/compression resistance to .required
//      (= SwiftUI prefers the explicit constraints over the bezel
//      intrinsic size).
//
// The width = height (= circle). 36 PT diameter (= matches
// TextField height in ChatInputBarView line 342).
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 36)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 36)
        widthConstraint.priority = .required
        widthConstraint.isActive = true
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        let newImage = NSImage(systemSymbolName: systemName, accessibilityDescription: help)
        if nsView.image !== newImage {
            nsView.image = newImage
        }
        nsView.toolTip = help
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func tap(_ sender: NSButton) {
            action()
        }
    }
}
