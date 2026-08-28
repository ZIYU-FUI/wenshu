// ProviderProfileExtTests.swift · Wenshu · v0.28
//
// Hermes-port validation tests for ProviderProfileExt + ModelMetadata
// (= wenshu M6 ticket 16 = hermes-port batch 3 sixth ticket).
//
// Tests cover:
// - ProviderCatalog.profileExt lookup (= v1 minimax cn entry present)
// - ProviderProfileExt defaults (= ProviderCatalog.profileExts)
// - ProviderProfileExt.UserAgentStrategy enum cases
// - ProviderProfileExt.RequestQuirk enum cases
// - ModelMetadata lookup by id
// - ModelMetadata Capability + Modality enums

import Foundation
import Testing
@testable import WenshuApp

@Suite("ProviderProfileExt (hermes verbatim port — M6 ticket 16)")
struct ProviderProfileExtTests {

    // MARK: - Catalog lookup

    @Test("ProviderCatalog.profileExt returns entry for minimax-cn")
    func catalogHasMinimaxCn() {
        let ext = ProviderCatalog.profileExt(for: "minimax-cn")
        #expect(ext != nil)
        #expect(ext?.displayName == "minimax cn")
        #expect(ext?.aliases.contains("minimax") == true)
    }

    @Test("ProviderCatalog.profileExt returns nil for unknown slug")
    func catalogReturnsNilForUnknown() {
        let ext = ProviderCatalog.profileExt(for: "unknown-provider")
        #expect(ext == nil)
    }

    @Test("ProviderCatalog.profileExts has exactly 1 entry (v1 minimax cn only)")
    func catalogSize() {
        #expect(ProviderCatalog.profileExts.count == 1)
        #expect(ProviderCatalog.profileExts.keys.contains("minimax-cn"))
    }

    @Test("minimax-cn entry uses Anthropic-compatible quirks")
    func minimaxCnUsesAnthropicQuirks() {
        let ext = ProviderCatalog.profileExt(for: "minimax-cn")!
        #expect(ext.userAgentStrategy == .customBrowserUA)
        #expect(ext.requestQuirks.contains(.useAnthropicVersionHeader))
    }

    // MARK: - Enum cases

    @Test("UserAgentStrategy has 3 cases (= default/customBrowserUA/omit)")
    func userAgentStrategyCases() {
        let cases = ProviderProfileExt.UserAgentStrategy.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.default))
        #expect(cases.contains(.customBrowserUA))
        #expect(cases.contains(.omit))
    }

    @Test("RequestQuirk has 4 cases")
    func requestQuirkCases() {
        let cases = ProviderProfileExt.RequestQuirk.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.omitTemperature))
        #expect(cases.contains(.omitStopSequences))
        #expect(cases.contains(.dropEmptyMessages))
        #expect(cases.contains(.useAnthropicVersionHeader))
    }

    // MARK: - Empty default

    @Test("ProviderProfileExt.empty is the no-quirks default")
    func emptyDefault() {
        let ext = ProviderProfileExt.empty
        #expect(ext.aliases.isEmpty)
        #expect(ext.displayName.isEmpty)
        #expect(ext.description.isEmpty)
        #expect(ext.signupURL.isEmpty)
        #expect(ext.userAgentStrategy == .default)
        #expect(ext.requestQuirks.isEmpty)
    }

    // MARK: - Provider extension accessor

    @Test("Provider.profileExt returns catalog entry or .empty fallback")
    func providerExtAccessor() {
        let minimax = Provider.minimaxCn
        let ext = minimax.profileExt
        #expect(ext.displayName == "minimax cn")

        let openrouter = Provider.openrouter
        let unknown = openrouter.profileExt
        #expect(unknown.displayName.isEmpty)
        #expect(unknown.userAgentStrategy == .default)
    }

    // MARK: - ModelMetadata

    @Test("ModelMetadata.catalog has 2 entries (M3 + Text-01)")
    func modelMetadataCatalogSize() {
        #expect(ModelMetadata.catalog.count == 2)
    }

    @Test("ModelMetadata lookup by id")
    func modelMetadataLookup() {
        let m3 = ModelMetadata.metadata(forModelID: "MiniMax-M3")
        #expect(m3 != nil)
        #expect(m3?.providerSlug == "minimax-cn")
        #expect(m3?.contextWindow == 128_000)

        let unknown = ModelMetadata.metadata(forModelID: "unknown-model")
        #expect(unknown == nil)
    }

    @Test("ModelMetadata Capability + Modality enums cover expected cases")
    func capabilityModalityCases() {
        #expect(ModelMetadata.Capability.allCases.count >= 6)
        #expect(ModelMetadata.Capability.allCases.contains(.chat))
        #expect(ModelMetadata.Capability.allCases.contains(.streaming))
        #expect(ModelMetadata.Capability.allCases.contains(.tools))
        #expect(ModelMetadata.Modality.allCases.count >= 6)
        #expect(ModelMetadata.Modality.allCases.contains(.textInput))
        #expect(ModelMetadata.Modality.allCases.contains(.textOutput))
    }
}