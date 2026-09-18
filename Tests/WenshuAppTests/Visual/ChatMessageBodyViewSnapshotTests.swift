//
//  ChatMessageBodyViewSnapshotTests.swift · Wenshu · T1-THINKING-VISIBLE (2026-09-18)
//
//  Strategy C: visual snapshot tests using @testable import WenshuApp
//  + SwiftUI ImageRenderer. Exercises the real wenshu types
//  (= no drift risk; = same source as production).
//
//  Each test renders a ChatMessageBodyView with a different parts[]
//  composition and writes a PNG to .scratch/2026-09-18-agent-fullchain/snapshots/.
//

import Testing
import Foundation
import SwiftUI
import AppKit
@testable import WenshuApp

@Suite("ChatMessageBodyView visual snapshots (T1-THINKING-VISIBLE)")
struct ChatMessageBodyViewSnapshotTests {

    let outputDir = "/Volumes/ANAN/Engineering/wenshu/.scratch/2026-09-18-agent-fullchain/snapshots"

    @MainActor
    private func render<V: View>(_ view: V, named name: String) {
        try? FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )
        let renderer = ImageRenderer(content: view.frame(width: 500, height: 320))
        renderer.scale = 2.0
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("[snapshot] FAILED to render \(name)")
            return
        }
        let path = "\(outputDir)/\(name).png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("[snapshot] wrote \(path) (\(png.count) bytes)")
    }

    /// Snapshot 1: ChatMessageBodyView with a .reasoning part + .text part.
    /// Expected:
    ///   • ChatReasoningPartView renders a DisclosureGroup with "Thinking: ..." label
    ///   • ChatTextPartView renders the .text content
    @Test @MainActor
    func snapshot_with_reasoning_part() {
        let msg = ChatMessage(
            role: .agent,
            content: "Final answer text.",
            tokens: 42,
            thinking: "Internal thinking that should be hidden by new view.",
            parts: [
                ChatMessagePart(id: UUID(), kind: .reasoning("Internal thinking..."), timestamp: nil, completedAt: nil),
                ChatMessagePart(id: UUID(), kind: .text("Final answer text."), timestamp: nil, completedAt: nil),
            ],
            streamState: .sealed
        )
        let view = ChatMessageBodyView(message: msg, isOutgoing: false, isStreaming: false)
        render(view, named: "01-with-reasoning-part")
    }

    /// Snapshot 2: legacy fallback = empty parts + legacy thinking string.
    /// Expected:
    ///   • ChatTextPartView renders message.content as the single text
    ///   • Legacy DisclosureGroup still renders (= back-compat path)
    @Test @MainActor
    func snapshot_legacy_empty_parts_with_thinking() {
        let msg = ChatMessage(
            role: .agent,
            content: "Legacy back-compat text.",
            tokens: 30,
            thinking: "Legacy thinking (this IS visible - old format)",
            parts: [],
            streamState: .sealed
        )
        let view = ChatMessageBodyView(message: msg, isOutgoing: false, isStreaming: false)
        render(view, named: "02-legacy-empty-parts-with-thinking")
    }

    /// Snapshot 3: ChatMessageView wrapper (= the parent that owns the
    /// T1 hide logic). With reasoning part → legacy DisclosureGroup
    /// must NOT render.
    @Test @MainActor
    func snapshot_messageview_with_reasoning_no_legacy_dup() {
        let msg = ChatMessage(
            role: .agent,
            content: "Final answer.",
            tokens: 42,
            thinking: "Thinking that goes through BOTH new + legacy path.",
            parts: [
                ChatMessagePart(id: UUID(), kind: .reasoning("Thinking via new part..."), timestamp: nil, completedAt: nil),
                ChatMessagePart(id: UUID(), kind: .text("Final answer."), timestamp: nil, completedAt: nil),
            ],
            streamState: .sealed
        )
        let view = ChatMessageView(message: msg)
            .frame(width: 500, height: 320)
        render(view, named: "03-messageview-with-reasoning-no-legacy-dup")
    }
}