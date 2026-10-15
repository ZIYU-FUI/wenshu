//
//  ReferenceLibraryMarkdownEngineConformanceTests.swift · Wenshu · v2.9d ticket T36 (boss 2026-09-28 OOB A6)
//
//  Structural tests confirming the v2.9d ReferenceLibraryImageProvider
//  + ReferenceLibraryWikiLinkResolver conform to the markdown-engine
//  protocols (= boss 2026-09-28 OOB inventory A6 = 'ReferenceLibraryImageProvider
//  / ReferenceLibraryWikiLinkResolver 接 markdown-engine'; = the
//  canonical wenshu pattern = use the markdown-engine provider
//  protocols so the editor renders [[wikilinks]] + ![[embeds]] with
//  one source of truth).
//
//  Three source-level tests pin the canonical shape:
//
//    1. testImageProviderConformsToEmbeddedImageProvider —
//       ReferenceLibraryImageProvider: EmbeddedImageProvider
//       (= the markdown-engine protocol conformance).
//
//    2. testWikiLinkResolverConformsToWikiLinkResolver —
//       ReferenceLibraryWikiLinkResolver: WikiLinkResolver
//       (= the markdown-engine protocol conformance).
//
//    3. testProvidersUsedByEditorServicesFactory —
//       WenshuEditorServicesFactory wires both providers
//       (= the canonical production consumer path per
//       AGENTS.md §11.1 batch 2 issue 05 markdown-engine
//       adoption).
//
//  Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112:
//  source-level tests following the v2.8d LLMWikiPipelineWireTests
//  pattern.

import Testing
import Foundation
@testable import WenshuApp

@Suite("ReferenceLibrary markdown-engine conformance (v2.9d — boss 2026-09-28 OOB A6)")
struct ReferenceLibraryMarkdownEngineConformanceTests {

    private func resolve(_ relative: String) -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent(relative)
        return url.path
    }

    @Test("ReferenceLibraryImageProvider conforms to markdown-engine EmbeddedImageProvider")
    func testImageProviderConformsToEmbeddedImageProvider() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Editor/ReferenceLibraryImageProvider.swift"), encoding: .utf8)
        #expect(source.contains(": EmbeddedImageProvider"),
                "ReferenceLibraryImageProvider must conform to EmbeddedImageProvider (= the markdown-engine protocol)")
    }

    @Test("ReferenceLibraryWikiLinkResolver conforms to markdown-engine WikiLinkResolver")
    func testWikiLinkResolverConformsToWikiLinkResolver() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Editor/ReferenceLibraryWikiLinkResolver.swift"), encoding: .utf8)
        #expect(source.contains(": WikiLinkResolver"),
                "ReferenceLibraryWikiLinkResolver must conform to WikiLinkResolver (= the markdown-engine protocol)")
    }

    @Test("WenshuEditorServicesFactory wires both providers (= the canonical production consumer)")
    func testProvidersUsedByEditorServicesFactory() throws {
        let source = try String(contentsOfFile: resolve("Sources/WenshuApp/Editor/WenshuEditorServicesFactory.swift"), encoding: .utf8)
        let wiresWikiLinks = source.contains("ReferenceLibraryWikiLinkResolver(")
        let wiresImages = source.contains("ReferenceLibraryImageProvider(")
        #expect(wiresWikiLinks && wiresImages,
                "WenshuEditorServicesFactory must wire both providers (= the canonical production consumer path)")
    }
}