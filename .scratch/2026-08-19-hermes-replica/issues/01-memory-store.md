# 01 — Local SQLite memory (MemoryStore.swift, replica mem0)

**What to build:**
老板 2026-08-19 19:57 拍 "bottom-layer dependency replica" — replica hermes mem0 long-term memory to wenshu local SQLite.

After change:
- Create `Sources/WenshuCore/Memory/MemoryStore.swift` (SQLite-backed)
- Interface add / search / get / delete / update, aligned with mem0 platform mode truth
- `swift build` exit 0
- Add unit tests

**Blocked by:** None
**Status:** ready-for-agent → impl done → commit + push (老板 8/19 self-decision authorization + no verification needed)

## Acceptance criteria

- [ ] `Sources/WenshuCore/Memory/MemoryStore.swift` SQLite-backed
- [ ] Table schema: user_id / memory_id / content / created_at / updated_at
- [ ] Interface add / search / get / delete / update
- [ ] `swift build` exit 0
- [ ] Unit tests: MemoryStoreTests add / search / get
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`
- [ ] Do not touch wenshu current SwiftUI UI / business logic

## Business-language description (老板 understands)

- wenshu own long-term memory (local SQLite), like mem0 can search/add, no hermes cloud dependence
- Engineering management authorized by 老板, no verification needed

## Truth references

- mem0 platform truth: `~/.hermes/profiles/pocock/mem0.json` mode = "platform"
- mem0 SDK Python interface: add / search / get / delete / update
- SQLite truth: SQLite3 built into Foundation, Apple standard truth