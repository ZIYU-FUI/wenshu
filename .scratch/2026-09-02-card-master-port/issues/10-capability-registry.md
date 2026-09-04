# Issue 10 — Capability registry

## What (= scope)

Refactor `ChatTrigger` / `SmartQueryParser` / `EntityIngestion` / `CrossRefInject` (= the chat-driven AI pipeline) into a registry pattern. Each capability = 1 file (= protocol + impl + test). Registry collects all capabilities at app launch.

Reference Card-master `src/bilibili-capabilities/registry.ts` (= each capability a separate file, registry collects all).

## Why (= rationale)

Currently these are 4 monolithic functions in `Sources/WenshuApp/Domain/`. Registry pattern enables: open-for-extension (= add new capabilities without touching existing code), single-test per capability, dependency injection.

## Apple-API-first check

- Custom code: `Capability` protocol + `CapabilityRegistry` (= factory + collection).
- Apple HIG candidate: Swift `protocol` + `~Copyable` (macOS 14+) or `any Capability` existential (= canonical registry pattern).
- Apple coverage: partial (= protocol is canonical, registry is custom).
- LOC delta: ~180.
- Risk: med (= refactor of working pipeline = regression risk).

## Files touched

- `Sources/WenshuApp/Domain/Capabilities/Capability.swift` (NEW): protocol.
- `Sources/WenshuApp/Domain/Capabilities/ChatTriggerCapability.ts` (NEW): refactor of `ChatTrigger.swift`.
- `Sources/WenshuApp/Domain/Capabilities/SmartQueryCapability.ts` (NEW): refactor of `SmartQueryParser.swift`.
- `Sources/WenshuApp/Domain/Capabilities/EntityIngestionCapability.ts` (NEW): refactor of `EntityIngestion.swift`.
- `Sources/WenshuApp/Domain/Capabilities/CrossRefInjectCapability.ts` (NEW): refactor of `CrossRefInject.swift`.
- `Sources/WenshuApp/Domain/Capabilities/CapabilityRegistry.swift` (NEW): registry.
- Delete (or keep as stub): the 4 monolithic files in `Domain/`.

## Acceptance criteria

- [ ] Each capability conforms to `Capability` protocol.
- [ ] `CapabilityRegistry.register(_:)` adds; `CapabilityRegistry.all` returns the collection.
- [ ] Each capability has its own test file.
- [ ] No caller (= `App.swift`, `ChatView.swift`) imports the old monolithic functions.
- [ ] macOS screenshot confirms chat-driven AI pipeline still works (= end-to-end test: user enters query → entity appears).

## Dependencies

None.

## References

- Source: Card-master `src/bilibili-capabilities/registry.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 10

First line: fact. Last line: fact.