# 02 — 本地 Skills 加载 (SkillRegistry.swift, 复刻 hermes skills)

**What to build:**
老板 2026-08-19 19:57 拍 "底层依赖复刻" — 复刻 hermes skills 加载机制到 wenshu 本地 markdown files.

改完:
- 新建 Sources/WenshuCore/Skills/SkillRegistry.swift (扫 markdown files)
- 新建 Sources/WenshuCore/Skills/SkillLoader.swift (load(name) 拿 SKILL.md)
- swift build exit 0
- 加单元测试 (SkillRegistry.scan / load)

**Blocked by:** ticket 01 (MemoryStore)

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 自行决策授权 + 不需要验收)

## Acceptance criteria

- [ ] Sources/WenshuCore/Skills/SkillRegistry.swift 扫 Sources/WenshuCore/Skills/<name>/SKILL.md
- [ ] parse frontmatter (YAML) + body (markdown)
- [ ] Sources/WenshuCore/Skills/SkillLoader.swift load(name) 拿 SKILL.md 内容 + linked_files
- [ ] swift build exit 0
- [ ] 单元测试: SkillRegistryTests scan / load
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 wenshu 当前 SwiftUI UI / 业务逻辑

## 业务语言描述 (老板懂)

- wenshu 自己的 skill registry (本地 markdown files), 跟 hermes 一样能 load SKILL.md + parse frontmatter, 不靠 hermes skills 加载
- 工程管理老板授权, 不需要验收

## 真值引用

- hermes SKILL.md 真值: ~/.hermes/profiles/pocock/skills/<name>/SKILL.md (35 个)
- frontmatter 真值: name / description + body markdown
- linked_files 真值: references/ templates/ scripts/