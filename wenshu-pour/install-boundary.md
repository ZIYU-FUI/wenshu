# install-boundary.md · 装机内容 vs PM 沉淀边界

> **本文件状态**:文枢 (Wenshu) 装机脚本 `scripts/install.sh` 复制边界的真理源。装机 user 2026-07-25 拍板。
> **真理源指针**:@./README.md(目录命名)+ @../AGENTS.md(仓根,协作规则真理源)+ @../wenshu/SOUL.md(灵魂)。
> **变更规则**:装机内容 vs PM 沉淀边界由装机 user 拍板变更,PM-direct 派工单修改,CC 落档。

---

## 1. 一句话判断标准

> **"装机 user 第一次启动文枢时,需不需要加载这个文件?"**
>
> - **需要** → 装机内容 → 进 `scripts/install.sh` postinstall 复制清单
> - **不需要** → PM 沉淀 → 留仓内 `wenshu-pour/` / `wenshu/docs/` / 调研,装机 user 看不到

---

## 2. 装机内容(进 `scripts/install.sh` postinstall)

装机 user 装机后,在用户机器 `~/.wenshu-hermes/` 下能看到 + 文枢开机加载。

| # | 源文件(仓内) | 目标(用户机器) | 装机 user 必加载理由 |
|---|--------------|----------------|---------------------|
| 1 | `wenshu/SOUL.md` | `~/.wenshu-hermes/SOUL.md` | 文枢灵魂 — 身份 + 哲学 + 4 维核心能力 |
| 2 | `wenshu/AGENTS.md` | `~/.wenshu-hermes/AGENTS.md` | 文枢工作手册 — 7 步通用节点框架 + 一致性清单 + 反向建议模板 |
| 3 | `wenshu/methodologies/`(递归) | `~/.wenshu-hermes/methodologies/` | 方法论库 — 文枢开机自动扫描,列出"可选方法清单"。`methodologies/README.md` 必拷 + 9 公版(见下)必拷 |

### 9 公版(在 `wenshu/methodologies/` 下,装机 user 装机后能看到)

装机 user 2026-07-25 拍 + 落档于 commit `2eef5e5e5` "translate 9 public-domain foreign methodologies":

| 子目录 | 公版(public domain) |
|--------|---------------------|
| `classical/` | five-ws-one-h / imrad / inverted-pyramid (3) |
| `commercial/` | aida-lewis (1) |
| `foundations/` | freytag-pyramid / hero-journey-campbell / seven-basic-plots-booker / snowflake-ingermanson / three-act-aristotle (5) |
| `examples/` | scqa-storytelling (文枢示例,commit `6512d5751`,非公版,但属装机内容) |

合计 9 公版 + 1 文枢示例 = 10 个方法论 .md。

---

## 3. 不打包(PM-direct 内部沉淀,留仓内)

装机 user 装机后**看不到**,只在仓根 `/Volumes/ANAN/Engineering/wenshu/` 下,给 PM-direct / CC / 装机 user 自己(回查)用。

| # | 路径 | 内容 | 不打包理由 |
|---|------|------|-----------|
| 1 | `wenshu-pour/`(本目录) | README + install-boundary + user-stories v0.2 + 未来更多 | 装机 user 不需要"项目侧沉淀池"的元数据,这是 PM-direct / CC / 装机 user 周末审改用 |
| 2 | `wenshu/docs/` | user-stories v0.1 (Story 1 完整) + 未来更多 | 装机 user 不需要"用户故事沉淀"原文 — 故事是在 PM↔装机 user 沟通里跑的,不是装机后跑的 |
| 3 | `wenshu/methodologies/lego/` | WO-001N 残骸(README + INDEX + category/*) | 节点碎片库,等装机 user 拍方案 A/B/C(重建 / 不建 / 部分建),不是定稿方法论,装机不能拷 |
| 4 | 调研 / 飞书记录 / 截图 | 装机 user 实战案例原始材料 | 不入仓 / 入仓 `.gitignore` 屏蔽 |
| 5 | `apps/desktop/electron/*.bak` / `*.tmp` 等 | CC 改 hermes 业务代码时的临时备份 | 严禁,业务代码沿用 hermes,CC 不写备份 |
| 6 | `__pycache__/` / `.pytest_cache/` / `node_modules/` / `target/` | 各种 build / cache | 装机 user 不需要 build 产物,`.gitignore` 已屏蔽 |

---

## 4. `scripts/install.sh` 复制逻辑(真理源)

```bash
# 摘自 scripts/install.sh copy_config_templates() (2026-07-25 验证)
# 行号:1824 / 1840 / 1853

cp "$INSTALL_DIR/wenshu/SOUL.md"        "$HERMES_HOME/SOUL.md"
cp "$INSTALL_DIR/wenshu/AGENTS.md"      "$HERMES_HOME/AGENTS.md"
cp -r "$INSTALL_DIR/wenshu/methodologies/." "$HERMES_HOME/methodologies/" 2>/dev/null || true
```

**装机内容 = 3 类**(SOUL.md / AGENTS.md / methodologies/ 递归)。

**⚠️ 已知问题**(等装机 user 拍板):
- `cp -r wenshu/methodologies/.` 会把 `lego/`(WO-001N 残骸)也复制过去。如果装机 user 拍方案 A/B/C 让 lego/ 重建,需要补一个 `cp` 黑名单 exclude。

---

## 5. 装机 user 周末拍板事项(7/25 拍 + 周末审改)

- [ ] **D-Bound-1**:`scripts/install.sh` 复制清单是否需要补黑名单(exclude `wenshu/methodologies/lego/`)
- [ ] **D-Bound-2**:`wenshu/docs/` 现状不动 / 未来合并到 `wenshu-pour/` / 双轨(本工单 WO-001P 不动 `wenshu/docs/`,等装机 user 拍)
- [ ] **D-Bound-3**:装机内容是否要加 `wenshu/methodologies/examples/scqa-storytelling.md`(文枢示例,当前 install.sh 递归复制自动带入)
- [ ] **D-Bound-4**:未来 9 公版增删的边界 — 由装机 user 拍板 / PM-direct 自由增删 / 走 PR 流程

---

## 6. 装机 user vs PM-direct 边界(交叉引用)

- **装机 user 拍**:`install-boundary.md` 修改 / 装机内容清单调整 / `wenshu/docs/` 是否合并到 `wenshu-pour/`
- **PM-direct 派单**:CC 改 install.sh 复制逻辑 / 改装机内容源文件(`wenshu/SOUL.md` 等)
- **CC 改**:落档 `install-boundary.md` 变更 / 改 `scripts/install.sh` 单文件(不批量改)

---

## 版本

- **v0.1** (2026-07-25):建 `wenshu-pour/` + 装机内容 vs PM 沉淀边界落档(WO-001P)。装机 user 周末审改 4 项决策(D-Bound-1 ~ D-Bound-4)。

---

*install-boundary.md v0.1 · 2026-07-25 · 文枢(Wenshu)装机内容 vs PM 沉淀边界 · 基于 hermes-agent v0.19.0 (MIT) 改 fork*