//
//  CoverMotifSupport.swift · Wenshu
//
//  The stub the cover tests draw with.
//
//  The generation service now REDUCES a document to its motifs before
//  it draws anything, and that reduction is a text call. Without a
//  stub, every cover test would reach the network, and the suite's
//  outcome would be a property of the network instead of a property
//  of the code.
//
//  The stub returns the same motifs for every document, so a test can
//  assert on the prompt the image model receives.
//

import Foundation
@testable import WenshuApp

/// A motif extractor that answers on purpose.
///
/// A class, not a struct, because the protocol's method is not
/// mutating and the counter still has to move.
final class StubMotifExtractor: CoverMotifExtracting, @unchecked Sendable {

    /// The motifs it hands back.
    var motifs: CoverMotifs

    /// The counter's lock.
    private let lock = NSLock()

    /// How many times it was asked.
    private var _callCount = 0

    var callCount: Int { lock.withLock { _callCount } }

    init(motifs: CoverMotifs = StubMotifExtractor.defaultMotifs) {
        self.motifs = motifs
    }

    /// The motifs the stub hands back by default.
    static let defaultMotifs = CoverMotifs(
        register: "中式",
        style: "宋韵插画",
        brush: "东方水墨笔触",
        motifs: ["礁灯", "浪花", "海鸥"],
        arrangement: "礁灯居中，浪花在两侧，海鸥在上",
        palette: ["靛蓝", "灰白"],
        mood: ["清冷"]
    )

    func extract(title: String, summary: String) async throws -> CoverMotifs {
        lock.withLock { _callCount += 1 }
        return motifs
    }
}
