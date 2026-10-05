// ROBUSTNESS-2 — BookChapterActor update() boundary tests.
//
// Two contracts:
//   2a — huge body (1 MB) round-trips through the actor + on-disk store
//        without truncation, encoding loss, or memory blowup.
//   2b — concurrent update() calls on the same chapter converge to a
//        single last-write-wins state (no torn writes, no exceptions).
//
// Background: BookChapterActor serializes writes through replaceChapter; = the
// contract holds because every update acquires the actor's isolation. This
// test pins that contract against regressions (= e.g. someone switches to a
// concurrent file write or skips the await).
//
// Reference: AGENTS.md §11.20 (chat-diff-preview), §11.21 (edit-chapter).
//
//  ActiveLibrary.overrideForTesting is a `@TaskLocal` (= Apple
//  HIG canonical pattern for test seams). Tests wrap their body
//  in `ActiveLibrary.$overrideForTesting.withValue(...) { ... }`
//  via the `withLibraryRoot` helper (= per-task scope; = no
//  cross-suite pollution; = no init() reset needed).

import Foundation
import Testing
@testable import WenshuApp

@MainActor
@Suite(.serialized)
struct BookChapterActorUpdateBoundaryTests {

    /// Canonical library root for these tests (= /tmp, resolved
    /// through /private/tmp symlink so PathGuard's canonical-root
    /// comparison matches).
    private static let libraryRoot = URL(fileURLWithPath: "/tmp").resolvingSymlinksInPath().path

    /// Run `body` with `ActiveLibrary.overrideForTesting` bound to
    /// the canonical /tmp library root (= Apple HIG canonical
    /// TaskLocal pattern; = no cross-suite pollution).
    private func withLibraryRoot<R>(_ body: () async throws -> R) async rethrows -> R {
        try await ActiveLibrary.$overrideForTesting.withValue(Self.libraryRoot, operation: body)
    }

    @Test func update_oneMegabyteBodyRoundTripsIntact() async throws {
        try await withLibraryRoot {
            let actor = try Self.makeActor()
            let bookId = UUID()

            // 1 MB body composed of repeating Lorem text. We avoid the very
            // last character being newline so we can distinguish truncation
            // from legitimate write.
            let oneMBBody = Self.makeLargeBody(bytes: 1 << 20, seed: "MegaChapterBodySeed")
            let chapter = try await actor.createChapter(
                bookId: bookId,
                title: "Huge Chapter",
                bodyMarkdown: "placeholder",
                summary: "Robustness T2.1"
            )

            // Update with the 1 MB body.
            _ = try await actor.updateChapter(
                id: chapter.id,
                title: "Huge Chapter",
                bodyMarkdown: oneMBBody,
                summary: "Robustness T2.1"
            )

            // Verify on-disk readback matches what we wrote — byte-for-byte.
            let readBackOpt = await actor.readBodyForTest(id: chapter.id)
            guard let readBack = readBackOpt else {
                Issue.record("1 MB body must round-trip — readback was nil")
                return
            }
            #expect(readBack == oneMBBody,
                    "1 MB body must round-trip without truncation or encoding loss")
            #expect(readBack.utf8.count == (1 << 20),
                    "byte count must equal 1 MB exactly")
            #expect(readBack.first == "M",
                    "first character must match seed prefix (= no head truncation)")
        }
    }

    @Test func update_concurrentCallsOnSameChapterConverge() async throws {
        // ROBUSTNESS-2.2 — Two concurrent update() calls on the same chapter.
        // The actor must serialize them (= per BookChapterActor's actor
        // isolation) so the on-disk file ends in one of the two bodies, not
        // a torn interleaving. We assert that one of the two writes wins
        // and the readback matches the winner exactly.
        try await withLibraryRoot {
            let actor = try Self.makeActor()
            let bookId = UUID()
            let chapter = try await actor.createChapter(
                bookId: bookId,
                title: "Concurrent Chapter",
                bodyMarkdown: "initial",
                summary: "Robustness T2.2"
            )

            let payloadA = String(repeating: "A", count: 4096)
            let payloadB = String(repeating: "B", count: 4096)

            // Race two updates.
            async let updateA: ChapterDescriptor = actor.updateChapter(
                id: chapter.id,
                title: "Concurrent A",
                bodyMarkdown: payloadA,
                summary: "A"
            )
            async let updateB: ChapterDescriptor = actor.updateChapter(
                id: chapter.id,
                title: "Concurrent B",
                bodyMarkdown: payloadB,
                summary: "B"
            )
            _ = try await (updateA, updateB)

            // Either A won or B won. The readback must match one of them
            // exactly (= never a partial interleave).
            let readBack = await actor.readBodyForTest(id: chapter.id)
            let allA = String(repeating: "A", count: 4096)
            let allB = String(repeating: "B", count: 4096)
            #expect(readBack == allA || readBack == allB,
                    "concurrent updates must converge to last-write-wins; got mixed content")
        }
    }

    // MARK: - Helpers

    private static func makeActor() throws -> BookChapterActor {
        let dir = try makeBookDirectory()
        return BookChapterActor(
            bookDirectoryProvider: { dir },
            currentChatBookIDProvider: { nil }
        )
    }

    private static func makeBookDirectory() throws -> URL {
        // Mimic the v2.0 PathGuard test fixture: an isolated /tmp subdir.
        let dir = URL(fileURLWithPath: "/tmp/wenshu-robustness-bk")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Build a deterministic body of approximately `bytes` bytes using the
    /// seed string. The result is prefix + padding + suffix so truncation
    /// would surface as either a different prefix or a missing suffix.
    private static func makeLargeBody(bytes: Int, seed: String) -> String {
        let prefix = seed.prefix(32)
        let suffix = "::END::"
        let targetInner = bytes - prefix.count - suffix.count
        let padding = String(repeating: "x", count: max(0, targetInner))
        return String(prefix) + padding + suffix
    }
}
