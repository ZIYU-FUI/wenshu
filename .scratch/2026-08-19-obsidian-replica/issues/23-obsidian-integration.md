# 23 — Obsidian replica scope A integration + cross-tool compatibility test (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian replica 9 tickets (12-22) integration test + cross-tool compatibility verification (JSON Canvas .canvas file Obsidian ↔ wenshu 1:1 round-trip + .base YAML + Markdown frontmatter + Internal Link bidirectional compatibility).

**After change:**
- Integration tests: `ObsidianFixtures.swift` (Obsidian public sample fixtures, run wenshu parse + encode → diff against original file verify 1:1)
- `swift test` exit 0 (new tests + old 137)
- CONTEXT.md add ObsidianReplicant domain word (replica scope + cross-tool compatibility)
- ADR `docs/adr/0007-obsidian-compatibility.md` write Obsidian compatibility constraints

**Blocked by:** ticket 12-22 (all Obsidian replica tickets)
**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria

- [ ] `Tests/WenshuAppTests/Integration/ObsidianFixtures.swift`
- [ ] JSON Canvas .canvas cross-tool round-trip test
- [ ] .base YAML cross-tool round-trip test
- [ ] Markdown frontmatter cross-tool round-trip test
- [ ] Internal Link bidirectional round-trip test
- [ ] `swift test` exit 0 (new tests + old 137)
- [ ] CONTEXT.md add ObsidianReplicant domain word
- [ ] `docs/adr/0007-obsidian-compatibility.md`
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`
- [ ] Do not touch LayoutTokens / LayoutShellView / NativeSplitter

## Business-language description (老板 understands)

- Integration test + cross-tool compatibility: Obsidian writes .canvas → wenshu reads, wenshu writes → Obsidian reads
- Engineering management authorized by 老板

## Truth references

- JSON Canvas 1.0 spec: https://jsoncanvas.org/spec/1.0
- Obsidian Bases: https://obsidian.md/help/bases