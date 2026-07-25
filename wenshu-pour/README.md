# wenshu-pour/ · 文枢项目辅助文档池

> **本目录状态**:文枢 (Wenshu) 项目侧"沉淀池" — 装机 user 与 PM-direct 共同维护的项目辅助文档。
> **不装机**:`wenshu-pour/` 不进 `scripts/install.sh` postinstall 复制清单,装机 user 装机后看不到。
> **跟谁平级**:`wenshu-pour/` 在仓根 `/Volumes/ANAN/Engineering/wenshu/` 下,跟 `wenshu/`(装机内容池)平级。
> **跟谁不同**:`wenshu/` 内的 `SOUL.md` / `AGENTS.md` / `methodologies/` 是装机内容(拷到用户 `~/.wenshu-hermes/`);`wenshu-pour/` 是项目侧沉淀(只在仓根,不出仓)。

---

## 命名 (pour = 沉淀)

- **wenshu** = 文枢(项目本身)
- **pour** = 倒 / 沉淀 — 跟 wenshu 配在一起 = "把项目侧的零碎沉淀倒进一个池子"
- **wenshu-pour** = 文枢项目侧沉淀池
- 命名经装机 user 2026-07-25 拍板确认(原候选 A `internal-docs/` / B `pm-notes/` / C `scratch/` / D `wenshu-pour/`)

## 真理源指针

- `@./AGENTS.md` (仓根) — 协作规则真理源(角色边界 / 派单 / 客户侧硬约束 / 评论 SLA / 升级 / 跟上游漂移)
- `@./AGENTS.md §0` (仓根) — 进入研发模式加载清单(PM-direct / CC 必加载内容)
- `@./wenshu/AGENTS.md §12` — 文枢灵魂 / 方法论库 / hermes 通用机制真理源
- `@./wenshu/SOUL.md` — 文枢灵魂(身份 + 哲学 + 4 维核心能力)

---

## 目录约定

| 文件 | 用途 | 状态 |
|------|------|------|
| `README.md` (本文件) | wenshu-pour 是什么 / 命名 / 引用 | ✅ 已落档 (WO-001P) |
| `install-boundary.md` | 装机内容 vs PM 沉淀边界 + 判断标准 | ✅ 已落档 (WO-001P) |
| `user-stories.md` | 用户故事沉淀(Story 1 拍板 / Story 2 草稿 v0.2 / Story 3 占位) | ✅ 已落档 (WO-001P) |
| 未来更多 | 由装机 user 实战需要决定 | ⏳ 待补 |

**新增文件硬约束**(PM-direct 7/25 拍):
- ❌ 不复制 `wenshu/SOUL.md` / `wenshu/AGENTS.md` / `wenshu/methodologies/`(已在 `wenshu/` 下,归 install.sh 复制)
- ❌ 不动 `wenshu/docs/`(PM 沉淀老地方,未来跟 wenshu-pour/ 合并时由装机 user 拍方案)
- ❌ 不动 `wenshu/methodologies/lego/`(WO-001N 残骸,等方案 A/B/C)
- ❌ 不动 `wenshu/SOUL.md` / `wenshu/AGENTS.md`(装机内容,装机 user 装能看到)

---

## 装机 user 周末拍板事项(7/25 拍 + 周末审改)

- [ ] **D-Pour-1**:`wenshu-pour/` 命名是否保留 / 改名 / 换位置
- [ ] **D-Pour-2**:`wenshu-pour/` 是否需要在仓根 `README.md` 加"装机 user 找得到"的入口链接
- [ ] **D-Pour-3**:`wenshu/docs/` 现有 user-stories v0.1 是否要迁到 `wenshu-pour/user-stories.md` + 留 redirect / 不迁 / 双轨
- [ ] **D-Pour-4**:`wenshu-pour/` 未来扩展规则(装机 user 拍板时定):PM-direct 自由加 / 装机 user 拍板每加 / 归类分目录
- [ ] **D-Pour-5**:`wenshu-pour/` 是否要 git commit(本工单 WO-001P 落档后由装机 user 周末审改拍)

---

## 版本

- **v0.1** (2026-07-25):建目录 + README + install-boundary + user-stories v0.2 草稿(WO-001P)。

---

*wenshu-pour/README.md v0.1 · 2026-07-25 · 文枢(Wenshu)项目侧沉淀池 · 基于 hermes-agent v0.19.0 (MIT) 改 fork*
