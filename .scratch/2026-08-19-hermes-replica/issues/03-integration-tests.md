# 03 — 集成测试 + WenshuCore 模块化

**What to build:**
老板 2026-08-19 19:57 拍 "底层依赖复刻" — 集成测试 + WenshuCore 模块独立.

改完:
- 集成测试 WenshuCore 1 file
- swift build exit 0
- 文档化 WenshuCore API 给后续 wenshu 业务调用

**Blocked by:** ticket 01 + 02 (MemoryStore + SkillRegistry)

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 自行决策授权 + 不需要验收)

## Acceptance criteria

- [ ] Sources/WenshuCore/Tests/WenshuCoreTests.swift 集成测试
- [ ] swift build exit 0
- [ ] 全部 17 swift test exit 0 (老测试 + 新测试)
- [ ] swift test exit 0
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 wenshu 当前 SwiftUI UI / 业务逻辑
- [ ] CONTEXT.md 加 WenshuCore domain word (Memory + Skills 模块化)

## 业务语言描述 (老板懂)

- 集成测试 WenshuCore (1 个 swift test 跑通 MemoryStore + SkillRegistry)
- 文档化新模块给后续调用
- 工程管理老板授权, 不需要验收

## 真值引用

- Apple Swift Testing 真值: XCTest / swift-testing
- WenshuCore 模块化真值: Swift Package Manager (SPM) local package