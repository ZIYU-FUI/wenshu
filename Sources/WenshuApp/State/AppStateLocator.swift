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

/// chapter-focus-lock 2026-09-28: bridge between the @MainActor
/// AppState (= SwiftUI environment) and background actors that
/// need to read its public state without taking a hard reference.
/// Set once at AppRootScene boot (= SwiftUI App init); = readers
/// use the weak `appState` to consult `focusedChapterPath`.
@MainActor
final class AppStateLocator {
    static let shared = AppStateLocator()
    weak var appState: AppState?
    private init() {}
}