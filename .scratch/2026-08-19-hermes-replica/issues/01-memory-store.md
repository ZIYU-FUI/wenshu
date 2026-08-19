# 01 — 本地 SQLite 记忆 (MemoryStore.swift, 复刻 mem0)

**What to build:**
老板 2026-08-19 19:57 拍 "底层依赖复刻" — 复刻 hermes mem0 长期记忆到 wenshu 本地 SQLite.

改完:
- 新建 Sources/WenshuCore/Memory/MemoryStore.swift (SQLite-backed)
- 接口 add / search / get / delete / update, 跟 mem0 platform 模式真值对齐
- swift build exit 0
- 加单元测试

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit + push (老板 8/19 自行决策授权 + 不需要验收)

## Acceptance criteria

- [ ] Sources/WenshuCore/Memory/MemoryStore.swift SQLite-backed
- [ ] 表 schema: user_id / memory_id / content / created_at / updated_at
- [ ] 接口 add / search / get / delete / update
- [ ] swift build exit 0
- [ ] 单元测试: MemoryStoreTests add / search / get
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/
- [ ] 不动 wenshu 当前 SwiftUI UI / 业务逻辑

## 业务语言描述 (老板懂)

- wenshu 自己的长期记忆 (本地 SQLite), 跟 mem0 一样能 search/add, 不靠 hermes 云
- 工程管理老板授权, 不需要验收

## 真值引用

- mem0 platform 真值: ~/.hermes/profiles/pocock/mem0.json mode = "platform"
- mem0 SDK Python 接口: add / search / get / delete / update
- SQLite 真值: SQLite3 内置 Foundation, Apple 标准真值