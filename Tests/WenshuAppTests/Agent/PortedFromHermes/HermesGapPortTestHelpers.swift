//
// HermesGapPortTestHelpers.swift · Wenshu · v1.57 stale-helper
//
// Shared helper for the HermesGapPortTests suite family (= ~20 test files
// under Tests/WenshuAppTests/Agent/PortedFromHermes/).
//
// Why this exists:
//   The v0.35-era test files used `#file` (= the relative path from
//   the wenshu root) and substituted the test file name with the source
//   file name, expecting the path to resolve to Sources/WenshuApp/...
//   That worked in the original worktree where the test was authored,
//   but `swift test` runs the tests from the swiftpm build dir's
//   flattened copy of the source tree (= #file resolves to a path under
//   .build/...), and the relative-path arithmetic no longer lines up.
//
//   The fix is to walk UP from #filePath (= the test file's absolute
//   path on disk during testing) until we find a directory containing
//   "Sources/WenshuApp/<...>", then build the source path by replacing
//   "Tests/WenshuAppTests/Agent/PortedFromHermes/" with "Sources/WenshuApp/"
//   and the test filename with the source filename.
//
//   Per `wenshu-stale-test-cleanup` skill Class A recipe:
//
//     Tests/WenshuAppTests/<X>/<Y>/<File>_test.swift  → depth 4
//     Tests/WenshuAppTests/<File>_test.swift          → depth 3
//
//   For HermesGapPortTests files the canonical depth = 5:
//     Tests/WenshuAppTests/Agent/PortedFromHermes/<File>Tests.swift
//
//   = filename + PortedFromHermes + Agent + WenshuAppTests + Tests.
//
// Usage (per test):
//
//     func testSourceFile_documentedAsHermesPort() {
//         let source = HermesGapPortTestHelpers.readSource(
//             relativeToTest: #filePath,
//             sourceFileName: "AgentInit.swift"
//         )
//         XCTAssertNotNil(source, "Could not locate AgentInit.swift via helper")
//         guard let source else { return }
//         XCTAssertTrue(source.contains("P9-AGENT-INIT-HERMES-PORT"))
//         ...
//     }
//
// Q112: 1 file 1 commit. Per Q99 dual-axis: fixes pre-existing
// combined-run variance (= 22 fails in v1.55 acceptance verify were
// all Class A "Could not read X.swift" pattern). Acceptance = the
// 13 Class A failing tests now resolve the source file and assert
// the doc-comment markers.

import Foundation

/// Shared helper for HermesGapPortTests (= ~20 test files under
/// Tests/WenshuAppTests/Agent/PortedFromHermes/).
///
/// Centralizes the source-file lookup that the original per-file
/// `testSourceFile_documentedAsHermesPort` tests tried to do with
/// `#file` + string substitution. The substitution pattern was
/// correct when the test was authored in the same worktree as the
/// source (= v0.35 era), but `swift test` flattens the source tree
/// into the build dir, breaking the relative path arithmetic.
///
/// The helper walks up from the test file's absolute path until it
/// finds a directory that contains both `Tests/` and `Sources/`,
/// then resolves the source path by replacing the test subdirectory
/// with the source subdirectory.
public enum HermesGapPortTestHelpers {

