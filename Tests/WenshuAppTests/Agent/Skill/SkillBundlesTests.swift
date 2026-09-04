//
//  SkillBundlesTests.swift · Wenshu · TICKET-HERMES-GAP-006
//
//  Tests for the in-memory SkillBundles resolver + transitive
//  dependency walk. Pins the Swift resolution semantics so future
//  refactors stay observable.
//
//  Hermes Python target: agent/skill_bundles.py (438 LOC). The
//  wenshu port narrows to the in-memory resolver + transitive
//  dependency walk (= YAML disk loading stays on SkillRegistry /
//  SkillAdapter per wenshu-side wins). Hermes' slug normalization,
//  build_bundle_invocation_message, file-level CRUD, and the scan
//  caching are intentionally NOT ported in this ticket (see
//  SkillBundles.swift header for rationale).
//
//  Test surface:
//    1. testRegisterAndResolve: register 1 bundle, resolve returns
//       its skillIDs (= direct lookup).
//    2. testResolveWithTransitiveDependencies: bundle A depends on B,
//       which depends on C; resolve(A) returns skillIDs from all 3.
//    3. testResolveMissingBundleThrows: resolve(unknown) throws
//       SkillBundlesError.bundleNotFound.
//    4. testDependenciesReturnsTransitiveBundleIDs: dependencies(A)
//       returns [A, B, C] in BFS order; tolerate cycles without
//       infinite loop (= self-reference = no-op).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("SkillBundles (TICKET-HERMES-GAP-006)")
struct SkillBundlesTests {

    // MARK: - Test 1: register + direct resolve

    @Test("register a bundle; resolve returns its direct skillIDs")
    func testRegisterAndResolve() async throws {
        let bundles = SkillBundles()
        let backend = SkillBundle(
            id: "backend-dev",
            name: "Backend Dev",
            skillIDs: ["github-code-review", "test-driven-development"]
        )
        await bundles.register(backend)

        let resolved = try await bundles.resolve(bundleID: "backend-dev")
        // Order preserved: registration order is preserved (= direct
        // list, no dependency walk needed).
        #expect(resolved == ["github-code-review", "test-driven-development"])

        let current = await bundles.current
        #expect(current.count == 1)
        #expect(current.first?.id == "backend-dev")

        // unregister + resolve → not-found.
        await bundles.unregister(id: "backend-dev")
        await #expect(throws: SkillBundlesError.self) {
            _ = try await bundles.resolve(bundleID: "backend-dev")
        }
    }

    // MARK: - Test 2: transitive dependency resolve

    @Test("resolve walks transitive dependencies; dedupes skillIDs")
    func testResolveWithTransitiveDependencies() async throws {
        let bundles = SkillBundles()
        // A depends on B; B depends on C.
        await bundles.register(SkillBundle(
            id: "A",
            name: "A",
            skillIDs: ["alpha", "beta"],
            dependencies: ["B"]
        ))
        await bundles.register(SkillBundle(
            id: "B",
            name: "B",
            skillIDs: ["beta", "gamma"],     // "beta" shared with A
            dependencies: ["C"]
        ))
        await bundles.register(SkillBundle(
            id: "C",
            name: "C",
            skillIDs: ["delta"]
        ))

        let resolved = try await bundles.resolve(bundleID: "A")
        // Expected: every skill ID reachable from A, deduplicated,
        // first-seen-wins (= "alpha" + "beta" before "gamma" + "delta").
        #expect(Set(resolved) == Set(["alpha", "beta", "gamma", "delta"]))
        #expect(resolved.count == 4, "duplicates must be deduped")

        // First-seen order: alpha, beta come from A's direct list.
        #expect(resolved.first == "alpha")
    }

    // MARK: - Test 3: missing bundle → throws

    @Test("resolve on missing bundle throws SkillBundlesError.bundleNotFound")
    func testResolveMissingBundleThrows() async throws {
        let bundles = SkillBundles()
        await bundles.register(SkillBundle(id: "exists", name: "exists", skillIDs: ["x"]))

        await #expect(throws: SkillBundlesError.self) {
            _ = try await bundles.resolve(bundleID: "missing")
        }

        // Error description is human-readable.
        do {
            _ = try await bundles.resolve(bundleID: "missing")
            Issue.record("expected throw")
        } catch let SkillBundlesError.bundleNotFound(id) {
            #expect(id == "missing")
        } catch {
            Issue.record("expected SkillBundlesError.bundleNotFound, got \(error)")
        }
    }

    // MARK: - Test 4: dependencies + cycle tolerance

    @Test("dependencies returns transitive bundle ids in BFS order; cycles terminate")
    func testDependenciesReturnsTransitiveBundleIDs() async throws {
        let bundles = SkillBundles()
        await bundles.register(SkillBundle(id: "A", name: "A", skillIDs: ["a"], dependencies: ["B", "C"]))
        await bundles.register(SkillBundle(id: "B", name: "B", skillIDs: ["b"], dependencies: ["C"]))
        await bundles.register(SkillBundle(id: "C", name: "C", skillIDs: ["c"]))
        // Cycle: D → E → D. Should terminate (= visited set short-circuits).
        await bundles.register(SkillBundle(id: "D", name: "D", skillIDs: ["d"], dependencies: ["E"]))
        await bundles.register(SkillBundle(id: "E", name: "E", skillIDs: ["e"], dependencies: ["D"]))

        let depsA = try await bundles.dependencies(bundleID: "A")
        // BFS: A first, then B + C.
        #expect(depsA.first == "A")
        #expect(Set(depsA) == Set(["A", "B", "C"]))
        #expect(depsA.count == 3)

        let depsD = try await bundles.dependencies(bundleID: "D")
        // Cycle terminates; D + E (each appears once).
        #expect(Set(depsD) == Set(["D", "E"]))
        #expect(depsD.count == 2)

        // unregisterAll clears; resolve throws.
        await bundles.unregisterAll()
        await #expect(throws: SkillBundlesError.self) {
            _ = try await bundles.resolve(bundleID: "A")
        }
    }
}
