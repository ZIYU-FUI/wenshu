//
//  ImportReferenceLibraryRouter.swift · wenshu
//
//  The reference library branch of the markdown import.
//
//  A book import splits one source into several documents under a
//  template. A reference library import produces ONE document, and the
//  work is enrichment rather than splitting: the title, the summary,
//  the tags, the library category, the entity type and the body all
//  come out of the source, and the body is checked against what the
//  outside world says.
//
//  So this branch is one model call that produces all of those fields at
//  once, with the web search tool advertised so the model can check the
//  content before it writes it. The library category and the entity type
//  are resolved through the shared classifier, so the keyword pass and
//  the library's own fallback rules apply; = an unrecognised value
//  falls back to the catch-all category and the catch-all entity type,
//  exactly as the reference storage layer already tolerates.
//

import Foundation
import WenshuAgent

/// The reference library branch of the import.
struct ImportReferenceLibraryRouter: Sendable {

    /// The connector the model is reached through.
    let connector: any LLMConnector

    /// The model the call goes out on (= the user's picked model).
    let modelSlug: String

    /// Run the web search tool (= the model's tool call reaches the
    /// registry's own tool).
    let dispatchWebSearch: @Sendable (String) async -> String

    /// Produce one finished entity for one source file.
    ///
    /// - Returns: the routing result the orchestrator writes from
    ///   (= the title, the summary, the tags, the category, the entity
    ///   type and the body).
    func route(
        input: ImportFileInput,
        body: String,
        fallbackTitle: String
    ) async throws -> ImportRoutingResult {
        // One call. The prompt asks for the whole entity, and the search
        // tool is advertised so the model can check the content against
        // the web before it answers.
        let reply = try await runToolUseLoop(
            prompt: Self.prompt(
                filePath: input.filePath,
                body: body
            )
        )
        // The model's category is the authority. The classifier only
        // fills in when the model gave none, so the two can never
        // disagree.
        let parsed = Self.parseReply(reply)
        let title = parsed.title.isEmpty ? fallbackTitle : parsed.title
        var category = parsed.categoryLetter.flatMap { EntityCategory(rawValue: $0) }
        var entityType = parsed.entityTypeNumber.map { EntityType.fromPromptNumber($0) }
        var tags = parsed.tags
        if category == nil || entityType == nil || tags.isEmpty {
            // The model left something out: = the classifier fills it in.
            // Its model callback takes a plain string and returns a plain
            // string, so the reply the model already produced is handed
            // back to it: = the model is asked once.
            let classification = await EntityClassifier().classify(
                title: title,
                summary: parsed.summary,
                body: parsed.body.isEmpty ? body : parsed.body,
                useLLMFallback: true,
                llmCallback: { _ in reply }
            )
            if category == nil { category = classification.category }
            if entityType == nil { entityType = classification.entityType }
            if tags.isEmpty { tags = classification.tags }
        }
        // The library's tag rule: = the title is not a tag, = one to
        // three tags, = never none. The model's own tags go through
        // the same rule (= the model may answer four, = or repeat the
        // title, = or answer none).
        tags = ImportTagPolicy.tags(
            tags,
            title: title,
            fallback: category.map { [$0.displayName] } ?? []
        )
        return ImportRoutingResult(
            destination: .referenceLibrary,
            title: title,
            summary: parsed.summary,
            tags: Set(tags),
            entityType: (entityType ?? .other).rawValue,
            category: category?.rawValue,
            confidence: 1.0,
            rewrittenBody: parsed.body.isEmpty ? nil : parsed.body,
            extraFiles: [],
        )
    }

    // MARK: - The prompt

    /// The request the model answers.
    ///
    /// The model produces the whole entity in one reply: the title, the
    /// summary, the tags, the library category, the entity type and the
    /// body. The search tool is advertised beside it, so the model can
    /// check the content before it writes the body.
    static func prompt(filePath: String, body: String) -> String {
        // The second-level codes are offered as the precise answers, so
        // the model can place the entity more precisely. The stored
        // result stays at the top-level category: = the second-level code
        // is not stored.
        let categories = EntityCategory.allCases
            .map { category in
                let codes = category.subcategories
                    .map { "\($0.code) = \($0.displayName)" }
                    .joined(separator: ", ")
                return codes.isEmpty
                    ? "\(category.rawValue) = \(category.displayName)"
                    : "\(category.rawValue) = \(category.displayName) (= \(codes))"
            }
            .joined(separator: "\n")
        let types = EntityType.allCases
            .map { "\($0.promptNumber) = \($0.displayName): \($0.description)" }
            .joined(separator: "\n")
        return """
        You are the wenshu librarian. Turn the source file into one finished
        library entity.

        ## Source file

        - Path: \(filePath)
        - Content:

        \(body)

        ## The twenty-two library categories (= the `category` value)

        \(categories)

        ## The nine entity types (= the `entity_type` value)

        \(types)

        ## What to do

        1. Use the `web_search` tool to check the content against what the
           outside world says. Search for the subject of the source, read
           what comes back, and correct anything the source gets wrong.
        2. Write the entity's body in your own words, using what the
           source says and what the search confirmed. Never invent facts:
           when the source does not answer something, say so.
        3. Answer with one JSON object and nothing else.

        ## The answer

        ```json
        {
          "title": "<the entity's title>",
          "summary": "<one line, at most 100 characters>",
          "tags": ["<tag1>", "<tag2>"],
          "category": "<one letter from the list above>",
          "entity_type": <one number from the list above>,
          "body": "<the entity's body, in markdown>"
        }
        ```

        - `category` must be one of the twenty-two letters; = when you
          cannot tell, use "Z". The second-level codes beside each letter
          are there to place the entity precisely; = answer with the
          letter, not with the code.
        - `entity_type` must be one of the nine numbers; = when you cannot
          tell, use 9.
        - `tags` is an array of at most 3 short tags.
        """
    }

