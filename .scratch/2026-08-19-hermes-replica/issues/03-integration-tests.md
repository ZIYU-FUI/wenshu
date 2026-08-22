# 03 — Integration tests + WenshuCore modularization

**What to build:**
老板 2026-08-19 19:57 拍 "bottom-layer dependency replica" — integration tests + WenshuCore module independent.

After change:
- Integration tests WenshuCore 1 file
- `swift build` exit 0
- Document WenshuCore API for subsequent wenshu business calls

**Blocked by:** ticket 01 + 02 (MemoryStore + SkillRegistry)

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 self-decision authorization + no verification needed)

## Acceptance criteria

- [ ] `Sources/WenshuCore/Tests/WenshuCoreTests.swift` integration tests
- [ ] `swift build` exit 0
- [ ] All 17 swift test exit 0 (old tests + new tests)
- [ ] `swift test` exit 0
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`
- [ ] Do not touch wenshu current SwiftUI UI / business logic
- [ ] CONTEXT.md add WenshuCore domain word (Memory + Skills modularization)

## Business-language description (老板 understands)

- Integration tests WenshuCore (1 swift test runs MemoryStore + SkillRegistry)
- Document new module for subsequent calls
- Engineering management authorized by 老板, no verification needed

## Truth references

- Apple Swift Testing truth: XCTest / swift-testing
- WenshuCore modularization truth: Swift Package Manager (SPM) local package