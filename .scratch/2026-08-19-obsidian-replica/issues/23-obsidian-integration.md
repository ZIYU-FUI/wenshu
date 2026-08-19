# 23 — Obsidian 复刻范围 A 集成 + 跨工具兼容性测试 (老板 2026-08-19 evening 拍)

**What to build:**
Obsidian 复刻 9 ticket (12-22) 集成测试 + 跨工具兼容性验证 (JSON Canvas .canvas 文件 Obsidian ↔ wenshu 1:1 round-trip + .base YAML + Markdown frontmatter + Internal Link 双向兼容)。

**改完:**
- 集成测试: ObsidianFixtures.swift (Obsidian 公开样例 fixture, 跑 wenshu 解析 + 编码 → 跟原文件 diff 验证 1:1)
- swift test exit 0 (新测试 + 老 137)
- CONTEXT.md 加 ObsidianReplicant domain word (复刻范围 + 跨工具兼容)
- ADR docs/adr/0007-obsidian-compatibility.md 写 Obsidian 兼容性约束

**Blocked by:** ticket 12-22 (所有 Obsidian 复刻 ticket)

**Status:** ready-for-agent → impl done → commit + push

## Acceptance criteria
- [ ] Tests/WenshuAppTests/Integration/ObsidianFixtures.swift
- [ ] JSON Canvas .canvas 跨工具 round-trip 测试
- [ ] .base YAML 跨工具 round-trip 测试
- [ ] Markdown frontmatter 跨工具 round-trip 测试
- [ ] Internal Link 双向链接 round-trip 测试
- [ ] swift test exit 0 (新测试 + 老 137)
- [ ] CONTEXT.md 加 ObsidianReplicant domain word
- [ ] docs/adr/0007-obsidian-compatibility.md
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 LayoutTokens / LayoutShellView / NativeSplitter

## 业务语言描述 (老板懂)
- 集成测试 + 跨工具兼容: Obsidian 写 .canvas → wenshu 读, wenshu 写 → Obsidian 读
- 工程管理老板授权

## 真值引用
- JSON Canvas 1.0 spec: https://jsoncanvas.org/spec/1.0
- Obsidian Bases: https://obsidian.md/help/bases
