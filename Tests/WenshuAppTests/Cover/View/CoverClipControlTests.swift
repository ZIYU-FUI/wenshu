//
//  CoverClipControlTests.swift · Wenshu
//
//  Proves what the cover's play control says and does.
//
//  The control is the App Store's shape (= a filled circle with a
//  triangle in it), and it is the system's own symbol: `play.circle
//  .fill` and `pause.circle.fill`. The rule is a small PURE type, so
//  the truth table can be checked without a player and without a
//  video file.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover clip control")
struct CoverClipControlTests {

    @Test("A clip that is not running shows the play symbol")
    func anIdleClipShowsPlay() {
        #expect(CoverClipControl.symbol(isPlaying: false) == "play.circle.fill")
    }

    @Test("A running clip shows the pause symbol")
    func aRunningClipShowsPause() {
        #expect(CoverClipControl.symbol(isPlaying: true) == "pause.circle.fill")
    }

    @Test("The control starts a clip that is not running")
    func anIdleClipIsStarted() {
        #expect(CoverClipControl.action(isPlaying: false) == .start)
    }

    @Test("The control stops a running clip")
    func aRunningClipIsStopped() {
        #expect(CoverClipControl.action(isPlaying: true) == .stop)
    }

    @Test("The control is read out with its own words")
    func theControlHasItsOwnWords() {
        #expect(CoverClipControl.label(isPlaying: false) == "cover.play_clip")
        #expect(CoverClipControl.label(isPlaying: true) == "cover.pause_clip")
    }

    @Test("The control is big enough to press")
    func theControlCanBePressed() {
        // Apple's smallest hit target is 28 PT, and the cover slot is
        // 100 PT tall, so the control can be pressed without aiming
        // and still leaves the picture readable.
        #expect(CoverClipControl.controlSize >= 28)
        #expect(CoverClipControl.controlSize <= 34)
    }
}
