---
name: wenshu-architecture-decision-record
description: A1 (= Persistence local SPM package) blocked by 6-repo app-domain coupling. Required reading before any A-route ticket.
version: 3.1.0
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [wenshu, architecture, adr, persistence, decision-record]
    category: architecture
    note: "ADR-0016. Records the A1 blocker (= app-domain coupling in 6 repos). Supersedes the optimistic A1d plan in persistence-boundary-catalog.md."
related_skills:
  - wenshu-pocock-workflow
---

# ADR-0016: WenshuData extraction = blocked by 6-repo app-domain coupling

Date: 2026-10-15 (= v3.1 governance arc, A1 probe).

## Context

Boss 2026-10-15 拍 = v3.1 governance restructure project
(`Sources/WenshuApp/Persistence/` -> local SwiftPM package
`Sources/WenshuData/`, = Apple Backyard Birds canonical pattern, =
AGENTS.md §6.4). Probed boundary on 2026-10-15.

## Decision (= scope re-baselined)

WenshuData extraction **does not ship** as 1 ticket. Real coupling
discovered: all 6 "ready" Repository files plus the 2 "blocked"
ones (= 8 of 8) reference app-side domain types. Catalog at
`docs/agents/persistence-boundary-catalog.md` had partial findings;
this ADR records the corrected full picture.

| File | App-domain dependency | Source |
|------|----------------------|--------|
| WSBookmarkRepository | `Bookmark` type | `Core/Bookmark/*.swift` |
| WSKanbanRepository | `KanbanTask` + `KanbanStatus` | `Core/Kanban/KanbanDomain.swift` |
| WSLinkRepository | `Link` + `LinkIndex` | `Core/LinkGraph/*.swift` |
| WSPreferenceRepository | `WenshuWorkspace` (×1) | `Core/Storage/*.swift` |
| WSProviderKeyRepository | `AppleKeychain` (= `ProviderKeychain` reader) | `Core/Auth/AppleKeychain*.swift` |
| WSTodoRepository | `TodoItem` + `TodoPriority` + `TodoStatus` | `Core/Todo/TodoDomain.swift` |
| WSMemoryRepository | `Memory` | `Core/Memory/MemoryManager.swift` |
| WSChatRepository | `StoredChatMessage` + `BookID` | `Core/Chat/Domain/` |

**Per Apple Backyard Birds canonical**: data layer (`WenshuData`)
MUST NOT reference app-side domain types. Conversion belongs in
caller (= app target's UseCase / ViewModel layer).

## Revised plan

| # | Scope | LOC estimate | Risk |
|---|-------|--------------|------|
| A1d | **drop** (= superseded by this ADR) | n/a | n/a |
| **A1e** | decouple 6 of 8 Repository from app-domain types (= move domain types down to `Sources/WenshuData/` shared types OR push conversion out to caller-side UseCase). Each repo = 1 PR. | ~300 LOC × 6 = ~1800 | medium (= breaks existing call sites; needs caller-side use-case code) |
| **A1f** | decouple WSChatRepository + WSMemoryRepository (= same A1e pattern) | ~150 LOC × 2 = ~300 | medium |
| **A1g** | extract all 38 files to `Sources/WenshuData/` local SPM package. Add `public` access modifier to 22 @Model + 8 Repository + 1 WSRepositoryContainer + 1 WSPersistenceContainer. Adjust 30+ caller-side `import WenshuData`. | ~1000 LOC churn | high (= each access modifier addition risks cascade failures) |
| A1h | delete `Sources/WenshuApp/Persistence/` (= empty after A1g) | trivial | 0 |

Per AGENTS.md §1.10 = 1 ticket = 1 commit; = each row above splits to
1 commit, = A1 = at least 8 sequential commits (= 4 weeks of
focussed work).

## Alternative = defer entirely

Boss拍 = "let me decide" canonical OOB pattern. If boss says "the
value is not worth 4 weeks of commits", this ADR is the cancel proof.
v3.1 governance wrote SSOT / OOB / .hermes.md; the AI-context-window
problem (= 4000 lines of mandatory context per turn) is FIXED without
A1. A1 = nice-to-have, not essential.

## References

- AGENTS.md §6.4 (Apple Backyard Birds target structure)
- AGENTS.md §6.5 (file suffix naming rules)
- persistence-boundary-catalog.md (initial probe)
- wenshu-swift-standards.md §6 (SwiftData canonical persistence rules)