    // MARK: - The reply

    /// The fields the model answered with.
    struct Reply: Sendable, Equatable {
        var title: String = ""
        var summary: String = ""
        var tags: [String] = []
        var categoryLetter: String?
        var entityTypeNumber: Int?
        var body: String = ""
    }

    /// Read the model's answer.
    static func parseReply(_ raw: String) -> Reply {
        guard let json = WCIRHelpers.extractFirstJSONObject(raw),
              let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return Reply()
        }
        let tags = (parsed["tags"] as? [String]) ?? []
        return Reply(
            title: ((parsed["title"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            summary: ((parsed["summary"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            tags: Array(tags.prefix(3)),
            categoryLetter: (parsed["category"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
            entityTypeNumber: (parsed["entity_type"] as? Int)
                ?? (parsed["entityType"] as? Int),
            body: (parsed["body"] as? String) ?? ""
        )
    }

    // MARK: - The tool-use loop

    /// Run the call, and let the model use the search tool.
    ///
    /// The model's tool call is answered by the search tool, and the
    /// result goes back into the conversation, so the model can correct
    /// the body against it.
    private func runToolUseLoop(prompt: String) async throws -> String {
        var messages: [LLMMessage] = [.user(prompt)]
        let options = LLMCallOptions(
            model: modelSlug,
            maxTokens: 4096,
            systemPrompt: nil,
            temperature: 0.2,
            reasoningEffort: nil,
            tools: WCIRToolSchema.webSearchToolSchema
        )
        let maxTurns = 5
        for _ in 0..<maxTurns {
            let response = try await send(messages: messages, options: options)
            switch response.stopReason {
            case .endTurn, .maxTokens, .stopSequence, .unknown:
                return response.blocks.map(\.textValue).joined()
            case .toolUse:
                break
            }
            var toolUses: [(id: String, name: String, input: String)] = []
            for block in response.blocks {
                if case .toolUse(let id, let name, let input) = block {
                    toolUses.append((id, name, input))
                }
            }
            if toolUses.isEmpty {
                return response.blocks.map(\.textValue).joined()
            }
            messages.append(LLMMessage(role: .assistant, blocks: response.blocks))
            for tool in toolUses {
                let output: String
                if tool.name == "web_search" {
                    output = Self.compactedSearchOutput(
                        await dispatchWebSearch(tool.input)
                    )
                } else {
                    output = "{\"ok\":false,\"error\":\"unknown tool: \(tool.name)\"}"
                }
                messages.append(.toolResult(toolUseID: tool.id, output: output))
            }
        }
        let response = try await send(messages: messages, options: options)
        return response.blocks.map(\.textValue).joined()
    }

    /// The search result the model reads back.
    ///
    /// The raw envelope carries every hit with its full snippet, and the
    /// web is not a place wenshu controls (= a snippet can say anything,
    /// = and a long one is a long way for a provider's input filter to
    /// trip over). The model needs enough to check the content against,
    /// so the result is trimmed: = the first few entries, = each snippet
    /// short, = the rest of the envelope as it was.
    static func compactedSearchOutput(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = object["results"] as? [[String: Any]],
              results.count > 2
        else { return raw }
        let kept = results.prefix(5).map { entry -> [String: Any] in
            var copy = entry
            if let snippet = entry["snippet"] as? String, snippet.count > 200 {
                copy["snippet"] = String(snippet.prefix(200))
            }
            return copy
        }
        var compacted = object
        compacted["results"] = kept
        compacted["count"] = kept.count
        guard let out = try? JSONSerialization.data(withJSONObject: compacted),
              let text = String(data: out, encoding: .utf8)
        else { return raw }
        return text
    }

    /// Send the request, and send it again when the provider refuses it.
    ///
    /// A provider with an input filter (= the ones that serve the China
    /// region) rejects some requests on a borderline input, = and the
    /// same request goes through the next time. The request is idempotent
    /// (= a refused request wrote nothing), = so the retry is safe.
    private func send(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) async throws -> LLMResponse {
        var attempt = 0
        while true {
            do {
                return try await connector.send(messages: messages, options: options)
            } catch {
                attempt += 1
                guard attempt < 2 else { throw error }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
        }
    }
}
