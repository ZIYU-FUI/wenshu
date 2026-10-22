//
//  WenshuAgentBoundary.swift · Wenshu · agent runtime boundary marker
//
//  Boundary marker file for the `WenshuAgent` subsystem.
//
//  LAYOUT:
//
//  The agent runtime is its own SwiftPM package at `Sources/WenshuAgent/`.
//  The target sources live under `Sources/WenshuAgent/Sources/WenshuAgent/`.
//  The package owns its own manifest and its own test target.
//  The app package depends on the runtime product, so the compiler
//  enforces that edge.
//
//      Sources/WenshuAgent/Sources/WenshuAgent/
//      ├── WenshuAgentBoundary.swift   (this file = intent + access policy)
//      ├── Agent/                      (the runtime: conductor +
//      │                               conversation loop + verifier +
//      │                               chat provider seam + LLM block
//      │                               / usage / response types)
//      ├── Connector/                  (provider connectors + registry)
//      ├── Context/                    (context engine + compression)
//      ├── Discovery/                  (model discovery + credentials)
//      ├── Keychain/                   (provider keychain + mirrored store)
//      ├── Logging/                    (WALogger + categories)
//      ├── Memory/                     (memory manager + write gate)
//      ├── Prompt/                     (system prompt + prompt assembly)
//      ├── Public/                     (public surface for outside callers)
//      ├── Recovery/                   (error classification + response guards)
//      ├── Settings/                   (agent settings)
//      ├── Streaming/                  (SSE + chunk converters + watchdog + fence)
//      ├── Tool/                       (tool mechanism = contract + registry
//      │                               + executor + path guard + schema
//      │                               + exposure)
//      └── Turn/                       (turn context + finalizer + notes)
//
//  The agent runtime itself lives here now: the conductor, the
//  conversation loop and the verifier all moved into the package.
//  The app keeps one file under `Sources/WenshuApp/WenshuAgent/`: the
//  app's own public facade (= `WenshuAgent.shared`). It stays there
//  because the app calls it by that name, and the name collides with
//  the package module on purpose.
//
//      Sources/WenshuApp/WenshuAgent/
//      └── Public/
//          └── WenshuAgent.swift
//
//  Everything else the app owns lives in the app's own tree: the import
//  router and its helpers in `Features/Agent/Service/`, the app
//  delegate's LLM helper in `App/`, the keychain selector in
//  `Features/Settings/Service/`, and the tool implementations in
//  `Features/Agent/Service/`. The tools bind the app's storage, and
//  they satisfy the runtime's `Tool` protocol.
//
//  TOOL MECHANISM:
//
//  The `Tool/` subfolder holds the tool mechanism: the `Tool` protocol
//  every tool satisfies, the registry that holds the instances, the
//  executor that dispatches them, and the path guard that keeps a tool
//  inside the user's library.
//
//  The runtime owns the mechanism. The app owns the tools. The app's
//  tool implementations stay in the app target (= they bind the app's
//  storage), and they reach the runtime through the protocol. The
//  runtime never names an app type.
//
//  Two seams carry the app's contribution into the runtime:
//    1. `ToolRegistry.ProductionToolRegistryBootstrap.start` = the app
//       installs the closure that touches its own tool types; the
//       runtime runs it when the shared registry is read.
//    2. `PathGuard.libraryRootProvider` = the app installs the accessor
//       for the active library root; the runtime reads it when a path
//       is checked.
//    3. `AgentChatProviders.current` = the app installs the chat entry
//       point the verifier probes; the runtime reads it when it checks
//       that the agent answers.
//
//  The conductor's own app half (= the tool catalogue, the settings
//  store, the concrete tools) lives in the app as an extension on the
//  package's `WenshuConductor`, and the import router's shelves root
//  is injected by the app where the router is constructed.
//
//  The path guard's test override (`PathGuard.$libraryRootOverride`)
//  lives in the runtime package, next to the guard that reads it. A
//  task local's storage belongs to the module that declares it, so the
//  runtime could not read one the app declared. The app's
//  `ActiveLibrary.path` reads the same value, so both sides agree.
//
//  ACCESS POLICY:
//
//  The runtime is a separate module, so the access level is enforced by
//  the compiler at the module boundary rather than by convention.
//
//  The boundary is enforced by:
//    1. The module edge (= a runtime file is invisible to the app target
//       unless it declares `public`).
//    2. `Sources/WenshuAgent/Sources/WenshuAgent/Public/` (= the documented
//       surface; = start here to call the runtime from the app).
//    3. This file (= the intent marker; = if you are reading it you are
//       inside the boundary).
//
//  The app-side facade (= `WenshuAgent.shared`) lives at
//  `Sources/WenshuApp/WenshuAgent/Public/WenshuAgent.swift`.
//
//  RATIONALE:
//
//  A separate package gives the runtime an independent version boundary.
//  It gives the runtime its own test target, so the runtime can be checked
//  without a full app build.
//  It gives the runtime a dependency edge the compiler enforces, so a
//  writing tool reaches this package's public surface and nothing else.
//
