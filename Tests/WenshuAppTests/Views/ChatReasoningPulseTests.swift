//
//  ChatReasoningPulseTests.swift · Wenshu · T17-REASONING-PULSE (2026-09-18)
//
//  Verifies that ChatReasoningPartView applies an opacity pulse
//  animation to the brain icon when isRunning = true. Strategy:
//  inspect the view's body for the `.animation(...)` modifier
//  chain (= a smoke test that the right modifiers are present;
//  visual verification requires ImageRenderer which can't render
//  @State bindings headless).
//

import Testing
import Foundation
import SwiftUI
@testable import WenshuApp

@Suite("ChatReasoningPartView pulse animation (T17)")
struct ChatReasoningPulseTests {

    /// T17 contract: ChatReasoningPartView.body has an opacity modifier
    /// gated on isRunning. (= We can't introspect @State directly;
    /// instead we verify the source contains the expected modifiers.)
    @Test func source_contains_running_gated_opacity() throws {
        // Locate the source file via Package.swift layout
        // (= just hard-code the relative path; = tests run from
        // the package root).
        let sourcePath = "Sources/WenshuApp/Views/Chat/ChatPartView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // The opacity should be `isRunning ? runningOpacity : 1.0`.
        #expect(source.contains("opacity(isRunning ? runningOpacity"))
        // The animation should be conditionally applied.
        #expect(source.contains(".animation("))
        #expect(source.contains("repeatForever(autoreverses: true)"))
    }

    /// T17 contract: the pulse only fires when isRunning is true.
    /// (= the .animation(...) modifier is wrapped in an isRunning ternary).
    @Test func pulse_animation_only_when_running() throws {
        let sourcePath = "Sources/WenshuApp/Views/Chat/ChatPartView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        // The .animation(...) block should be conditional on isRunning.
        #expect(source.contains("isRunning"))
        #expect(source.contains("repeatForever(autoreverses: true)"))
        // Verify the conditional form: .animation(isRunning ? ... : .default, ...)
        let animationTernaryPattern = "isRunning\n                            ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)\n                            : .default"
        #expect(source.contains(animationTernaryPattern))
    }

    /// T17 contract: runningOpacity = 0.6 (= midway between visible
    /// and faint = subtle pulse without disappearing).
    @Test func running_opacity_value() throws {
        let sourcePath = "Sources/WenshuApp/Views/Chat/ChatPartView.swift"
        let source = try String(contentsOfFile: sourcePath, encoding: .utf8)
        #expect(source.contains("return 0.6"))
    }
}