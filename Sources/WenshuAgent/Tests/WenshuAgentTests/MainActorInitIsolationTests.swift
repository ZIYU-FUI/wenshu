//
//  MainActorInitIsolationTests.swift · WenshuAgent
//
//  The three singletons that read a @MainActor value now declare that
//  isolation on their initializer, so the compiler refuses an
//  off-MainActor construction.
//
//  MainActor.assumeIsolated was a runtime assertion, not a check: off the
//  MainActor it traps (= SIGTRAP), so a caller cannot catch it. Two proofs
//  replace it, and each is checked where it can be seen:
//
//    1. the compiler refuses a caller that constructs the type away from
//       the MainActor (= the trap is unreachable, not merely unlikely).
//       Before the fix that caller compiled, and the trap fired at runtime.
//    2. a caller away from the MainActor gets a value (= the initializer
//       hops to the MainActor, where its dependency is valid).
//       Before the fix that caller trapped and killed the process.
//
//  Proof 1 fails the compile and proof 2 fails the process, so neither is an
//  assertion this suite can catch. The suite checks the compiler's exit
//  status and the process's survival.
//

import Foundation
import Testing
@testable import WenshuAgent

@Suite("The singletons' initializers declare their MainActor isolation")
struct MainActorInitIsolationTests {

    // MARK: - The initializer carries the isolation

