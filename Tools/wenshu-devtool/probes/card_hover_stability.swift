//
//  card_hover_stability.swift
//
//  Measure whether the inspector column's card HOVER FLICKERS.
//
//  WHY A PROBE AND NOT THE APP
//    The app's own board page sorts itself live (= the agent's tasks
//    move, = = and the card under the pointer changes), = = so a
//    capture-to-capture diff of the app measures the BOARD, = = not
//    the hover. = = ⇒ The probe draws ONE STATIC card, = = so every
//    pixel that moves between two frames is the hover's doing.
//
//  WHAT IT MEASURES
//    Two cards, side by side, = = the SAME card with the SAME surface:
//
//      LEFT   the tracking area INSIDE the Button's label
//      RIGHT  the tracking area ON the Button (= outside the label)
//
//    and for each one, = = over many frames with the pointer parked
//    on it, = = how many frames differ from their neighbour (= = the
//    hover flickering).
//
//  HOW IT IS READ
//    The probe does NOT capture (= = the app's own capture is the
//    instrument, = = and the probe is only the picture). = = ⇒ The
//    frames are taken by `wincap`, = = which reads the window server's
//    own pixels of this window.
//
//  HOW IT IS RUN
//    swiftc -O Tools/wenshu-devtool/probes/card_hover_stability.swift -o /tmp/cardhover
//    /tmp/cardhover &
//    wincap <window-number> /tmp/f_1.png     (= from the terminal, = = which
//    has the screen-recording grant)
//

import AppKit
import CoreGraphics
import SwiftUI

// MARK: - The card's own parts

private let cardRadius: CGFloat = 8

private struct ContentAreaMaterial: View {
    var body: some View {
        VisualEffectView(material: .underWindowBackground, blending: .withinWindow)
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.material = material
        nsView.blendingMode = blending
        nsView.state = .active
    }
}

/// The card's own surface (= its words, = its material, = its hairline,
/// = and its hover wash).
private struct CardSurface: View {
    let isHovering: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("A card's own words")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { ContentAreaMaterial() }
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius)
                .fill(isHovering
                    ? AnyShapeStyle(.quaternary)
                    : AnyShapeStyle(Color.clear))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardRadius))
    }
}

/// The card with the tracking area INSIDE the label (= the old
/// arrangement).
private struct CardInsideLabel: View {
    @State private var isHovering = false

    var body: some View {
        Button(action: {}) {
            CardSurface(isHovering: isHovering)
                .onHover { hovering in
                    FileHandle.standardError.write(
                        Data("INSIDE-LABEL hover=\(hovering)\n".utf8)
                    )
                    isHovering = hovering
                }
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

/// The card with the tracking area ON the Button (= the new
/// arrangement).
private struct CardOutsideLabel: View {
    @State private var isHovering = false

    var body: some View {
        Button(action: {}) {
            CardSurface(isHovering: isHovering)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { hovering in
            FileHandle.standardError.write(
                Data("ON-BUTTON hover=\(hovering)\n".utf8)
            )
            isHovering = hovering
        }
    }
}

// MARK: - The probe's own run

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 200, y: 200, width: 760, height: 260),
    styleMask: [.titled], backing: .buffered, defer: false
)
window.title = "card hover stability"
window.contentView = NSHostingView(
    rootView: HStack(spacing: 40) {
        CardInsideLabel().frame(width: 320)
        CardOutsideLabel().frame(width: 320)
    }
    .padding(30)
)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

print("PROBE READY (= its window number is the one to capture)")

// The probe stays up until it is killed.
RunLoop.main.run()
