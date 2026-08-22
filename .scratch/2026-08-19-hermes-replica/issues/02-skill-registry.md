# 02 — Local Skills loading (SkillRegistry.swift, replica hermes skills)

**What to build:**
老板 2026-08-19 19:57 拍 "bottom-layer dependency replica" — replica hermes skills loading mechanism to wenshu local markdown files.

After change:
- Create `Sources/WenshuCore/Skills/SkillRegistry.swift` (scan markdown files)
- Create `Sources/WenshuCore/Skills/SkillLoader.swift` (`load(name)` get SKILL.md)
- `swift build` exit 0
- Add unit tests (`SkillRegistry.scan` / `load`)

**Blocked by:** ticket 01 (MemoryStore)

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 self-decision authorization + no verification needed)

## Acceptance criteria

- [ ] `Sources/WenshuCore/Skills/SkillRegistry.swift` scan `Sources/WenshuCore/Skills/<name>/SKILL.md`
- [ ] parse frontmatter (YAML) + body (markdown)
- [ ] `Sources/WenshuCore/Skills/SkillLoader.swift` `load(name)` get SKILL.md content + linked_files
- [ ] `swift build` exit 0
- [ ] Unit tests: SkillRegistryTests scan / load
- [ ] Do not touch hermes app / `~/.hermes/profiles/pocock/`
- [ ] Do not touch wenshu current SwiftUI UI / business logic

## Business-language description (老板 understands)

- wenshu own skill registry (local markdown files), like hermes can load SKILL.md + parse frontmatter, no hermes skills loading dependence
- Engineering management authorized by 老板, no verification needed

## Truth references

- hermes SKILL.md truth: `~/.hermes/profiles/pocock/skills/<name>/SKILL.md` (35 files)
- frontmatter truth: name / description + body markdown
- linked_files truth: references/ templates/ scripts/