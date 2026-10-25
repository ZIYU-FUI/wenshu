//
//  ReferenceLibraryLocator.swift
//
//  The bridge between the app's reference library and the agent's
//  reference-library tool.
//
//  Why: the tool registry needs an instance of every tool at
//  registration time, but the user's library only exists once the
//  launch sequence has built it (= LibraryLifecycleHook). The tool
//  therefore ran against a throwaway /tmp root, and every document
//  the agent wrote landed there: invisible in the user's library,
//  gone with the next launch, and (= the point of the card) no
//  constraint for the writing that follows.
//
//  The locator is the same shape as AppStateLocator: the app binds
//  the store once at launch, and the tool reads it when it runs.
//

import Foundation
import os

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "referencelibrary.locator")

@MainActor
final class ReferenceLibraryLocator {
    static let shared = ReferenceLibraryLocator()

    /// The user's reference store (= nil before the launch sequence
    /// has run).
    private(set) var referenceStore: (any ReferenceStoring)?

    /// The root the user's reference library lives in (= nil before
    /// the launch sequence has run).
    private(set) var referenceLibraryRoot: URL?

    private init() {}

    /// Bind the user's library (= called by the launch sequence).
    ///
    /// The last bind wins (= the user can switch libraries; = the
    /// agent writes into the library that is open now).
    func bind(referenceStore: any ReferenceStoring, referenceLibraryRoot: URL) {
        self.referenceStore = referenceStore
        self.referenceLibraryRoot = referenceLibraryRoot
        wenshuLogger.info(
            "[wenshu.reference.locator] bound the reference library: \(referenceLibraryRoot.path)"
        )
    }

    /// Test-only: forget the bound library (= the state before the
    /// launch sequence runs).
    func unbindForTest() {
        referenceStore = nil
        referenceLibraryRoot = nil
    }
}