    /// Read the source file that a given HermesGapPortTests file asserts against.
    ///
    /// - Parameters:
    ///   - relativeToTest: pass `#filePath` from the calling test.
    ///   - sourceFileName: leaf filename of the source file
    ///     (= e.g. "AgentInit.swift" not the full path).
    /// - Returns: the source file contents, or nil if the wenshu
    ///   repo root could not be located (= the test should XCTFail
    ///   with "Could not locate <sourceFileName> via helper").
    public static func readSource(
        relativeToTest testPath: String,
        sourceFileName: String
    ) -> String? {
        let wenshuRoot = locateWenshuRoot(startingAt: testPath)
        guard let wenshuRoot else { return nil }

        // Canonical mapping: Tests/WenshuAppTests/Agent/PortedFromHermes/<Name>.swift
        //               →   Sources/WenshuApp/Core/Agent/<...>/<Name>.swift
        //
        // For HermesGapPortTests we know the test file lives at
        //   Tests/WenshuAppTests/Agent/PortedFromHermes/<X>HermesGapPortTests.swift
        // and the source file lives at
        //   Sources/WenshuApp/Core/Agent/<...>/<X>.swift
        //
        // The shared prefix between them is "Agent/" — we substitute
        //   "Tests/WenshuAppTests/Agent/PortedFromHermes/"
        // with
        //   "Sources/WenshuApp/Core/Agent/"
        // and substitute the test filename with the source filename.
        //
        // For modules not under Core/Agent (= CredentialSources.swift
        // lives under Core/Provider/), we use a fallback that searches
        // the entire Sources/WenshuApp/ tree for a file with the given
        // name (= no namespace ambiguity since each module name is
        // unique within the tree).

        // Fast path 1: known canonical mapping for Agent subtree.
        let agentSourcePath = wenshuRoot
            + "/Sources/WenshuApp/Core/Agent/"
            + sourceFileName
        if let contents = try? String(contentsOfFile: agentSourcePath, encoding: .utf8) {
            return contents
        }

        // Fast path 2: known canonical mapping for Provider subtree.
        let providerSourcePath = wenshuRoot
            + "/Sources/WenshuApp/Core/Provider/"
            + sourceFileName
        if let contents = try? String(contentsOfFile: providerSourcePath, encoding: .utf8) {
            return contents
        }

        // Fast path 3: known canonical mapping for Connector subtree.
        let connectorSourcePath = wenshuRoot
            + "/Sources/WenshuApp/Core/Agent/Connector/"
            + sourceFileName
        if let contents = try? String(contentsOfFile: connectorSourcePath, encoding: .utf8) {
            return contents
        }

        // Fast path 4: known canonical mapping for Tool subtree.
        let toolSourcePath = wenshuRoot
            + "/Sources/WenshuApp/Core/Agent/Tool/"
            + sourceFileName
        if let contents = try? String(contentsOfFile: toolSourcePath, encoding: .utf8) {
            return contents
        }

        // Fast path 5: known canonical mapping for Skills subtree.
        let skillsSourcePath = wenshuRoot
            + "/Sources/WenshuApp/Core/Skills/"
            + sourceFileName
        if let contents = try? String(contentsOfFile: skillsSourcePath, encoding: .utf8) {
            return contents
        }

        // Fallback: walk the Sources tree for the filename.
        return locateByFilename(in: wenshuRoot + "/Sources/WenshuApp", filename: sourceFileName)
    }

    /// Walk up from the test file's absolute path until we find a directory
    /// containing both `Tests/` and `Sources/` (= the wenshu repo root).
    private static func locateWenshuRoot(startingAt path: String) -> String? {
        var url = URL(fileURLWithPath: path)
        // Cap the walk at 8 levels to prevent runaway loops on weird inputs.
        for _ in 0..<8 {
            let testsMarker = url.appendingPathComponent("Tests").path
            let sourcesMarker = url.appendingPathComponent("Sources").path
            if FileManager.default.fileExists(atPath: testsMarker) &&
               FileManager.default.fileExists(atPath: sourcesMarker) {
                return url.path
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { return nil }
            url = parent
        }
        return nil
    }

    /// Search the Sources/WenshuApp/ subtree for a file with the given leaf
    /// filename (= used for source files not in the canonical Agent/Provider/
    /// Connector/Tool/Skills subtrees). Returns the contents of the first match.
    private static func locateByFilename(in dir: String, filename: String) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dir) else { return nil }
        for case let entry as String in enumerator {
            if entry.hasSuffix("/" + filename) || entry == filename {
                let fullPath = dir + "/" + entry
                if let contents = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    return contents
                }
            }
        }
        return nil
    }
}