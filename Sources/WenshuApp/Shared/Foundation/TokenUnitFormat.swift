// TokenUnitFormat.swift
//
// The app's one unit conversion for token counts.
//
// The product rule (see OOB.md #2026-11-26) is that a meter which prints a
// count converts it to a unit, because a six-digit number is too long to
// read off the bar.
//
// Foundation ships the conversion, so nothing here picks a suffix or a
// divisor (= IntegerFormatStyle.CompactNameSymbolNotation, documented at
// https://developer.apple.com/documentation/Foundation/IntegerFormatStyle/
// CompactNameSymbolNotation): the formatter asks the locale which unit a
// number abbreviates to and at what magnitude, so one call answers the
// ten-thousand unit in Chinese and the thousand unit in English. A
// hand-written "/ 1000 + k" would be wrong in one of the two languages.
//
// Measured on this machine's Foundation (Swift 6), which is what the two
// branches below are cut on: at fraction length 0...1, 128000 renders as
// twelve point eight of the locale's unit in Chinese and 128K in English,
// and 3027 stays 3,027 in both. The DEFAULT fraction rounds further, to
// thirteen of the Chinese unit, which is why the fraction length is pinned
// to one decimal: the window's own size has to stay readable.
//
// The exact strings are asserted in TokenUnitFormatTests, where the locale
// output is data the test compares against.
//
// Below the smallest unit either locale has, a count is already short, so
// it prints in full and the reader keeps the exact number. The line is
// 10,000: it is the first unit Chinese has, and the one place a five-digit
// number would otherwise be shortened to one significant digit.

import Foundation

/// Token counts as the reader sees them.
enum TokenUnitFormat {
    /// The count, in unit form.
    ///
    /// - Parameters:
    ///   - count: the number to render.
    ///   - locale: the language to render it in. A view leaves this out so
    ///     the reading follows the app's own locale; a test passes one so
    ///     the assertion means the same thing on every machine.
    static func string(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        if count < unitThreshold {
            return count.formatted(.number.locale(locale))
        }
        return count.formatted(
            .number
                .locale(locale)
                .notation(.compactName)
                .precision(.fractionLength(0 ... 1))
        )
    }

    /// The count in full, as the tooltip and VoiceOver carry it.
    ///
    /// The unit form costs exactness, so the number the reader is being
    /// shown stays one command away.
    static func exactString(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        count.formatted(.number.locale(locale))
    }

    /// The magnitude at which the unit form starts.
    ///
    /// `internal` rather than a literal in both branches, so a reader who
    /// doubts the line finds one place to argue with.
    static let unitThreshold = 10000
}
