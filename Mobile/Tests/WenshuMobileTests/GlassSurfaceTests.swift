import Foundation
import Testing
@testable import WenshuMobileApp

/// The glass surface gate and the call sites that use it.
///
/// The gate is one decision, so both sides of it are provable without a
/// device: the native side draws the system's own glass, the fallback
/// side draws the system's own material. The call sites are read from
/// the source, because a surface is drawn by a modifier and a modifier
/// is not visible to a test at runtime.
@Suite("GlassSurfaceTests")
struct GlassSurfaceTests {
    /// The gate follows the system that runs the app.
    ///
    /// The decision is the runtime's own answer, so a device on the
    /// system's glass takes the glass and a device below it takes the
    /// material.
    @Test func theAvailabilityGateFollowsTheSystemThatRunsTheApp() {
        if #available(iOS 26.0, macOS 26.0, *) {
            #expect(GlassSurface.nativeAvailable)
            #expect(GlassSurface.decide(nativeAvailable: GlassSurface.nativeAvailable) == .glass)
        } else {
            #expect(GlassSurface.nativeAvailable == false)
            #expect(GlassSurface.decide(nativeAvailable: GlassSurface.nativeAvailable) == .material)
        }
    }

    /// The gate decides the surface, and both sides of it are fixed.
    ///
    /// The availability is the only input, so the native side and the
    /// fallback side are each reachable and each one is decided.
    @Test func theAvailabilityGateDecidesTheSurface() {
        let native = GlassSurface.decide(nativeAvailable: true)
        let fallback = GlassSurface.decide(nativeAvailable: false)

        #expect(native == .glass)
        #expect(fallback == .material)
        #expect(native != fallback)
    }

    /// The decision follows its input every time.
    ///
    /// The decision is read fresh on every pass, so a call that took the
    /// fallback does not leave the next call on the fallback, and the
    /// other way round.
    @Test func theDecisionFollowsItsInputEveryTime() {
        _ = GlassSurface.decide(nativeAvailable: false)
        let afterTheFallback = GlassSurface.decide(nativeAvailable: true)
        _ = GlassSurface.decide(nativeAvailable: true)
        let afterTheNative = GlassSurface.decide(nativeAvailable: false)

        #expect(afterTheFallback == .glass)
        #expect(afterTheNative == .material)
    }

    /// The connection card draws on the central gate.
    ///
    /// The card asks the gate for its surface, so the gate is the one
    /// place that knows which surface the system offers. A card that
    /// named the material itself would be a second decision.
    @Test func theConnectionCardUsesTheCentralGate() throws {
        let source = try readSource("Sources/WenshuMobileApp/Features/Connection/View/ConnectionView.swift")

        #expect(source.contains(".glassSurface(ContainerRelativeShape())"))
        #expect(!codeLines(of: source).contains { $0.contains("background(.regularMaterial") })
    }

    /// The material is named in the gate alone.
    ///
    /// The gate is the one place that knows which surface the system
    /// offers, so a surface anywhere else that names the material itself
    /// would be a second decision.
    @Test func theMaterialIsNamedInTheGateAlone() throws {
        let naming = try swiftSources(in: "Sources/WenshuMobileApp")
            .filter { source in
                codeLines(of: source.text).contains { $0.contains("background(.regularMaterial") }
            }

        #expect(naming.map(\.path).sorted() == ["Sources/WenshuMobileApp/Shared/UI/GlassSurface.swift"])
    }

    /// The shell keeps the tab bar and holds one glass layer.
    ///
    /// The tab bar is the system's own, so the shell draws none of its
    /// own, and the surfaces of one screen share the container's layer.
    @Test func theShellKeepsItsTabBarInsideOneGlassContainer() throws {
        let source = try readSource("Sources/WenshuMobileApp/App/ClientShell.swift")
        let lines = codeLines(of: source)

        #expect(source.contains("TabView(selection:"))
        #expect(lines.filter { $0.contains("GlassEffectContainer") }.count == 1)
    }
}

// MARK: - The source under test

extension GlassSurfaceTests {
    /// A source file and where it sits.
    private struct Source {
        /// The path from the repository root.
        let path: String
        /// The file's text.
        let text: String
    }

    /// The repository root: the nearest ancestor holding a Package.swift.
    ///
    /// Probing for the manifest rather than counting the directories
    /// above this file keeps the read working when the test tree moves.
    private static let repoRoot: URL = {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current
            }
            current.deleteLastPathComponent()
        }
        fatalError("GlassSurfaceTests: no Package.swift above \(#filePath)")
    }()

    /// Reads a production source file as UTF-8.
    private func readSource(_ relativePath: String) throws -> String {
        let url = Self.repoRoot.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return text
    }

    /// Every Swift file under a directory, read as UTF-8.
    private func swiftSources(in relativePath: String) throws -> [Source] {
        let root = Self.repoRoot.appendingPathComponent(relativePath)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var sources: [Source] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let path = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
            sources.append(Source(path: path, text: text))
        }
        return sources
    }

    /// The code lines of a source file, with its comments left out.
    ///
    /// A comment may name a surface in passing; only the code decides.
    private func codeLines(of source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.isEmpty }
    }
}
