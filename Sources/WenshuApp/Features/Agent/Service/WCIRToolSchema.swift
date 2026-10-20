//
//  WCIRToolSchema.swift
//
//  webSearchToolSchema extracted from
//  WenshuConductorImportRouterHelpers.swift
//  (= §6.6 god-class split + discoverability: the 32-LOC
//  webSearchToolSchema static let moved out of the WCIRHelpers
//  namespace into this dedicated `enum WCIRToolSchema`).
//
//  Why extracted (= §6.6 god-class split + discoverability): the
//  WCIRHelpers namespace is 1182 LOC = 1.97x the 600-LOC cap. The
//  webSearchToolSchema is a single concern (= "register the web
//  search tool schema for the LLM to call"). Putting it in a
//  dedicated file named after the concern (= WCIRToolSchema.swift)
//  lets the next reader find the tool schema by name.
//
//  This is a static let (= no instance state; = safe to access from
//  any context).
//

import Foundation
import WenshuAgent

/// Namespace container for the tool schema registry. Wrapped in an
/// enum (= same pattern as A56's `enum ImportServiceDedup` and
/// A62's `enum ImportServiceCache`).
enum WCIRToolSchema {
        // MARK: - webSearchToolSchema

    static let webSearchToolSchema: [ToolRegistrySchema] = [
        ToolRegistrySchema(
            name: "web_search",
            description: """
            Web search via the keyless anonymous public free tier ring \
            (Parallel / Exa / Keenable, in that order). No API key \
            or configuration is needed; works on first launch. \
            Use this tool to find the canonical content for the entity \
            the user is importing (= search the entity name; = return \
            the top results with title / url / snippet; = the LLM \
            then incorporates the search results into the rewritten \
            body).
            """,
            inputSchema: [
                "action": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "The web_search operation to perform.",
                    enumValues: ["search", "research"]
                ),
                "query": ToolRegistrySchemaProperty(
                    type: "string",
                    description: "Search query string (= required)."
                ),
                "limit": ToolRegistrySchemaProperty(
                    type: "integer",
                    description: "Maximum number of results to return."
                )
            ],
            required: ["action", "query"]
        )
    ]


}
