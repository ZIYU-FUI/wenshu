//
//  ContinuityProvider.swift
//
//  Where a turn's continuity report comes from.
//
//  Why: the agent runtime does not own a book. The app does: = the
//  book lives on disk under the library, = and only the app's layer
//  can read it. So the runtime asks for the report and the app
//  supplies it, = the same seam the memory provider uses (= the
//  runtime holds a provider and reads it per turn, = and the app
//  decides what the provider is).
//
//  The protocol is what keeps the package boundary honest: = the
//  runtime never opens a book, = and the app never writes the prompt.
//  What travels is a value (= a report), = so the boundary holds on
//  the wire and not only in the source.
//

import Foundation

/// The source of a turn's continuity report.
///
/// A provider that has nothing to say returns an empty report, = = so
/// a turn with no book bound carries no report and is not blocked.
public protocol ContinuityProvider: Sendable {
    /// The report for the book the current turn is about.
    ///
    /// The provider is asked once per turn, = = so it may cache what
    /// it reads, = = and it is asked before the prompt is composed, =
    /// = so the report reaches the model with the rest of the turn's
    /// context.
    func continuityReport() async -> ContinuityReport
}

public extension ContinuityProvider {
    /// A provider that never has anything to say.
    ///
    /// The default for a turn with no book bound: = the bundle's two
    /// arrays stay empty, = = which is what they were before this
    /// seam existed.
    static var empty: ContinuityProvider {
        EmptyContinuityProvider()
    }
}

/// The provider that carries nothing.
public struct EmptyContinuityProvider: ContinuityProvider {
    public init() {}

    public func continuityReport() async -> ContinuityReport {
        ContinuityReport()
    }
}
