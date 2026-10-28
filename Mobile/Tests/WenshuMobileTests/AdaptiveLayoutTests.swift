import SwiftUI
import Testing
@testable import WenshuMobileApp

@Suite("AdaptiveLayoutTests")
struct AdaptiveLayoutTests {
    @Test func aCompactWidthTakesTheStack() {
        let layout = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: false)

        #expect(layout.shape == .stack)
    }

    @Test func aRegularWidthTakesTheSplit() {
        let layout = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: false)

        #expect(layout.shape == .split)
    }

    @Test func anUnclassifiedWidthTakesTheWiderLayout() {
        let layout = AdaptiveLayout.decide(sizeClass: nil, foldableNativeAvailable: false)

        #expect(layout.shape == .split)
    }

    @Test func theAvailabilityGateDoesNotChangeTheShape() {
        let compactFallback = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: false)
        let compactNative = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: true)
        let regularFallback = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: false)
        let regularNative = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true)

        #expect(compactFallback.shape == compactNative.shape)
        #expect(regularFallback.shape == regularNative.shape)
        #expect(compactNative.shape == .stack)
        #expect(regularNative.shape == .split)
    }

    @Test func aFlatDisplayTakesTheSizeClassLayout() {
        let layout = AdaptiveLayout.decide(
            sizeClass: .regular,
            foldableNativeAvailable: true,
            fold: .flat
        )

        #expect(layout.drawing == .sizeClassLayout)
    }

    @Test func aFoldThatSplitsTheDisplayTakesTheFoldableArrangement() {
        let layout = AdaptiveLayout.decide(
            sizeClass: .regular,
            foldableNativeAvailable: true,
            fold: .folded
        )

        #expect(layout.drawing == .foldableArrangement)
    }

    @Test func aFoldTakesTheSizeClassLayoutWhereTheFoldableAPIIsMissing() {
        let layout = AdaptiveLayout.decide(
            sizeClass: .regular,
            foldableNativeAvailable: false,
            fold: .folded
        )

        #expect(layout.drawing == .sizeClassLayout)
        #expect(layout.shape == .split)
    }

    @Test func aCompactWidthNeverTakesTheFoldableArrangement() {
        let layout = AdaptiveLayout.decide(
            sizeClass: .compact,
            foldableNativeAvailable: true,
            fold: .folded
        )

        #expect(layout.shape == .stack)
        #expect(layout.drawing == .sizeClassLayout)
    }

    @Test func theDecisionFollowsTheWidthAndIsNotLatched() {
        let unfolded = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true)
        let folded = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: true)

        #expect(unfolded.shape == .split)
        #expect(folded.shape == .stack)
    }

    @Test func theFoldIsRecomputedAndNotLatched() {
        let folded = AdaptiveLayout.decide(
            sizeClass: .regular,
            foldableNativeAvailable: true,
            fold: .folded
        )
        let unfolded = AdaptiveLayout.decide(
            sizeClass: .regular,
            foldableNativeAvailable: true,
            fold: .flat
        )

        #expect(folded.drawing == .foldableArrangement)
        #expect(unfolded.drawing == .sizeClassLayout)
    }

    @Test func theDecisionIsTheSameWhicheverWidthWasSeenLast() {
        let regular = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true)
        _ = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: true)
        let regularAgain = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true)

        #expect(regularAgain == regular)
        #expect(regularAgain.shape == .split)
    }

    @Test func theAvailabilityGateFollowsTheSystemThatRunsTheApp() {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            #expect(AdaptiveLayout.foldableNativeAvailable)
        } else {
            #expect(AdaptiveLayout.foldableNativeAvailable == false)
        }
        #else
        #expect(AdaptiveLayout.foldableNativeAvailable == false)
        #endif
    }
}