    @Test("each initializer that reads a MainActor value declares the isolation")
    func initializerDeclaresTheIsolation() throws {
        for source in InitializerSources.all {
            let text = try String(contentsOf: source.url, encoding: .utf8)
            #expect(
                source.declaresIsolation(in: text),
                "\(source.url.lastPathComponent) must declare @MainActor on \(source.initializer)"
            )
            #expect(
                !text.contains("MainActor.assumeIsolated"),
                "\(source.url.lastPathComponent) must not keep the runtime assertion"
            )
            if let staleClaim = source.staleClaim {
                #expect(
                    !text.contains(staleClaim),
                    "\(source.url.lastPathComponent) must not describe a type annotation it does not have"
                )
            }
        }
    }

    // MARK: - The compiler refuses an off-MainActor construction

    @Test("the compiler refuses to build the memory provider off the MainActor")
    func memoryProviderRejectsAnOffMainActorCaller() throws {
        let result = try compileOffMainActorCaller(building: "WSMemoryProvider")
        #expect(result.status != 0, "the compiler must refuse the caller")
        #expect(
            result.diagnostics.contains("main actor-isolated initializer"),
            "the refusal must name the actor isolation, not some other error: \(result.diagnostics)"
        )
    }

    @Test("the compiler refuses to build the memory manager off the MainActor")
    func memoryManagerRejectsAnOffMainActorCaller() throws {
        let result = try compileOffMainActorCaller(building: "MemoryManager")
        #expect(result.status != 0, "the compiler must refuse the caller")
        #expect(
            result.diagnostics.contains("main actor-isolated initializer"),
            "the refusal must name the actor isolation, not some other error: \(result.diagnostics)"
        )
    }

    @Test("the compiler refuses to build the conductor off the MainActor")
    func conductorRejectsAnOffMainActorCaller() throws {
        let result = try compileOffMainActorCaller(building: "WenshuConductor")
        #expect(result.status != 0, "the compiler must refuse the caller")
        #expect(
            result.diagnostics.contains("main actor-isolated initializer"),
            "the refusal must name the actor isolation, not some other error: \(result.diagnostics)"
        )
    }

    // MARK: - A caller away from the MainActor gets a value

    @Test("a caller away from the MainActor gets a memory provider, not a trap")
    func memoryProviderIsBuiltForABackgroundCaller() async {
        // Before the initializer declared its isolation, this call ran on the
        // background thread and the assertion killed the process (= the whole
        // suite died, with no failure to read). Now the initializer is
        // MainActor-isolated, so the call hops to the MainActor and returns.
        let provider = await Task.detached { await WSMemoryProvider() }.value
        #expect(
            provider.slug == "swiftdata-memory",
            "the provider must carry the same default slug (= the behaviour is unchanged)"
        )
        #expect(provider.isEnabled, "the provider must carry the same default flag")
    }

    @Test("a caller away from the MainActor gets a memory manager, not a trap")
    func memoryManagerIsBuiltForABackgroundCaller() async {
        let manager = await Task.detached { await MemoryManager() }.value
        let result = await manager.prefetch(userMessage: "a message")
        switch result {
        case .empty, .prefetched:
            break
        }
    }

    @Test("a caller away from the MainActor gets a conductor, not a trap")
    func conductorIsBuiltForABackgroundCaller() async {
        let conductor = await Task.detached { await WenshuConductor() }.value
        let settings = await conductor.turnSettingsForTesting()
        #expect(
            settings == AgentSettings(),
            "the conductor must carry the same default settings (= the behaviour is unchanged)"
        )
    }

    // MARK: - Helpers

    /// The three initializer sites that read a @MainActor value.
    private enum InitializerSources {
        struct Source {
            let url: URL
            /// The initializer's own signature (= the declaration the
            /// isolation must sit on).
            let initializer: String
            /// The claim about a type annotation the code does not have.
            let staleClaim: String?

            /// Whether the isolation is declared on the initializer.
            ///
            /// The declaration must be the annotation immediately above the
            /// initializer (= a class-level annotation would isolate every
            /// member, which is not what these types are).
            func declaresIsolation(in text: String) -> Bool {
                guard let range = text.range(of: initializer) else { return false }
                let above = text[text.startIndex..<range.lowerBound]
                let lines = above
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return lines.last == "@MainActor"
            }
        }

        static let all: [Source] = [
            Source(
                url: packageRoot
                    .appendingPathComponent("Sources/WenshuAgent/Memory/WSMemoryProvider.swift"),
                initializer: "public init(slug:",
                staleClaim: "is @MainActor (= class annotation)"
            ),
            Source(
                url: packageRoot
                    .appendingPathComponent("Sources/WenshuAgent/Memory/MemoryManager.swift"),
                initializer: "public init(maxCharBudget:",
                staleClaim: nil
            ),
            Source(
                url: packageRoot
                    .appendingPathComponent("Sources/WenshuAgent/Agent/WenshuConductor.swift"),
                initializer: "public init(\n        connector:",
                staleClaim: nil
            )
        ]

        /// The root of the WenshuAgent package (= the directory that holds
        /// Sources/ and Tests/).
        static let packageRoot: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The compiler's verdict on a caller that builds the named type away
    /// from the MainActor.
    private struct CompileResult {
        let status: Int32
        let diagnostics: String
    }

    /// Compile a caller that builds `type` away from the MainActor and
    /// return the compiler's verdict.
    ///
    /// The caller is compiled as its own translation unit against the built
    /// module, because the refusal has to happen in the compiler: it cannot
    /// be provoked from inside this test target, where such a call would
    /// simply fail to compile.
    private func compileOffMainActorCaller(building type: String) throws -> CompileResult {
        let source = """
        import WenshuAgent

        // A caller away from the MainActor.
        func buildsAwayFromTheMainActor() {
            _ = \(type)()
        }
        """
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("WenshuOffMainActorCaller-\(UUID().uuidString).swift")
        try source.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = [
            "-typecheck",
            "-swift-version", "6",
            "-I", try moduleSearchPath().path,
            file.path,
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CompileResult(
            status: process.terminationStatus,
            diagnostics: String(decoding: output, as: UTF8.self)
        )
    }

    /// The directory holding the built WenshuAgent module.
    ///
    /// The package builds its own module (= the package owns its version
    /// boundary) and the root package builds it as a local dependency, so
    /// both layouts are searched. A module built before the sources it
    /// answers for would report the old behaviour, so the newest module
    /// that is not older than the sources wins.
    private func moduleSearchPath() throws -> URL {
        let packageBuild = InitializerSources.packageRoot
            .appendingPathComponent(".build/debug")
        let repositoryBuild = InitializerSources.packageRoot
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/debug")
        let candidates = [packageBuild, repositoryBuild]
        let built = candidates.filter { directory in
            ["WenshuAgent", "WenshuData", "EventSource"].allSatisfy { module in
                FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent("\(module).swiftmodule").path
                )
            }
        }
        let sourceDate = InitializerSources.all
            .map { date(of: $0.url) }
            .max() ?? .distantPast
        let fresh = built.filter {
            date(of: $0.appendingPathComponent("WenshuAgent.swiftmodule")) >= sourceDate
        }
        guard let chosen = (fresh.isEmpty ? built : fresh).max(by: { lhs, rhs in
            date(of: lhs.appendingPathComponent("WenshuAgent.swiftmodule"))
                < date(of: rhs.appendingPathComponent("WenshuAgent.swiftmodule"))
        }) else {
            throw ModuleSearchPathError(candidates: candidates.map(\.path))
        }
        return chosen
    }

    private func date(of url: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.modificationDate] as? Date) ?? .distantPast
    }

    private struct ModuleSearchPathError: Error, CustomStringConvertible {
        let candidates: [String]
        var description: String {
            "no built WenshuAgent module found in: \(candidates.joined(separator: ", "))"
        }
    }
}
