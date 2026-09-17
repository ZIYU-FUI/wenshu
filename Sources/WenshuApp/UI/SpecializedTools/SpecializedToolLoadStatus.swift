//
// SpecializedToolLoadStatus.swift · Wenshu · v1.28 B2.6
//
// Shared `LoadStatus` enum for the 8 SpecializedTools tabs (= per
// R1 reuse audit Top 5; = previously each view file re-declared
// `private enum LoadStatus: Equatable, Sendable { case idle / loading
// / loaded / failed(String) }`; = 6 of 8 specialized tool views
// had the same boilerplate enum copied verbatim).
//
// Apple HIG alignment: matches SwiftUI's `Task` lifecycle states
// (= idle = no work yet, loading = Task in flight, loaded = Task
// succeeded, failed = Task threw).
//
// Concurrency: `Equatable, Sendable` (= the SwiftUI body runs on
// MainActor; = the enum crosses actor boundaries when the `Task`
// resume captures it; = Sendable is the Swift 6 strict-concurrency
// contract for that capture).
//
// Single source of truth: future cases (= cancelled, throttled, …)
// touch this one file instead of 8.
//

import Foundation

public enum SpecializedToolLoadStatus: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}
