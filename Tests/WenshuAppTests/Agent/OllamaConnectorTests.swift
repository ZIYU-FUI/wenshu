//
//  OllamaConnectorTests.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  Unit tests for OllamaConnector (= §11.2 Ollama profile).
//
//  Ollama is a LOCAL model server (= http://localhost:11434/v1 by default)
//  with no API key required per AGENTS.md §11.2. Tests cover:
//    1. connectorID identity (= "ollama")
//    2. Protocol conformance + Provider slug match (= delegates to
//       OpenAICompatibleConnector(provider: .ollama))
//    3. ConnectorCredentials.resolve(for: .ollama) yields empty apiKey
//       (= no-auth local server contract per §11.2 P1 row "Ollama | None (local)")
//
//  HTTP transport tests for Ollama (= empty Bearer + localhost:11434 host +
//  /chat/completions path) are covered in OpenAIConnectorTests.swift
//  (`testOllamaNoAuth` + `testOllamaMissingKeyNoThrow`). The §11.2
//  gap-fill tests focus on the *profile identity* (= slug + protocol
//  conformance + no-auth credential contract).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OllamaConnector (§11.2 gap-fill)")
struct OllamaConnectorTests {

    @Test("OllamaConnector.connectorID == 'ollama' (per AGENTS.md §11.2 profile slug)")
    func testConnectorIDIdentity() async throws {
        let connector = OllamaConnector()
        #expect(connector.connectorID == "ollama")
    }

    @Test("OllamaConnector conforms to LLMConnector protocol")
    func testProtocolConformance() async throws {
        let connector: any LLMConnector = OllamaConnector()
        #expect(connector.connectorID == "ollama")
    }

    @Test("OllamaConnector: no-auth contract via ConnectorCredentials.resolve")
    func testNoAuthCredentialContract() async throws {
        // Per AGENTS.md §11.2 P1 row "Ollama | None (local)", Ollama has
        // no API key. ConnectorCredentials.resolve must yield empty
        // apiKey without hitting the Keychain (= local server contract).
        let credentials = ConnectorCredentials.resolve(for: .ollama)
        #expect(credentials.apiKey.isEmpty)
        #expect(credentials.provider.slug == "ollama")
        #expect(credentials.provider.defaultBaseURL == "http://localhost:11434/v1")
        #expect(credentials.isReady == true)
    }
}
