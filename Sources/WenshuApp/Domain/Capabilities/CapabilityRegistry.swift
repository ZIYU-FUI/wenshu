// CapabilityRegistry.swift · Wenshu (文枢) · v0.34
//
// v0.34 boss 2026-09-02 OOB '其他工程上的机制我不太懂, 你看着定':
// Capability registry (= port of Card-master `src/bilibili-capabilities/
// registry.ts`).
//
// `Capability` protocol defines the contract (= id, display name,
// execute). `CapabilityRegistry` collects all capabilities at
// app launch (= open for extension: add new capability = 1 new
// file, no edits to existing files). Existing 4 monolithic
// capabilities (= ChatTrigger, SmartQueryParser, EntityIngestion,
// CrossRefInject) stay as-is in v0.34 (= refactoring them into
// individual capability files is a separate ticket; this commit
// only adds the registry scaffolding so future tickets can plug
// in).
//
// Apple-API-first check: Swift `protocol` + `actor` + `~Copyable`
// (= macOS 14+; = Apple canonical registry pattern). No
// third-party libs.

import Foundation

/// A single chat-side capability (= 1 file per capability per
/// the registry pattern; = open for extension without touching
/// existing files). Capabilities run in sequence during chat
/// processing (= trigger → parse → ingest → cross-ref inject).
///
/// v0.34: this is the protocol contract; future tickets wire
/// `ChatTrigger` / `SmartQueryParser` / `EntityIngestion` /
/// `CrossRefInject` to individual Capability implementations.
public protocol Capability: Sendable {
    /// Stable string id (= e.g. "chat-trigger", "wiki-smart-query").
    var id: String { get }
    /// Chinese display label (= boss 'UI 全中文' rule).
    var displayName: String { get }
    /// v0.34: empty default (= no-op capability). Future tickets
    /// override this to participate in chat processing.
    func execute(context: CapabilityContext) async throws -> CapabilityResult
}

// MARK: - v0.34: capability execution context (= shared state for the
// chat pipeline; = a thin wrapper that grows as more capabilities
// are added). v0.34 ships with minimal fields; future tickets
// extend it (= e.g. LLM context window, current entity stack).
public struct CapabilityContext: Sendable {
    public let sessionId: String
    public let userMessage: String
    public let currentModel: String
    public let timestamp: Date

    public init(
        sessionId: String,
        userMessage: String,
        currentModel: String,
        timestamp: Date = .now
    ) {
        self.sessionId = sessionId
        self.userMessage = userMessage
        self.currentModel = currentModel
        self.timestamp = timestamp
    }
}

/// v0.34: capability execution result (= 1+ entities the capability
/// wants to surface to the chat pipeline + the next stage).
public struct CapabilityResult: Sendable {
    public let capabilityID: String
    public let entities: [String]
    public let notes: [String]

    public init(capabilityID: String, entities: [String] = [], notes: [String] = []) {
        self.capabilityID = capabilityID
        self.entities = entities
        self.notes = notes
    }

    /// Empty result (= no-op capability = returns zero entities / notes).
    public static let empty = CapabilityResult(capabilityID: "noop")
}

/// v0.34: registry. Thread-safe (= actor) collection of
/// capabilities. App bootstrap registers each capability once
/// at launch (= see LibraryBootstrapper-equivalent in future
/// tickets); chat pipeline iterates `registry.all` in order.
public actor CapabilityRegistry {
    private var capabilities: [String: any Capability] = [:]

    public init() {}

    /// Register a capability. Idempotent (= registering the same
    /// id twice is a no-op; the first registration wins).
    public func register(_ capability: any Capability) {
        if capabilities[capability.id] == nil {
            capabilities[capability.id] = capability
        }
    }

    /// All registered capabilities, in registration order (= chat
    /// pipeline iterates this to run each in sequence).
    public var all: [any Capability] {
        Array(capabilities.values)
    }

    /// Look up by id. Returns nil if not registered.
    public func capability(for id: String) -> (any Capability)? {
        capabilities[id]
    }

    /// Number of registered capabilities (= for diagnostics + tests).
    public var count: Int {
        capabilities.count
    }
}

// MARK: - v0.34 default capabilities (= no-op stubs for now)

/// v0.34: no-op stub for the chat-trigger stage (= the real
/// implementation lives in `Domain/ChatTrigger.swift`; this stub
/// exists so the registry is loadable at app launch with zero
/// calls to the underlying services. Future ticket wires
/// `ChatTrigger.run(...)` to the registry's `execute` method.
public struct ChatTriggerCapability: Capability {
    public let id = "chat-trigger"
    public let displayName = "聊天触发"
    public init() {}
    public func execute(context: CapabilityContext) async throws -> CapabilityResult {
        .empty
    }
}

/// v0.34: no-op stub for the smart-query parse stage.
public struct SmartQueryCapability: Capability {
    public let id = "wiki-smart-query"
    public let displayName = "智能查询解析"
    public init() {}
    public func execute(context: CapabilityContext) async throws -> CapabilityResult {
        .empty
    }
}

/// v0.34: no-op stub for the LLM Wiki entity-ingestion stage.
public struct EntityIngestionCapability: Capability {
    public let id = "wiki-entity-ingestion"
    public let displayName = "实体入库"
    public init() {}
    public func execute(context: CapabilityContext) async throws -> CapabilityResult {
        .empty
    }
}

/// v0.34: no-op stub for the cross-reference inject stage.
public struct CrossRefInjectCapability: Capability {
    public let id = "wiki-cross-ref-inject"
    public let displayName = "交叉引用注入"
    public init() {}
    public func execute(context: CapabilityContext) async throws -> CapabilityResult {
        .empty
    }
}

/// v0.34: default registry (= registers the 4 chat-side
/// capabilities at app launch). Per Q34 single-subject rule, this
/// commit only ADDS the registry; it does NOT wire the existing
/// `ChatTrigger` / `SmartQueryParser` / `EntityIngestion` /
/// `CrossRefInject` to the registry (= those wirings are future
/// tickets = open-for-extension per the registry pattern).
public func makeDefaultCapabilityRegistry() -> CapabilityRegistry {
    let registry = CapabilityRegistry()
    // Synchronous registration via Task (= the actor's `register`
    // is async; we hop once at app launch).
    Task { @Sendable in
        await registry.register(ChatTriggerCapability())
        await registry.register(SmartQueryCapability())
        await registry.register(EntityIngestionCapability())
        await registry.register(CrossRefInjectCapability())
    }
    return registry
}