//
//  WenshuMarkdownEditorAdapterTests.swift · Wenshu · v0.39 ticket 001
//
// Swift Testing suite for the swift-markdown-engine adapter layer
// (= WenshuMarkdownEditor + 2 service protocols + factory). Verifies:
// - WikiLinkResolver: hit + miss (resolve(name:range:))
// - EmbeddedImageProvider: hit (character portrait, world picture,
//   raw fallback) + miss, and a fingerprint that follows the world folder
// - WenshuMarkdownEditor: SwiftUI mount produces a view (no crash)
//
// Per Q182.4: Swift Testing framework (= wenshu convention since v0.30+);
// @MainActor isolation inherited from the types under test (AppState is
// @MainActor-isolated; engine's NSViewRepresentable requires main).
//

import Testing
import Foundation
import AppKit
import SwiftUI
import MarkdownEngine
import MarkdownEngineLatex
@testable import WenshuApp

@MainActor
@Suite("WenshuMarkdownEditor (swift-markdown-engine adapter)")
struct WenshuMarkdownEditorAdapterTests {

    // MARK: - Fixtures

    /// Build a temp directory shaped like a wenshu reference-library
    /// (= `entities/` folder with 0+ JSON entity files). Returns the
    /// reference-library root URL. Auto-cleaned via `.tmp` + deinit.
    private func makeReferenceLibrary(entities: [(id: String, name: String)]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("reference-library", isDirectory: true)
        let entitiesDir = root.appendingPathComponent("entities", isDirectory: true)
        try FileManager.default.createDirectory(at: entitiesDir, withIntermediateDirectories: true)
        for entity in entities {
            let url = entitiesDir.appendingPathComponent("\(entity.id).json")
            let json: [String: Any] = ["id": entity.id, "name": entity.name]
            let data = try JSONSerialization.data(withJSONObject: json)
            try data.write(to: url)
        }
        return root
    }

