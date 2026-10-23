//
//  ContextOverrides.swift · Wenshu
//
//  The context numbers the user picked, installed by the app.
//
//  Three numbers live in the settings screen and change nothing: the
//  compression threshold, the keep fraction, and the memory cap. This
//  holder is the input for all three.
//
//  Why a holder and not a parameter: the compressor is constructed as a
//  default value wherever the conversation loop is built, and the memory
//  provider is a singleton, so a parameter would have to reach every
//  construction site. A holder reaches one.
//
//  The shape follows the package's own precedent
//  (`ProviderEndpointOverrides`): a plain enum, one nonisolated(unsafe)
//  static var replaced wholesale so a reader always sees a consistent
//  snapshot, and typed accessors that decide what to do with a stored value
//  that cannot be used. The package owns no storage and never reads
//  `UserDefaults`; the app installs the values.
//

import Foundation

/// The context numbers the user chose, installed by the app.
///
/// Absent or out of range (= the built-in default applies). Never read
/// `UserDefaults` from here (= the app installs the values).
public enum ContextOverrides {

    /// One snapshot of the user's numbers.
    ///
    /// Replaced wholesale rather than mutated in place, so a reader that
    /// asks for two of them never sees one from before an install and one
    /// from after it.
    public struct Values: Sendable, Equatable {
        /// Fraction of the context window at which compression starts.
        public var compressionThreshold: Double
        /// Fraction of the transcript that survives the compression.
        public var keepFraction: Double
        /// How many memories one recall may return.
        public var memoryCap: Int

        public init(
            compressionThreshold: Double = 0.85,
            keepFraction: Double = 0.3,
            memoryCap: Int = 5
        ) {
            self.compressionThreshold = compressionThreshold
            self.keepFraction = keepFraction
            self.memoryCap = memoryCap
        }
    }

    /// The user's numbers, replaced wholesale by the app.
    public nonisolated(unsafe) static var values = Values()

    /// Install the user's numbers.
    ///
    /// The whole snapshot is replaced, so a reader always sees one
    /// consistent set (= the endpoint-override precedent).
    public static func install(_ values: Values) {
        self.values = values
    }

    /// Install the user's numbers from their three parts.
    public static func install(
        compressionThreshold: Double,
        keepFraction: Double,
        memoryCap: Int
    ) {
        install(Values(
            compressionThreshold: compressionThreshold,
            keepFraction: keepFraction,
            memoryCap: memoryCap
        ))
    }

    // MARK: - Typed accessors

    /// The threshold the compressor compares usage against.
    ///
    /// A fraction of the context window on both sides (= compress once the
    /// transcript fills that share of the window). Accepted range is
    /// `(0, 1]`: a share of a window is above zero and at most the whole
    /// window, so anything else falls back to the built-in default rather
    /// than reaching the compressor.
    public static var compressionThreshold: Double {
        let stored = values.compressionThreshold
        guard stored > 0, stored <= 1 else { return Values().compressionThreshold }
        return stored
    }

    /// The share of the transcript that survives the compression.
    ///
    /// A fraction of the transcript (= the tail's share of the tokens the
    /// compressor was handed), not a fraction of the window: the window
    /// decides WHEN to compress, this decides HOW MUCH is kept. Accepted
    /// range is `(0, 1]`, the same shape as the threshold.
    public static var keepFraction: Double {
        let stored = values.keepFraction
        guard stored > 0, stored <= 1 else { return Values().keepFraction }
        return stored
    }

    /// How many memories one recall may return.
    ///
    /// Zero is not a cap: a recall that returns nothing leaves the agent
    /// with no memory of the user at all, and the memory subsystem's own
    /// switch is the way to turn recall off. A cap below one is therefore
    /// rejected and the built-in default applies (= a bounded recall,
    /// never an unbounded one).
    public static var memoryCap: Int {
        let stored = values.memoryCap
        guard stored >= 1 else { return Values().memoryCap }
        return stored
    }
}
