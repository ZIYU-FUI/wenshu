//
//  RequestHelpersToolsTests.swift · Wenshu · P5-AGENT-STREAMING-VISIBILITY
//
//  Verifies that the Anthropic and OpenAI request builders + streaming
//  wire-ups emit the `tools` array in the correct wire shape when
//  LLMCallOptions.tools is non-empty, and omit the key when empty.
//
//  Covers 6 assertions:
//    1. Anthropic non-streaming body includes top-level `tools[]` of
//       {name, description, input_schema} (= correct Anthropic shape).
//    2. Anthropic non-streaming body OMITS `tools` when LLMCallOptions
//       carries an empty array (= preserves prior wire parity).
//    3. OpenAI non-streaming body includes top-level `tools[]` of
//       {type:"function", function:{name, description, parameters}}
//       (= correct OpenAI shape).
//    4. OpenAI non-streaming body OMITS `tools` when empty.
//    5. AnthropicStreamingWireupFactory.buildRequest emits the same
//       Anthropic tools shape on the SSE path.
//    6. OpenAIStreamingWireupFactory.buildRequest emits the OpenAI
//       tools shape on the SSE path.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("RequestHelpers tools serialization (P5-AGENT-STREAMING-VISIBILITY)", .serialized)
struct RequestHelpersToolsTests {

    private static func makeSchema() -> ToolRegistrySchema {
        ToolRegistrySchema(
            name: "ReadFile",
            description: "Read a file from disk",
            inputSchema: [
                "path": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "absolute path"
                )
            ],
            required: ["path"]
        )
    }

    @Test("Anthropic non-streaming body emits tools[] when non-empty")
    func testAnthropicNonStreamingWithTools() throws {
        let messages = [LLMMessage.user("hello")]
        let data = try RequestHelpers.buildAnthropicRequest(
            model: "claude-sonnet-4-5",
            messages: messages,
            maxTokens: 1024,
            systemPrompt: "you are helpful",
            tools: [Self.makeSchema()]
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let tools = body?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?[0]["name"] as? String == "ReadFile")
        #expect(tools?[0]["description"] as? String == "Read a file from disk")
        let inputSchema = tools?[0]["input_schema"] as? [String: Any]
        #expect(inputSchema?["type"] as? String == "object")
        let properties = inputSchema?["properties"] as? [String: Any]
        let pathProp = properties?["path"] as? [String: Any]
        #expect(pathProp?["type"] as? String == "string")
        let required = inputSchema?["required"] as? [String]
        #expect(required == ["path"])
    }

    @Test("Anthropic non-streaming body omits tools key when empty")
    func testAnthropicNonStreamingOmitsEmptyTools() throws {
        let messages = [LLMMessage.user("hello")]
        let data = try RequestHelpers.buildAnthropicRequest(
            model: "claude-sonnet-4-5",
            messages: messages,
            maxTokens: 1024,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(body?["tools"] == nil, "empty tools array must omit the key for prior wire parity")
    }

    @Test("OpenAI non-streaming body emits tools[] when non-empty")
    func testOpenAINonStreamingWithTools() throws {
        let messages = [LLMMessage.user("hello")]
        let data = try RequestHelpers.buildOpenAIRequest(
            model: "gpt-5",
            messages: messages,
            maxTokens: 2048,
            systemPrompt: "you are helpful",
            tools: [Self.makeSchema()]
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let tools = body?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?[0]["type"] as? String == "function")
        let function = tools?[0]["function"] as? [String: Any]
        #expect(function?["name"] as? String == "ReadFile")
        let parameters = function?["parameters"] as? [String: Any]
        #expect(parameters?["type"] as? String == "object")
        let required = parameters?["required"] as? [String]
        #expect(required == ["path"])
    }

    @Test("OpenAI non-streaming body omits tools key when empty")
    func testOpenAINonStreamingOmitsEmptyTools() throws {
        let messages = [LLMMessage.user("hello")]
        let data = try RequestHelpers.buildOpenAIRequest(
            model: "gpt-5",
            messages: messages,
            maxTokens: 2048,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(body?["tools"] == nil)
    }

    private static func makeAnthropicCredentials() -> ConnectorCredentials {
        let provider = Provider(
            slug: "anthropic",
            name: "Anthropic",
            defaultBaseURL: "https://api.example.com",
            apiMode: "anthropic_messages",
            authHeader: .xApiKey,
            defaultModels: ["claude-sonnet-4-5"]
        )
        return ConnectorCredentials(
            provider: provider,
            apiKey: "sk-test",
            baseURL: "https://api.example.com"
        )
    }

    private static func makeOpenAICredentials() -> ConnectorCredentials {
        let provider = Provider(
            slug: "openai",
            name: "OpenAI",
            defaultBaseURL: "https://api.example.com",
            apiMode: "openai_chat",
            authHeader: .bearer,
            defaultModels: ["gpt-5"]
        )
        return ConnectorCredentials(
            provider: provider,
            apiKey: "sk-test",
            baseURL: "https://api.example.com"
        )
    }

    @Test("Anthropic streaming wire-up emits tools[] when non-empty")
    func testAnthropicStreamingWithTools() throws {
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: Self.makeAnthropicCredentials(),
            model: "claude-sonnet-4-5",
            maxTokens: 1024,
            systemPrompt: "you are helpful",
            messages: [LLMMessage.user("hi")],
            tools: [Self.makeSchema()]
        )
        let bodyData = try #require(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let tools = body?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?[0]["name"] as? String == "ReadFile")
        let inputSchema = tools?[0]["input_schema"] as? [String: Any]
        let required = inputSchema?["required"] as? [String]
        #expect(required == ["path"])
    }

    @Test("OpenAI streaming wire-up emits tools[] when non-empty")
    func testOpenAIStreamingWithTools() throws {
        let request = OpenAIStreamingWireupFactory.buildRequest(
            credentials: Self.makeOpenAICredentials(),
            model: "gpt-5",
            maxTokens: 2048,
            systemPrompt: "you are helpful",
            messages: [LLMMessage.user("hi")],
            bearerToken: "sk-test",
            tools: [Self.makeSchema()]
        )
        let bodyData = try #require(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let tools = body?["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?[0]["type"] as? String == "function")
        let function = tools?[0]["function"] as? [String: Any]
        #expect(function?["name"] as? String == "ReadFile")
        let parameters = function?["parameters"] as? [String: Any]
        let required = parameters?["required"] as? [String]
        #expect(required == ["path"])
    }
}