    /// Build a temp directory shaped like a wenshu book (= a
    /// `characters/` folder and a `world/` folder, each with 0+ PNG
    /// files). Returns the book root URL.
    private func makeBook(characterImages: [String], worldImages: [String] = []) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-book-\(UUID().uuidString)", isDirectory: true)
        try writePNGs(named: characterImages, in: root.appendingPathComponent("characters"))
        try writePNGs(named: worldImages, in: root.appendingPathComponent("world"))
        return root
    }

    /// Build a temp directory shaped like the reference library's raw
    /// layer (= a `raw/` folder with 0+ PNG files). Returns the
    /// reference-library root URL.
    private func makeRawReferenceLibrary(rawImages: [String] = []) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-raw-\(UUID().uuidString)", isDirectory: true)
        try writePNGs(named: rawImages, in: root.appendingPathComponent("raw"))
        return root
    }

    /// Write 0+ 1x1 transparent PNGs (= 67 bytes; = valid minimal PNG)
    /// named `<name>.png` into `directory`, creating it if needed.
    private func writePNGs(named names: [String], in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in names {
            let png: [UInt8] = [
                0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
                0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
                0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
                0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
                0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
                0x42, 0x60, 0x82
            ]
            try Data(png).write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    // MARK: - WikiLinkResolver tests

    @Test("WikiLinkResolver hit returns exists: true with matching id")
    func wikiLinkResolverHit() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna"),
            (id: "uuid-beth", name: "Beth")
        ])
        let resolver = ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot)
        let result = resolver.resolve(displayName: "Anna", range: NSRange(location: 0, length: 0))
        #expect(result != nil)
        #expect(result?.exists == true)
        #expect(result?.id == "uuid-anna")
    }

    @Test("WikiLinkResolver miss returns exists: false with empty id")
    func wikiLinkResolverMiss() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna")
        ])
        let resolver = ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot)
        let result = resolver.resolve(displayName: "Ghost", range: NSRange(location: 0, length: 0))
        #expect(result != nil)
        #expect(result?.exists == false)
        #expect(result?.id == "")
    }

    // MARK: - EmbeddedImageProvider tests

    @Test("EmbeddedImageProvider hit returns NSImage for character portrait")
    func imageProviderHit() async throws {
        let bookRoot = try makeBook(characterImages: ["Anna", "Beth"])
        let refRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: refRoot.appendingPathComponent("raw", isDirectory: true),
            withIntermediateDirectories: true
        )
        let provider = ReferenceLibraryImageProvider(
            activeBookRoot: bookRoot,
            referenceLibraryRoot: refRoot
        )
        let img = provider.image(for: EmbeddedImageRequest(name: "Anna"))
        #expect(img != nil)
    }

    @Test("EmbeddedImageProvider miss returns nil")
    func imageProviderMiss() async throws {
        let bookRoot = try makeBook(characterImages: ["Anna"])
        let refRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-test-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: refRoot.appendingPathComponent("raw", isDirectory: true),
            withIntermediateDirectories: true
        )
        let provider = ReferenceLibraryImageProvider(
            activeBookRoot: bookRoot,
            referenceLibraryRoot: refRoot
        )
        let img = provider.image(for: EmbeddedImageRequest(name: "Ghost"))
        #expect(img == nil)
    }

    // MARK: - EmbeddedImageProvider: the book's world folder

    /// The provider searches the book's `characters/`, the book's
    /// `world/`, and the library's `reference-library/raw/`. A picture
    /// in the world folder resolves like any other (= the world's
    /// on-disk folder name comes from the folder catalogue, so the
    /// provider and the disk agree).
    @Test("EmbeddedImageProvider resolves a picture in the book's world folder")
    func imageProviderResolvesWorldFolderPicture() async throws {
        let bookRoot = try makeBook(characterImages: ["Anna"], worldImages: ["Map"])
        let refRoot = try makeRawReferenceLibrary(rawImages: ["Cover"])
        let provider = ReferenceLibraryImageProvider(
            activeBookRoot: bookRoot,
            referenceLibraryRoot: refRoot
        )
        #expect(provider.image(for: EmbeddedImageRequest(name: "Map")) != nil)
        // The other two folders keep resolving (= the world folder is
        // searched, not swapped for one of them).
        #expect(provider.image(for: EmbeddedImageRequest(name: "Anna")) != nil)
        #expect(provider.image(for: EmbeddedImageRequest(name: "Cover")) != nil)
    }

    /// The fingerprint covers the same three folders the lookup uses,
    /// so two books that differ only in their world folder carry
    /// different fingerprints (= the engine's image cache invalidates
    /// when a world-folder picture changes).
    @Test("EmbeddedImageProvider fingerprint differs between books differing only in the world folder")
    func imageProviderFingerprintFollowsWorldFolder() async throws {
        let refRoot = try makeRawReferenceLibrary()
        let bookA = try makeBook(characterImages: [], worldImages: ["Map"])
        let bookB = try makeBook(characterImages: [], worldImages: ["Atlas"])
        let fingerprintA = ReferenceLibraryImageProvider(
            activeBookRoot: bookA,
            referenceLibraryRoot: refRoot
        ).fingerprint()
        let fingerprintB = ReferenceLibraryImageProvider(
            activeBookRoot: bookB,
            referenceLibraryRoot: refRoot
        ).fingerprint()
        #expect(fingerprintA != fingerprintB)
    }

    // MARK: - WenshuMarkdownEditor mount test

    @Test("WenshuEditorServicesFactory.make builds a valid configuration")
    func servicesFactoryBuilds() async throws {
        let refRoot = try makeReferenceLibrary(entities: [
            (id: "uuid-anna", name: "Anna")
        ])
        let bookRoot = try makeBook(characterImages: [])
        // Build the configuration WITHOUT exercising the highlighter
        // (= HighlighterSwiftBridge.init requires a fully running
        // AppKit stack with theme assets loaded; Swift Testing runs
        // outside the normal runloop and the bridge crashes on nil
        // Highlighter). We test the factory plumbing by building
        // a stripped-down configuration that skips the highlighter
        // (= the production WenshuEditorServicesFactory does include
        // it, but its init is not the responsibility of THIS test).
        let services = MarkdownEditorServices(
            wikiLinks: ReferenceLibraryWikiLinkResolver(referenceLibraryRoot: refRoot),
            images: ReferenceLibraryImageProvider(
                activeBookRoot: bookRoot,
                referenceLibraryRoot: refRoot
            )
        )
        // Round-trip the configuration through WenshuMarkdownEditor
        // (= the engine requires services to be on a configuration,
        // not standalone). This validates that the type wires up
        // cleanly without exercising HighlighterSwift.
        var config = MarkdownEditorConfiguration.default
        config.services = services
        #expect(config.services.wikiLinks.resolve(
            displayName: "Anna", range: NSRange(location: 0, length: 0)
        )?.exists == true)
    }

    // MARK: - Fixture helpers for content-sniff tests (= T-01 source-content gate)

    /// Resolve a path relative to the wenshu repo root from this test
    /// file's location. The worktree lays the file under
    /// `.worktrees/editor-smc-defaults/Tests/WenshuAppTests/Editor/` →
    /// walking up 4 segments lands on `.worktrees/editor-smc-defaults/`
    /// (= the worktree root, = the canonical "repo root" inside the
    /// worktree). One more segment up (5) would step out of the
    /// worktree into the wenshu main repo; = don't do that.
    private func resolve(_ relative: String) -> String {
        var url = SourceLocator.repoRoot
        url.appendPathComponent(relative)
        return url.path
    }

    /// The file's code lines only (= the whole-line comments dropped),
    /// so a comment that names a symbol neither satisfies nor breaks a
    /// gate. Block comments are not stripped (= the files these gates
    /// read carry line comments only).
    private func codeOnly(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !String($0).trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Reading a SwiftUI branch STRUCTURALLY

    /// Which side of a branch the editor's height-mode check is on.
    enum HeightModeBranch {
        /// The branch that runs when the editor fits its content.
        case fitsContent
        /// The branch that runs when the editor scrolls internally.
        case scrolls
        /// The condition says neither (= the check is somewhere else, or
        /// it is spelled in a way this reader does not resolve).
        case unknown
    }

    /// The two bodies of one `if`/`else` pair.
    struct BranchPair {
        /// The body of the branch the height-mode check selects.
        var gated: String
        /// The body of the branch it does NOT select.
        var other: String
    }

    /// Blank every comment and every string literal (= the characters
    /// become spaces, = so the offsets still line up with the original).
    ///
    /// WHY: the reader must not be fooled by a DECOY. A phrase that sits
    /// in a trailing comment, = in a block comment, = or in a string
    /// literal is not code, = and a reader that reads it as code can be
    /// pointed at the wrong branch. (= the same reason the suite's
    /// `codeOnly` drops whole-line comments: = a comment that names a
    /// symbol must neither satisfy nor break a gate.)
    private func blankingCommentsAndStrings(_ source: String) -> String {
        let chars = Array(source)
        var out = chars
        var i = 0
        // 0 = code, 1 = a line comment, 2 = a block comment, 3 = a string.
        var state = 0
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            switch state {
            case 0:
                if c == "/", next == "/" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 1; continue
                }
                if c == "/", next == "*" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 2; continue
                }
                if c == "\"" {
                    out[i] = " "; i += 1; state = 3; continue
                }
            case 1:
                if c == "\n" { state = 0 } else { out[i] = " " }
            case 2:
                if c == "*", next == "/" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 0; continue
                }
                if c != "\n" { out[i] = " " }
            case 3:
                if c == "\\" {
                    out[i] = " "
                    if i + 1 < chars.count { out[i + 1] = " " }
                    i += 2; continue
                }
                if c == "\"" {
                    out[i] = " "; i += 1; state = 0; continue
                }
                if c != "\n" { out[i] = " " }
            default:
                break
            }
            i += 1
        }
        return String(out)
    }

    /// The editor's own `body`, = which is the region the gate's claim
    /// is about.
    ///
    /// WHY THE REGION IS FOUND BY THE TYPE AND NOT BY THE PHRASE: the
    /// phrase `var body: some View {` belongs to EVERY view, = so the
    /// first one in the file is not necessarily the editor's. = A second
    /// view type earlier in the file (= one with its own height-mode
    /// branch) would capture the reader, = and the editor's real branch
    /// would never be read = which is a HOLE (= the defect ships
    /// undetected) = and not a false positive.
    ///
    /// So the region is the body that belongs to the editor's OWN
    /// declaration, = and = at brace depth one inside it (= a nested
    /// type's own `var body` is at depth two, = and a `var body` inside a
    /// closure is deeper still).
    private func editorBodyRegion(in readable: String) -> String? {
        guard let declaration = readable.range(of: "struct WenshuMarkdownEditor"),
              let brace = readable.range(of: "{",
                                         range: declaration.upperBound..<readable.endIndex),
              let typeEnd = matchingBrace(in: readable, from: brace.lowerBound),
              let bodyBrace = topLevelBodyDeclaration(in: readable,
                                                      from: brace.lowerBound,
                                                      to: typeEnd),
              let bodyEnd = matchingBrace(in: readable, from: bodyBrace)
        else { return nil }
        return String(readable[readable.index(after: bodyBrace)..<bodyEnd])
    }

    /// The `{` of the `var body: some View {` that belongs DIRECTLY to a
    /// type, = and not to a nested type or to a closure.
    private func topLevelBodyDeclaration(in code: String,
                                         from typeBrace: String.Index,
                                         to typeEnd: String.Index) -> String.Index? {
        let needle = "var body: some View {"
        var depth = 0
        var i = typeBrace
        while i < typeEnd {
            if depth == 1, code[i...].hasPrefix(needle) {
                return code.index(i, offsetBy: needle.count - 1)
            }
            switch code[i] {
            case "{": depth += 1
            case "}": depth -= 1
            default: break
            }
            i = code.index(after: i)
        }
        return nil
    }

    /// Find the `if`/`else` pair inside the editor's body whose
    /// condition resolves to the editor's height-mode check, and return
    /// both bodies.
    ///
    /// WHY A STRUCTURAL READ AND NOT A SUBSTRING SEARCH: the condition
    /// can be spelled six ways, and a substring search only catches one
    /// of them.
    ///
    ///  1. written out (= `surface.configuration.heightBehavior ==
    ///     .fitsContent`), = which a substring search finds, = but it
    ///     also finds the phrase when the phrase is somewhere ELSE and
    ///     the branch is inverted.
    ///  2. extracted into a computed property (= `if isFitsContent`),
    ///     which a substring search MISSES, = and a search for the
    ///     phrase plus the word `if` would FALSE-POSITIVE on it.
    ///  3. negated (= `if !isFitsContent`), = which names the OTHER
    ///     branch.
    ///  4. negated in place (= `if !(surface.configuration.heightBehavior
    ///     == .fitsContent)`), = which is the same and reads the same
    ///     way, = and which a "contains the phrase" test gets BACKWARDS.
    ///  5. written with `!=` (= `if surface.configuration.heightBehavior
    ///     != .fitsContent`), = which is the OTHER branch written the
    ///     other way round.
    ///  6. the enum spelled in full (= `if surface.configuration
    ///     .heightBehavior == MarkdownEditorConfiguration.HeightBehavior
    ///     .fitsContent`), = which is the SAME branch, = and which a
    ///     test for the phrase `heightBehavior == .fitsContent` MISSES.
    ///
    /// So the condition is resolved to the thing it NAMES (= a computed
    /// property is followed to its own body and read there, = a negation
    /// is read as the branch it excludes, = and the comparison is SPLIT
    /// so that the enum may be spelled any way it likes), = and the
    /// branch bodies are found by matching braces (= never by taking the
    /// first `} else {` in the file).
    ///
    /// WHICH BRANCH, WHEN THERE IS MORE THAN ONE: the claim is about the
    /// branch that RENDERS THE EDITOR, = so the branch is the one whose
    /// body hands the engine to SwiftUI. = A height-mode check that
    /// only picks a background colour is a legitimate thing to add, = and
    /// the gate must not be captured by it.
    ///
    /// - Parameter readable: the source with comments and strings blanked.
    /// - Returns: the pair, or nil when no branch resolves to the check.
    private func heightModeBranchPair(in readable: String) -> BranchPair? {
        guard let body = editorBodyRegion(in: readable) else { return nil }
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        var offset = 0
        for line in lines {
            // The `if` must OPEN a line (= a decoy in a comment, = in a
            // string, = or in the middle of a line must not be able to
            // point the reader at the wrong branch).
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("if ") {
                let lineStart = body.index(body.startIndex, offsetBy: offset)
                // The condition starts AFTER the `if ` (= and after the
                // line's indentation, = or the condition would still
                // carry the `if ` and read as an expression).
                let indent = line.prefix { $0 == " " || $0 == "\t" }.count
                let afterIf = body.index(lineStart, offsetBy: indent + 3)
                let searchEnd = body.index(afterIf, offsetBy: 400, limitedBy: body.endIndex)
                    ?? body.endIndex
                if let brace = body.range(of: "{", range: afterIf..<searchEnd),
                   let bodyEnd = matchingBrace(in: body, from: brace.lowerBound)
                {
                    let condition = String(body[afterIf..<brace.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let ifBody = String(body[brace.upperBound..<bodyEnd])
                    let elseBody = elseBody(of: body, after: bodyEnd)

                    let pair: BranchPair?
                    switch heightMode(of: condition, in: readable) {
                    case .fitsContent:
                        pair = BranchPair(gated: ifBody, other: elseBody ?? "")
                    case .scrolls:
                        pair = elseBody.map { BranchPair(gated: $0, other: ifBody) }
                    case .unknown:
                        pair = nil
                    }
                    // The branch that renders the editor (= and only
                    // that one) is the one the claim is about.
                    if let pair, mentionsEngine(pair.gated) || mentionsEngine(pair.other) {
                        return pair
                    }
                }
            }
            offset += line.count + 1
        }
        return nil
    }

    /// Whether a branch body hands the EDITOR's engine to SwiftUI.
    ///
    /// The token, = not a substring (= so `engineering` does not count),
    /// and the comments are already blanked (= so a comment that names
    /// the engine cannot make a branch qualify).
    private func mentionsEngine(_ text: String) -> Bool {
        var search = text.startIndex
        while let range = text.range(of: "engine", range: search..<text.endIndex) {
            let before = range.lowerBound == text.startIndex
                ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex
                ? nil : text[range.upperBound]
            let beforeOK = before.map { !($0.isLetter || $0.isNumber || $0 == "_") } ?? true
            let afterOK = after.map { !($0.isLetter || $0.isNumber || $0 == "_") } ?? true
            if beforeOK && afterOK { return true }
            search = range.upperBound
        }
        return false
    }

    /// The body of the `else` that follows an `if` block, or nil when
    /// the `if` has no `else` (= or when what follows is not one).
    ///
    /// An `else if` CHAIN is not resolved (= the reader reports no
    /// branch, = which fails the gate loudly; = it never reads the
    /// chain's first branch as if it were the height-mode one).
    private func elseBody(of code: String, after bodyEnd: String.Index) -> String? {
        var i = code.index(after: bodyEnd)
        while i < code.endIndex, code[i].isWhitespace { i = code.index(after: i) }
        guard code[i...].hasPrefix("else") else { return nil }
        let afterElse = code.index(i, offsetBy: 4)
        var j = afterElse
        while j < code.endIndex, code[j].isWhitespace { j = code.index(after: j) }
        guard j < code.endIndex, code[j] == "{" else { return nil }
        guard let end = matchingBrace(in: code, from: j) else { return nil }
        return String(code[code.index(after: j)..<end])
    }

    /// The index of the `}` that closes the `{` at `open`.
    private func matchingBrace(in code: String, from open: String.Index) -> String.Index? {
        var depth = 0
        var i = open
        while i < code.endIndex {
            switch code[i] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return i }
            default: break
            }
            i = code.index(after: i)
        }
        return nil
    }

    /// Which height-mode branch a condition selects, resolved through a
    /// computed property when the condition names one, = and read
    /// through a negation when the condition is negated.
    private func heightMode(of condition: String, in code: String, depth: Int = 0) -> HeightModeBranch {
        var text = condition.trimmingCharacters(in: .whitespacesAndNewlines)
        var negated = false
        // A leading `!` and the parentheses around the test are noise
        // for the question "is this branch the fitsContent one?".
        while true {
            if text.hasPrefix("!") {
                negated.toggle()
                text = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            if text.hasPrefix("("), text.hasSuffix(")"), isBalanced(text) {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            break
        }
        let base: HeightModeBranch
        if text.isHeightModeIdentifier {
            guard depth < 3 else { return .unknown }
            base = heightModeOfComputedProperty(named: text, in: code, depth: depth)
        } else {
            base = heightModeOfComparison(text)
        }
        guard base != .unknown else { return .unknown }
        return negated ? (base == .fitsContent ? .scrolls : .fitsContent) : base
    }

    /// The branch a COMPARISON selects, however the enum is spelled.
    ///
    /// WHY A PARSE AND NOT A PHRASE: the right-hand side names the mode
    /// in three ways, = and a substring test catches one of them:
    /// `.fitsContent`, = `fitsContent`, = and
    /// `MarkdownEditorConfiguration.HeightBehavior.fitsContent` (= the
    /// fully qualified case, = which is a legitimate rewrite, = and which
    /// a test for the phrase `heightBehavior == .fitsContent` MISSES).
    /// So the comparison is SPLIT, = the left side must name the
    /// behaviour, = and the right side is read by its LAST path
    /// component (= so any prefix resolves to the same case).
    ///
    /// The operator decides the polarity: `heightBehavior ==
    /// .fitsContent` is TRUE in the fitsContent mode, = and
    /// `heightBehavior != .fitsContent` is TRUE in the other one.
    private func heightModeOfComparison(_ text: String) -> HeightModeBranch {
        for (op, isEqual) in [("!=", false), ("==", true)] {
            guard let range = text.range(of: op) else { continue }
            let left = String(text[..<range.lowerBound])
            let right = String(text[range.upperBound...])
            guard left.contains("heightBehavior") else { continue }
            guard let mode = heightModeName(of: right) else { continue }
            let selectsFitsContent = (mode == .fitsContent)
            return (isEqual == selectsFitsContent) ? .fitsContent : .scrolls
        }
        return .unknown
    }

    /// The mode an enum case names, however it is spelled.
    private func heightModeName(of text: String) -> HeightModeBranch? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.split(separator: ".").last else { return nil }
        switch last {
        case "fitsContent": return .fitsContent
        case "scrolls": return .scrolls
        default: return nil
        }
    }

    /// Whether the parentheses in a condition are balanced (= so a
    /// condition that is only WRAPPED can be unwrapped).
    private func isBalanced(_ text: String) -> Bool {
        var depth = 0
        for c in text {
            if c == "(" { depth += 1 }
            if c == ")" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }

    /// The branch a computed property's own body selects.
    private func heightModeOfComputedProperty(named name: String, in code: String, depth: Int = 0) -> HeightModeBranch {
        guard let declaration = code.range(of: "var \(name): Bool {",
                                          range: code.startIndex..<code.endIndex),
              // The declaration's OWN `{` opens the computed property's
              // body (= searching forward from `declaration.upperBound`
              // would find the NEXT `{` in the file, = which is a
              // different scope entirely).
              let brace = code.range(of: "{", range: declaration.lowerBound..<declaration.upperBound),
              let end = matchingBrace(in: code, from: brace.lowerBound)
        else { return .unknown }
        let body = String(code[brace.upperBound..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = heightModeOfComparison(body)
        if resolved != .unknown { return resolved }
        // The property may name ANOTHER property (= a property of a
        // property), = so the read follows the name one more step.
        if body.isHeightModeIdentifier {
            return heightMode(of: body, in: code, depth: depth + 1)
        }
        return .unknown
    }

    // MARK: - LaTeX rendering enabled (= boss拍 2026-10-11)

    @Test("WenshuEditorServicesFactory constructs a LatexRenderer (= NoOpLatexRenderer is NOT the production choice)")
    func servicesFactoryEnablesLaTeX() throws {
        // Build MarkdownEditorServices exactly as `WenshuEditorServicesFactory.make`
        // does, then assert `services.latex` is NOT the legacy NoOpLatexRenderer
        // (= the engine ships SwiftMathBridge(= SwiftMath) as a separate SPM
        // product; we don't drive SwiftMathBridge.init here because that pulls
        // MTMathUILabel which lazy-loads NSBundle resources and SIGTRAPs the
        // XCTest runner — matching the HighlighterSwift trap documented
        // above). Reusing a snapshot of the live factory's `services` build
        // is enough to gate the regression; do NOT call factory.make() directly.
        let services = MarkdownEditorServices(
            wikiLinks: NoOpWikiLinkResolver(),
            images: NoOpEmbeddedImageProvider(),
            syntaxHighlighter: PlainTextSyntaxHighlighter(),
            latex: SwiftMathBridge(),
            bus: .default
        )
        let typeName = String(describing: type(of: services.latex))
        #expect(
            typeName.contains("SwiftMathBridge"),
            "services.latex must be SwiftMathBridge (= boss拍 2026-10-11). Got: \(typeName)"
        )
    }

    // MARK: - ed-smc-defaults T-01: placeholder slot wired

    /// SMC exposes a `placeholder:` slot on `NativeTextViewWrapper`.
    /// We extended `WenshuMarkdownEditor` (= the wenshu-side SwiftUI
    /// view that wraps the engine wrapper) to forward it. This
    /// source-content test catches a regression where someone removes
    /// the forwarding and the start-writing ghost text silently
    /// disappears (= the visible UI failure mode the user reports
    /// first).
    ///
    /// Why source-content instead of `swift-mock-test`: we don't drive
    /// NSViewRepresentable here (= AppKit NSWindow needed, = outside
    /// the Swift Testing sandbox); = verify the contract literally.
    /// If anyone walks the slot away, the contract disclaims.
    @Test("WenshuMarkdownEditor forwards SMC `placeholder:`")
    func forwardsSMCPlaceholderSlot() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let content = try String(contentsOfFile: editorPath, encoding: .utf8)

        // Placeholder slot forwarded — the wenshu view MUST pass the
        // surface's placeholder to NativeTextViewWrapper (= otherwise
        // the ghost text disappears, = invisible UI regression).
        #expect(
            content.contains("placeholder: surface.placeholder"),
            "WenshuMarkdownEditor must forward the `placeholder: placeholder` argument to NativeTextViewWrapper (= ed-smc-defaults T-01)"
        )

        // Padding removal — the previous `.padding(.all,
        // DesignTokens.zoneContentInset)` wrap was what produced the
        // white rectangle the user reported as superfluous. The
        // wrapper now sits flush against the editor zone's own
        // background. If anyone reintroduces a `.padding(.all,
        // DesignTokens.zoneContentInset)` wrap around
        // NativeTextViewWrapper, the rectangle comes back.
        let pattern = #"\.padding\(\.all,\s*DesignTokens\.zoneContentInset\)"#
        #expect(
            content.range(of: pattern, options: .regularExpression) == nil,
            "WenshuMarkdownEditor must NOT re-wrap NativeTextViewWrapper in `.padding(.all, DesignTokens.zoneContentInset)` (= T-01: the white-card rectangle is removed)"
        )
    }

    // MARK: - ed-smc-defaults T-02: format toolbar pinned + 12-button contract

    /// The 12-button format toolbar (= Pages / Numbers / Keynote
    /// document-chrome idiom). Each button posts a `MarkdownEditorBus`
    /// request name that the engine observes internally. The toolbar
    /// must cover exactly 12 actions (= the engine's full format
    /// surface: bold / italic / highlight / strikethrough /
    /// inline-code / heading / blockquote / unordered-list /
    /// ordered-list / link / code-block / horizontal-rule). If
    /// anyone adds a 13th case, this test fails (= the toolbar
    /// contract drift surface). If anyone drops a case, this test
    /// fails (= the toolbar silently loses a button).
    @Test("EditorFormatAction covers the engine's 12-button format surface (= T-02)")
    func formatActionCoverage() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorFormatToolbar.swift")
        let toolbar = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(
            toolbar.contains("enum EditorFormatAction"),
            "EditorFormatAction enum must live in EditorFormatToolbar.swift"
        )
        #expect(
            toolbar.contains("var iconName: String"),
            "EditorFormatAction.iconName must be defined (= SF Symbol mapping per case)"
        )
        #expect(
            EditorFormatAction.allCases.count == 12,
            "EditorFormatAction.allCases must cover exactly 12 buttons (= engine's full format surface)"
        )
        let expectedCases: Set<String> = [
            "bold", "italic", "highlight", "strikethrough",
            "inlineCode", "heading", "blockquote",
            "unorderedList", "orderedList",
            "link", "codeBlock", "horizontalRule"
        ]
        let actualCases = Set(EditorFormatAction.allCases.map(\.rawValue))
        #expect(
            actualCases == expectedCases,
            "EditorFormatAction cases must match the engine's 12-button contract (= names below must match the bus public surface)"
        )
    }

    /// The toolbar dispatches via `FormatDispatcher` (= canonical helper
    /// in EditorActions.swift) and the raw `bus.apply…Request`
    /// notification names. Source-content test gates both the helper
    /// use (= bold) AND the bus-name dispatch (= the other 11).
    @Test("EditorFormatToolbar dispatches via FormatDispatcher + bus names (= T-02)")
    func formatToolbarDispatchContract() throws {
        let toolbarPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorFormatToolbar.swift")
        let toolbar = try String(contentsOfFile: toolbarPath, encoding: .utf8)
        #expect(
            toolbar.contains("FormatDispatcher(bus: bus)"),
            "EditorFormatToolbar must construct FormatDispatcher (= canonical bus-dispatch helper)"
        )
        #expect(
            toolbar.contains("post(bus.applyBoldRequest)")
                || toolbar.contains("dispatcher.applyBold()"),
            "Bold dispatch must be wired (= the engine's contract for format-surface parity)"
        )
        // The toolbar must reach into every bus name at least once
        // (= the contract is "12 names, 12 dispatches"). Source-grep
        // each so a future dropped case fails this test.
        let busNames = [
            "applyItalicRequest", "applyHighlightRequest",
            "applyStrikethroughRequest", "applyInlineCodeRequest",
            "applyHeadingRequest", "applyBlockquoteRequest",
            "applyUnorderedListRequest", "applyOrderedListRequest",
            "applyLinkRequest", "applyCodeBlockRequest",
            "applyHorizontalRuleRequest"
        ]
        for name in busNames {
            #expect(
                toolbar.contains("bus.\(name)"),
                "EditorFormatToolbar must reference `bus.\(name)` (= dropped case in the 12-button contract)"
            )
        }
    }

    /// `EditorEditContent` (= the edit-mode wrapper) must forward the
    /// `editorPlaceholder` slot added in T-02 so the start-writing
    /// ghost text stays visible while editing (= canonical Pages /
    /// Numbers document-chrome-survives-WYSIWYG-toggle pattern).
    @Test("EditorEditContent forwards SMC `editorPlaceholder:` (= T-02)")
    func editorEditContentForwardsPlaceholderSlot() throws {
        let editPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorEditContent.swift")
        let edit = try String(contentsOfFile: editPath, encoding: .utf8)
        let surfacePath = resolve("Sources/WenshuApp/Features/Editor/Model/EditorSurface.swift")
        let surface = try String(contentsOfFile: surfacePath, encoding: .utf8)
        // The placeholder slot lives on the editor surface (= the set of
        // values the host hands to the engine), and the edit content
        // forwards that one surface. The contract is unchanged: the
        // slot still reaches the engine.
        #expect(
            surface.contains("let placeholder: NSAttributedString?"),
            "the editor surface must expose `placeholder: NSAttributedString?` (= SMC chrome slot)"
        )
        #expect(
            edit.contains("surface: surface"),
            "EditorEditContent body must forward the editor surface into the inner WenshuMarkdownEditor"
        )
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(
            editor.contains("placeholder: surface.placeholder"),
            "the engine wrapper must forward the placeholder slot out of the surface"
        )
    }

    // MARK: - ed-smc-defaults T-04: 5th InspectorPage (= documentTools)

    // MARK: - ed-smc-defaults T-05: format-readout sub-tool body shipped
    //
    // Removed 2026-10-18: formatReadout was deleted as a feature
    // (= boss directive; = no future T-05 will reintroduce it).
    // See OOB.md #2026-10-18 for the full rationale and rejection
    // criterion (= any subsequent .formatReadout restoration is a
    // reject-on-sight violation).

    // MARK: - ed-smc-defaults T-06: find & replace sub-tool body shipped

    // MARK: - ed-smc-defaults T-07: heading outline sub-tool body shipped

    // MARK: - ed-smc-defaults T-08: code-block list sub-tool body shipped

    // MARK: - ed-smc-defaults T-09: spell-check toggles sub-tool body shipped

    // MARK: - ed-smc-defaults T-11: explicit default-theme binding

    /// T-11 binds `MarkdownEditorTheme.default` explicitly in
    /// `WenshuEditorServicesFactory.make`. The binding is the
    /// single landing-spot for future retheme work (= a future
    /// ticket that wants to swap the default theme for a
    /// wenshu-tuned one has one place to edit).
    @Test("WenshuEditorServicesFactory binds MarkdownEditorTheme.default (= T-11)")
    func servicesFactoryBindsMarkdownEditorThemeDefault() throws {
        let factoryPath = resolve("Sources/WenshuApp/Features/Editor/Service/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        #expect(
            factory.contains("config.theme = MarkdownEditorTheme.default"),
            "WenshuEditorServicesFactory.make must explicitly bind MarkdownEditorTheme.default (= single landing-spot for future retheme work)"
        )
    }

    // MARK: - ed-smc-defaults T-12: EditorPreferences AppStorage schema

    /// T-12 ships `EditorPreferences` (= the host-side struct that
    /// snapshots the user's editor preferences for the factory).
    /// Source-content gate: if anyone removes the struct the
    /// AppStorage schema silently reverts (= a future Settings
    /// panel has no place to bind).
    @Test("EditorPreferences schema exists with 8 keys (= 6 T-12 + 2 list-editing)")
    func editorPreferencesSchemaHasEightKeys() throws {
        let prefPath = resolve("Sources/WenshuApp/Features/Editor/Model/EditorPreferences.swift")
        let pref = try String(contentsOfFile: prefPath, encoding: .utf8)
        #expect(pref.contains("struct EditorPreferences"),
                "EditorPreferences struct must exist (= host-side AppStorage schema)")
        #expect(pref.contains("readingWidth"),
                "EditorPreferences must declare a field named readingWidth (= AppStorage schema key)")
        #expect(pref.contains("heightBehavior"),
                "EditorPreferences must declare a field named heightBehavior (= AppStorage schema key)")
        #expect(pref.contains("rawSourceMode"),
                "EditorPreferences must declare a field named rawSourceMode (= AppStorage schema key)")
        #expect(pref.contains("continuousSpellChecking"),
                "EditorPreferences must declare a field named continuousSpellChecking (= AppStorage schema key)")
        #expect(pref.contains("grammarChecking"),
                "EditorPreferences must declare a field named grammarChecking (= AppStorage schema key)")
        #expect(pref.contains("automaticSpellingCorrection"),
                "EditorPreferences must declare a field named automaticSpellingCorrection (= AppStorage schema key)")
        #expect(pref.contains("listHelpersEnabled"),
                "EditorPreferences must declare a field named listHelpersEnabled (= AppStorage schema key)")
        #expect(pref.contains("autoClosePairsEnabled"),
                "EditorPreferences must declare a field named autoClosePairsEnabled (= AppStorage schema key)")
        #expect(pref.contains("case readingWidth"),
                "EditorPreferences.AppStorageKey must declare readingWidth case")
        #expect(pref.contains("case heightBehavior"),
                "EditorPreferences.AppStorageKey must declare heightBehavior case")
        #expect(pref.contains("case rawSourceMode"),
                "EditorPreferences.AppStorageKey must declare rawSourceMode case")
        #expect(pref.contains("case listHelpersEnabled"),
                "EditorPreferences.AppStorageKey must declare listHelpersEnabled case")
        #expect(pref.contains("case autoClosePairsEnabled"),
                "EditorPreferences.AppStorageKey must declare autoClosePairsEnabled case")
    }

    /// The factory must forward the EditorPreferences snapshot to
    /// MarkdownEditorConfiguration (= the 4 live settings; = if any
    /// disappears the host's settings silently stop reaching the
    /// engine). The reading width is not among them (= it is pinned
    /// to nil by its own gate below).
    @Test("WenshuEditorServicesFactory forwards the live EditorPreferences to config (= 4 binding lines)")
    func servicesFactoryForwardsEditorPreferences() throws {
        let factoryPath = resolve("Sources/WenshuApp/Features/Editor/Service/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        let code = codeOnly(factory)
        #expect(code.contains("config.heightBehavior = preferences.heightBehavior"),
                "Factory must bind config.heightBehavior from preferences.heightBehavior")
        #expect(code.contains("config.rawSourceMode = preferences.rawSourceMode"),
                "Factory must bind config.rawSourceMode from preferences.rawSourceMode")
        #expect(code.contains("config.spellChecking = SpellCheckingPolicy("),
                "Factory must build SpellCheckingPolicy from preferences")
        #expect(code.contains("config.lists = ListStyle("),
                "Factory must build ListStyle from preferences (= listHelpersEnabled + autoClosePairsEnabled)")
    }

    /// The reading width is NOT a forwarded preference: the
    /// 2026-10-14 decision pins `config.readingWidth = nil` (= the
    /// engine resolves the column width from the editor's own scroll
    /// view), so this gate asks for the pin and keeps the removed
    /// binding removed.
    @Test("WenshuEditorServicesFactory pins config.readingWidth to nil (= the 2026-10-14 decision)")
    func servicesFactoryPinsReadingWidthToNil() throws {
        let factoryPath = resolve("Sources/WenshuApp/Features/Editor/Service/WenshuEditorServicesFactory.swift")
        let factory = try String(contentsOfFile: factoryPath, encoding: .utf8)
        let code = codeOnly(factory)
        #expect(code.contains("config.readingWidth = nil"),
                "Factory must pin config.readingWidth to nil (= the engine resolves the column width itself)")
        #expect(!code.contains("config.readingWidth = preferences.readingWidth"),
                "Factory must NOT bind config.readingWidth from preferences (= the 2026-10-14 decision removed that binding)")
    }

    // MARK: - ed-smc-defaults T-13: scroll-memory persistence

    /// T-13 ships `EditorScrollMemory` (= the host-side persistence
    /// layer that wires the engine's 3 scroll-memory closures).
    /// Source-content gate: if anyone removes the struct or stops
    /// calling the persist/restore entry points the host silently
    /// loses scroll memory.
    @Test("EditorScrollMemory persists + restores scroll offsets (= T-13)")
    func editorScrollMemoryPersistsAndRestores() throws {
        let memoryPath = resolve("Sources/WenshuApp/Features/Editor/Store/EditorScrollMemory.swift")
        let memory = try String(contentsOfFile: memoryPath, encoding: .utf8)
        #expect(memory.contains("struct EditorScrollMemory"),
                "EditorScrollMemory struct must exist (= host-side scroll-memory persistence)")
        #expect(memory.contains("static func persist("),
                "EditorScrollMemory must declare a static persist(_:for:) entry point (= the engine calls onPersistScrollOffset)")
        #expect(memory.contains("static func restore("),
                "EditorScrollMemory must declare a static restore(for:) entry point (= the engine calls restoreScrollOffset)")
    }

    /// `WenshuMarkdownEditor` must wire the 3 engine scroll-memory
    /// closures (= retainedScrollDocumentIds + onPersistScrollOffset
    /// + restoreScrollOffset). Source-content gate: if any of the
    /// 3 wiring lines disappears, the host silently loses scroll
    /// memory on next session.
    @Test("WenshuMarkdownEditor wires the 3 scroll-memory closures (= T-13)")
    func wenshuMarkdownEditorWiresScrollMemory() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(editor.contains("retainedScrollDocumentIds:"),
                "WenshuMarkdownEditor must wire retainedScrollDocumentIds (= the engine's opt-in subset)")
        #expect(editor.contains("onPersistScrollOffset:"),
                "WenshuMarkdownEditor must wire onPersistScrollOffset (= the engine's persist callback)")
        #expect(editor.contains("restoreScrollOffset:"),
                "WenshuMarkdownEditor must wire restoreScrollOffset (= the engine's restore callback)")
        #expect(editor.contains("EditorScrollMemory.persist"),
                "WenshuMarkdownEditor's onPersistScrollOffset must call EditorScrollMemory.persist")
        #expect(editor.contains("EditorScrollMemory.restore"),
                "WenshuMarkdownEditor's restoreScrollOffset must call EditorScrollMemory.restore")
    }

    // MARK: - ed-smc-defaults T-03: editor status bar (= bottom chrome)

    /// T-03 ships `EditorStatusBarView` (= the bottom chrome band of
    /// the editor zone; = word count + autosave state). The band's
    /// height is not this view's own (= the shared `ChromeBottomFooter`
    /// shell owns it, = so the editor bar and the chat footer stay one
    /// canonical bottom chrome).
    @Test("EditorStatusBarView exists as the editor zone's bottom chrome (= T-03)")
    func editorStatusBarViewExists() throws {
        let barPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorStatusBarView.swift")
        let bar = try String(contentsOfFile: barPath, encoding: .utf8)
        let code = codeOnly(bar)
        #expect(code.contains("struct EditorStatusBarView"),
                "EditorStatusBarView must exist (= the bottom chrome band of the editor zone)")
        #expect(code.contains("ChromeBottomFooter("),
                "EditorStatusBarView must render through the shared ChromeBottomFooter shell (= one bottom-chrome component)")
        #expect(!code.contains(".frame(height:"),
                "EditorStatusBarView must NOT hardcode its own height (= the shared shell owns the band height)")
        #expect(!code.contains("cursorRectProvider"),
                "EditorStatusBarView must NOT take a cursorRectProvider (= the cursor-location chunk was removed on 2026-10-13)")
    }

    /// The bottom-chrome band's height lives in the shared component
    /// and its design token (= one height for every column bottom).
    @Test("The shared ChromeBottomFooter owns the bottom-chrome height (= T-03)")
    func sharedBottomChromeOwnsItsHeight() throws {
        let footerPath = resolve("Sources/WenshuApp/Features/Chrome/View/ChromeBottomFooter.swift")
        let footer = try String(contentsOfFile: footerPath, encoding: .utf8)
        #expect(codeOnly(footer).contains("DesignTokens.chromeBottomFooterHeight"),
                "ChromeBottomFooter must derive its content-row height from the shared design token")
        let tokensPath = resolve("Sources/WenshuApp/DesignTokens.swift")
        let tokens = try String(contentsOfFile: tokensPath, encoding: .utf8)
        #expect(tokens.contains("static let chromeBottomFooterHeight"),
                "DesignTokens must declare the chromeBottomFooterHeight token (= the one bottom-chrome height)")
    }

    /// The status bar mounts at the bottom edge of the editor zone
    /// (= the zone's `.safeAreaInset(edge: .bottom)`; = pinned, = it
    /// does NOT scroll with the text). The cursor-location chunk was
    /// dropped on 2026-10-13 (= a developer convention wenshu's
    /// readers do not use), so the `cursorRectProvider` closure is
    /// gone and this gate keeps it gone. The live caret rect still
    /// reaches the open tab (= the engine reports the rect through
    /// `onCaretRectChange`; = the tab stores it), so this gate asks
    /// for that shape instead of the removed closure spelling.
    @Test("EditorView mounts EditorStatusBarView at the zone's bottom edge (= T-03)")
    func editorViewMountsStatusBar() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorView.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        let code = codeOnly(editor)
        #expect(code.contains("EditorStatusBarView("),
                "EditorView must construct EditorStatusBarView (= the bottom chrome band mount)")
        #expect(code.contains(".safeAreaInset(edge: .bottom"),
                "EditorView must mount the status bar on the zone's bottom edge (= pinned, = it does not scroll with the text)")
        #expect(code.contains("textProvider: { self.draft }"),
                "EditorView must wire textProvider to the active tab's draft (= live word count source)")
        #expect(code.contains("self.appState.openTabs[idx].cursorRect = rect"),
                "EditorView must write the engine's caret rect into the open tab (= the rect reaches the tab)")
        #expect(!code.contains("cursorRectProvider"),
                "EditorView must NOT wire a cursorRectProvider (= the cursor-location chunk was removed on 2026-10-13)")
    }

    /// `WenshuMarkdownEditor` must forward the caret-rect callback to
    /// the engine. Source-content gate: if the forwarding line
    /// disappears the status bar silently loses the live cursor
    /// location (= falls back to the "Ln —, Col —" placeholder).
    @Test("WenshuMarkdownEditor forwards onCaretRectChange to engine (= T-03)")
    func wenshuMarkdownEditorForwardsCaretRectChange() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        #expect(editor.contains("onCaretRectChange: surface.onCaretRectChange"),
                "WenshuMarkdownEditor must forward onCaretRectChange to NativeTextViewWrapper")
    }

    /// `.fitsContent` needs an enclosing scroll view, and the desktop
    /// did not have one.
    ///
    /// The engine's own contract (its `HeightBehavior` docs): in
    /// `.fitsContent` the editor reports `headerHeight + content height`
    /// to SwiftUI, its own `ClampedScrollView` DISABLES its vertical
    /// scroller (`wantsVerticalScroller` returns false for
    /// `.fitsContent`), and its `scrollWheel` forwards the event to the
    /// responder chain (= "the enclosing (SwiftUI) scroll view receives
    /// the event"). So an enclosing scroller is not optional: without
    /// one the document cannot be scrolled at all AND its content
    /// height becomes the only height the editor column has (= the
    /// hosting view's `height >= content` demand reaches the
    /// NSSplitViewController's item wrapper; = the split grew past the
    /// window and the column's top chrome was drawn off the window's
    /// top edge).
    ///
    /// The gate is on the HOST, not on the engine: the enclosing scroll
    /// view has to wrap the engine's `NativeTextViewWrapper` in the
    /// wenshu-side host (= `WenshuMarkdownEditor`), because the engine
    /// itself cannot provide one.
    ///
    /// Two things are gated, because both were wrong at once:
    /// 1. `.fitsContent` MUST get the scroll view (= the contract above).
    /// 2. `.scrolls` MUST NOT (= the engine's own `NSScrollView` owns the
    ///    scroll there; = a second scroller would nest them and the
    ///    wheel events would be swallowed by the outer one).
    ///
    /// The gate asserts WHERE the scroll view sits, not that a phrase
    /// appears somewhere in the file. A substring check on the gate's
    /// own text cannot tell "the scroll view is inside the `.fitsContent`
    /// branch" from "the scroll view is on the `.scrolls` branch and the
    /// phrase is still in the file", = so the branch is SLICED and each
    /// slice is checked on its own. Measured against the real source:
    /// this fails when the scroll view is moved to the `.scrolls` branch,
    /// when it is removed, and when it is put on BOTH branches (= the
    /// nesting the card names).
    ///
    /// The canvas's own code is read for the same reason: the property
    /// "the canvas carries no scroll view" lives in
    /// `EditorPaperCanvas.swift`, = so asserting it about the HOST file
    /// would be true for every possible content of that file (= a check
    /// that cannot fail is not a check).
    @Test("WenshuMarkdownEditor gives .fitsContent an enclosing scroll view (= the engine's paging contract)")
    func wenshuMarkdownEditorGivesFitsContentAnEnclosingScrollView() throws {
        let editorPath = resolve("Sources/WenshuApp/Features/Editor/Model/WenshuMarkdownEditor.swift")
        let editor = try String(contentsOfFile: editorPath, encoding: .utf8)
        // Comments and strings are blanked (= not just the whole-line
        // ones), = so a DECOY that names the gate phrase in a trailing
        // comment, = in a block comment, = or in a string literal cannot
        // point the reader at the wrong branch, = and cannot satisfy the
        // assertions below either.
        let code = blankingCommentsAndStrings(codeOnly(editor))
        #expect(code.contains("ScrollView(.vertical)"),
                "WenshuMarkdownEditor must wrap the engine in a vertical ScrollView (= the engine's .fitsContent contract requires an enclosing scroller)")
        #expect(!code.contains("ScrollView([.horizontal, .vertical])"),
                "WenshuMarkdownEditor must NOT scroll horizontally (= the engine's own NSScrollView owns the horizontal axis; = a horizontal SwiftUI scroller is what produced the 30 PT sliver)")

        // The gate's LOCATION is the claim (= which branch carries the
        // scroll view), = so the branch is read STRUCTURALLY: the
        // condition is resolved to the height-mode check it names, = and
        // the two bodies are found by matching braces.
        let pair = heightModeBranchPair(in: code)
        #expect(pair != nil,
                "WenshuMarkdownEditor must branch on surface.configuration.heightBehavior (= .scrolls keeps the engine's own scroller; = nesting two scrollers would swallow the wheel events)")
        if let pair {
            #expect(pair.gated.contains("ScrollView(.vertical)"),
                    "the .fitsContent branch MUST carry the ScrollView (= the engine's paging contract needs the enclosing scroller)")
            #expect(!pair.other.contains("ScrollView"),
                    "the .scrolls branch MUST NOT carry a ScrollView (= two scrollers would nest and the wheel events would be swallowed by the outer one)")
        }

        // The canvas's own CODE (= its comment history still names a
        // ScrollView, = so the comments are stripped first), = because the
        // property this asserts lives there and not in the host file.
        let canvasPath = resolve("Sources/WenshuApp/Features/Editor/View/EditorPaperCanvas.swift")
        let canvasCode = blankingCommentsAndStrings(codeOnly(try String(contentsOfFile: canvasPath, encoding: .utf8)))
        #expect(!canvasCode.contains("ScrollView"),
                "EditorPaperCanvas must NOT carry a ScrollView (= the enclosing scroll view belongs on the engine host; = the canvas's ScrollView is what the v3 'text not rendered' regression came from)")
    }
}

private extension String {
    /// Whether a condition is a plain identifier (= `isFitsContent`),
    /// as opposed to an expression (= `a.b == c`).
    var isHeightModeIdentifier: Bool {
        !isEmpty && allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}


