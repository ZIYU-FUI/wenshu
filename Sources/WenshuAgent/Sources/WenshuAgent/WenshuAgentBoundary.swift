//
//  WenshuAgentBoundary.swift · Wenshu · v3.1 governance ticket: extract WenshuAgent
//
//  Boundary marker file for the `WenshuAgent` subsystem.
//
//  Layout (post-2026-10-16 refactor):
//
//      Sources/WenshuApp/WenshuAgent/
//      ├── WenshuAgentBoundary.swift   (this file = intent + access policy)
//      ├── API.md                       (P2 design — public API reference)
//      ├── AUDIT.md                     (P1 audit — file inventory + refactor scope)
//      ├── Public/                      (intended surface for UI / App callers)
//      │   ├── WABaseProvider.swift
//      │   ├── LLMMessage.swift
//      │   ├── LLMResponse.swift
//      │   └── WALogger.swift
//      ├── Logging/                     (WALogger + categories)
//      ├── Streaming/                   (SSE + diagnostic + watchdog + fence)
//      ├── Connector/                   (8 provider connectors + registry + built-ins)
//      ├── Keychain/                    (provider keychain + mirrored store)
//      ├── Discovery/                   (model discovery + wire format helpers)
//      ├── Context/                     (context compression + prompt caching)
//      ├── Agent/                       (WenshuConductor + chat + import router)
//      └── App/                         (WenshuAppDelegateLLM bridge)
//
//  ACCESS POLICY (2026-10-16):
//
//  WenshuApp is a single SPM target. = the public / internal distinction
//  between files in the same target is purely organizational. The Swift
//  `public` keyword has no effect on visibility inside the WenshuApp
//  executable target (= it is the default `internal` access that matters).
//
//  The boundary is enforced by:
//    1. Folder location (= `WenshuAgent/Public/` is the documented surface;
//       `WenshuAgent/<other>/` is internal by convention).
//    2. `WenshuAgent.shared` (forthcoming) = the only public entry point
//       that chat / settings / import layers are expected to use.
//    3. This file (= the intent marker; = if you are reading it you are
//       inside the boundary, = if you want to call into WenshuAgent from
//       outside, = start with `WenshuAgent/Public/`).
//
//  RATIONALE (hermes style):
//  Wenshu already extracted WenshuData (= a separate SPM target via
//  ADR-0016). = the data layer is genuinely a separate package (= it
//  hosts @Model + SwiftData + cross-platform concerns). WenshuAgent
//  does NOT need that level of separation (= it is wenshu-internal; =
//  MCP / plugin support is a future ticket, not a present concern).
//  = a folder boundary (= this file) is sufficient for now.
//
