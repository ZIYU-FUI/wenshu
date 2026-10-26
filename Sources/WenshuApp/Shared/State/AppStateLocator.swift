//
//  AppStateLocator.swift
//
//  Tiny locator for the singleton AppState so background actors
//  (= EditChapterActor, BookChapterActor, etc.) can read the
//  focus-lock predicate without coupling to AppState's full
//  surface (= which is @MainActor and would otherwise require
//  every read to await MainActor.run). The locator owns a weak
//  reference (= the AppState lives for the process lifetime, but
//  the weak pattern lets unit tests create + tear down multiple
//  instances without leaking).
//
//  Mirrors the SwiftUI environment-injected AppState (= read
//  sites inside SwiftUI views use @Environment(AppState.self))
//  by providing a MainActor-bounded entry point. Background
//  actors call `currentFocusedChapterPath()` (= awaits MainActor)
//  via ChapterFocusLockGuard.
//

import Foundation
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "appstate.locator")

/// Bridge between the @MainActor AppState (= SwiftUI environment)
/// and background actors that need to read its public state without
/// taking a hard reference. The app binds the state it creates at
/// launch (= see WenshuApp); = readers use the weak `appState` to
/// consult `focusedChapterPath`.
@MainActor
final class AppStateLocator {
    static let shared = AppStateLocator()

    /// The bound app state (= nil before the app binds it).
    private(set) weak var appState: AppState?

    private init() {}

    /// Bind the app state (= called once, where the app creates it).
    ///
    /// The last bind wins: the app owns one app state for its
    /// lifetime, and a test binds its own instance.
    func bind(appState: AppState) {
        self.appState = appState
        wenshuLogger.info("[wenshu.appstate.locator] bound the app state")
    }

    /// Test-only: forget the bound app state (= the state before the
    /// app binds it).
    func unbindForTest() {
        appState = nil
    }
}
