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
//      ├── Agent/                      (LLM block / usage / response types)
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
//      ├── Tool/                       (tool schema + tool exposure)
//      └── Turn/                       (turn context + finalizer + notes)
//
//  Eight source files stay inside the app target at
//  `Sources/WenshuApp/WenshuAgent/`.
//  They stay because they reference the app's tool registry, the tool
//  executor, the auth pool, the provider catalogue and the app delegate,
//  all of which live in the app target.
//  Moving them into the runtime package is separate work that needs the
//  dependency-inversion decision first.
//
//      Sources/WenshuApp/WenshuAgent/
//      ├── Agent/
//      │   ├── ConversationLoop.swift
//      │   ├── WenshuConductor.swift
//      │   ├── WenshuConductorImportRouter.swift
//      │   ├── WenshuConductorImportRouterHelpers.swift
//      │   └── WenshuVerifier.swift
//      ├── App/
//      │   └── WenshuAppDelegateLLM.swift
//      ├── Keychain/
//      │   └── KeychainSelector.swift
//      └── Public/
//          └── WenshuAgent.swift
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
