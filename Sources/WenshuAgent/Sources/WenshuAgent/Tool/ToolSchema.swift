// ToolSchema.swift
//
// The declaration half of the tool contract: the schema a tool
// publishes, and the metadata a registration carries. Split from
// ToolRegistry.swift so this description can cross a module boundary
// without dragging the registry and its bootstraps with it.
//
// A writing-tool package imports this to declare its own tools; the
// registry that consumes the declarations stays in the app target
// until its boot order can be inverted.

import Foundation

//
//  ToolRegistry.swift
//
//  1:1 Swift port of hermes `tools/registry.py` (= 766 LOC).
//
//  Source of truth:
//    /Volumes/ANAN/.hermes/tools/registry.py
//  Spec:
//    .scratch/2026-09-05-v0-40-toolregistry-port-spec.md
//
//  The hermes implementation = thread-safe singleton (`threading.RLock`).
//  Swift equivalent = `actor` (= compiler-enforced serialized mutation).
//
//  Surface (mirrors hermes):
//    - `ToolRegistrySchema` (= JSON-schema-style tool declaration;
//      renamed from the spec sketch `ToolSchema` because a file-internal
//      `MemoryProvider.ToolSchema` already exists; per the spec hard
//      rule "DO NOT remove any existing public surface", we keep the
//      existing one untouched and use a registry-scoped name here).
//    - `ToolRegistrySchemaProperty` (= single property in the schema).
//    - `ToolEntry` (= metadata for one registered tool; 10 fields).
//    - `ToolRegistry` (= `actor` singleton; `register` with override
//      protection, `getDefinitions` for LLM, `getHandler` for dispatch,
//      `generation` counter for cache invalidation, `clear` +
//      `deregister` for testing + MCP dynamic refresh).
//
//  Out of scope (per spec):
//    - AST-based auto-discovery (= hermes Python has this via stdlib
//      `ast`; Swift would need SwiftSyntax lib = new dep = deferred to
//      separate ticket).
//    - check_fn TTL cache + transient-failure suppression (= hermes-
//      specific Python detail; Swift actor model does not need it).
//    - Migration of existing 12 wenshu tool registrations to
//      `ToolRegistry.shared.register(...)` (= separate ticket
//      MIGRATE-TOOLREGISTRY-002).
//
//  Hard rules (per spec):
//    - English-only in all files.
//    - No new third-party dependency.
//    - No removal of existing `Tool` protocol public surface.
//    - Additive only.
//

import Foundation

// MARK: - ToolRegistrySchema

/// JSON-schema-style declaration of one tool (= hermes `ToolEntry.schema`).
///
/// Mirrors the OpenAI `function` tool shape: name + description +
/// input properties + required-field list. `inputSchema` keys = property
/// names, values = `ToolRegistrySchemaProperty`.
public struct ToolRegistrySchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: [String: ToolRegistrySchemaProperty]
    public let required: [String]

    public init(
        name: String,
        description: String,
        inputSchema: [String: ToolRegistrySchemaProperty] = [:],
        required: [String] = []
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.required = required
    }

    /// Render to a JSON-compatible dictionary (= hermes
    /// `schema_with_name` in `get_definitions`).
    public func toJSON() -> [String: Any] {
        var props: [String: Any] = [:]
        for (key, prop) in inputSchema {
            props[key] = prop.toJSON()
        }
        var json: [String: Any] = [
            "name": name,
            "description": description
        ]
        if !props.isEmpty {
            json["parameters"] = [
                "type": "object",
                "properties": props,
                "required": required
            ]
        }
        return json
    }
}

// MARK: - ToolRegistrySchemaProperty

/// Single property in a `ToolRegistrySchema.inputSchema` (= hermes
/// property objects inside the `properties` map).
///
/// `type` = "string" | "number" | "boolean" | "array" | "object".
/// `enumValues` populated only when the value is a closed enum
/// (= hermes uses `enum` arrays in JSON Schema).
public struct ToolRegistrySchemaProperty: Sendable, Codable, Equatable {
    public let type: String
    public let description: String
    public let enumValues: [String]?

    public enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }

    public init(
        type: String,
        description: String,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    /// Render to a JSON-compatible dictionary.
    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "type": type,
            "description": description
        ]
        if let enumValues {
            json["enum"] = enumValues
        }
        return json
    }
}

// MARK: - ToolEntry

/// Metadata for a single registered tool (= hermes `ToolEntry`).
///
/// 10 fields, mirroring hermes 1:1 minus `handler` (= replaced by
/// `handlerID` — a stable identifier for the handler slot; wenshu
/// tools are mostly `struct`-based so we wrap them in a class-bound
/// `HandlerBox` to give `ObjectIdentifier` a stable key) and minus
/// `dynamic_schema_overrides` (= Python-specific dynamic re-binding;
/// Swift actor model makes this simpler: re-register with the new
/// schema if config changes).
public struct ToolEntry: Sendable {
    public let name: String
    public let toolset: String
    public let schema: ToolRegistrySchema
    /// Stable identifier for the handler slot (= `ObjectIdentifier` of
    /// the internal `HandlerBox` holding the `any Tool` instance). Use
    /// `registry.getHandler(name:)` to retrieve the live handler.
    public let handlerID: ObjectIdentifier
    /// Optional availability check (= hermes `check_fn`). When
    /// `nil`, the tool is always available. When set, called
    /// synchronously at `getDefinitions` time.
    public let checkFn: (@Sendable () -> Bool)?
    public let requiresEnv: [String]
    public let isAsync: Bool
    public let description: String
    public let emoji: String
    public let maxResultSizeChars: Int?

    public init(
        name: String,
        toolset: String,
        schema: ToolRegistrySchema,
        handlerID: ObjectIdentifier,
        checkFn: (@Sendable () -> Bool)? = nil,
        requiresEnv: [String] = [],
        isAsync: Bool = true,
        description: String,
        emoji: String,
        maxResultSizeChars: Int? = nil
    ) {
        self.name = name
        self.toolset = toolset
        self.schema = schema
        self.handlerID = handlerID
        self.checkFn = checkFn
        self.requiresEnv = requiresEnv
        self.isAsync = isAsync
        self.description = description
        self.emoji = emoji
        self.maxResultSizeChars = maxResultSizeChars
    }

    /// Manual `Equatable` (= closure field `checkFn` cannot be auto-
    /// synthesized). Excludes `checkFn` from comparison (= hermes
    /// treats two entries with the same metadata as equal regardless
    /// of the check callable identity).
    public static func == (lhs: ToolEntry, rhs: ToolEntry) -> Bool {
        lhs.name == rhs.name
            && lhs.toolset == rhs.toolset
            && lhs.schema == rhs.schema
            && lhs.handlerID == rhs.handlerID
            && lhs.requiresEnv == rhs.requiresEnv
            && lhs.isAsync == rhs.isAsync
            && lhs.description == rhs.description
            && lhs.emoji == rhs.emoji
            && lhs.maxResultSizeChars == rhs.maxResultSizeChars
    }
}
