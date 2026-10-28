import SwiftUI
import Testing
@testable import WenshuMobileApp

@Suite("ClientShellTests")
struct ClientShellTests {
    @Test func aCompactWidthTakesTheTabBar() {
        let layout = AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: false)

        #expect(ClientShellLayout.layout(for: layout) == .tabBar)
    }

    @Test func aRegularWidthTakesTheSplitView() {
        let layout = AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: false)

        #expect(ClientShellLayout.layout(for: layout) == .splitView)
    }

    @Test func anUnclassifiedWidthTakesTheSplitView() {
        let layout = AdaptiveLayout.decide(sizeClass: nil, foldableNativeAvailable: false)

        #expect(ClientShellLayout.layout(for: layout) == .splitView)
    }

    @Test func theAvailabilityGateDoesNotChangeTheShell() {
        let compactFallback = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: false)
        )
        let compactNative = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .compact, foldableNativeAvailable: true)
        )
        let regularFallback = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: false)
        )
        let regularNative = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true)
        )

        #expect(compactFallback == compactNative)
        #expect(regularFallback == regularNative)
        #expect(compactNative == .tabBar)
        #expect(regularNative == .splitView)
    }

    @Test func aFoldDoesNotChangeTheShell() {
        let folded = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true, fold: .folded)
        )
        let flat = ClientShellLayout.layout(
            for: AdaptiveLayout.decide(sizeClass: .regular, foldableNativeAvailable: true, fold: .flat)
        )

        #expect(folded == flat)
        #expect(folded == .splitView)
    }

    @Test func theShellOffersTheLibraryAndTheConnection() {
        #expect(ClientDestination.allCases == [.library, .connect])
        #expect(ClientDestination.library.title == "Library")
        #expect(ClientDestination.connect.title == "Connect")
    }

    @Test func eachDestinationCarriesItsOwnSymbol() {
        #expect(ClientDestination.library.symbol == .library)
        #expect(ClientDestination.connect.symbol == .link)
        #expect(ClientDestination.library.symbol != ClientDestination.connect.symbol)
    }
}
