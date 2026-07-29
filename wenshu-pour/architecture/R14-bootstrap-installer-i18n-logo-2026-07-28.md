# WO-001BI-R14 Bootstrap installer i18n + LOGO (8/28 拍)

## 1. 派单真值

装机 user 8/28 拍板真值：
- 设置页 LOGO 仍是 nous-girl.jpg（应改为 WENSHU 文字标识）
- 设置页步骤名英文（Prerequisites/Repository/Venv/Python deps/Node deps/Path/Config/Setup/Gateway/Complete）应翻译为中文
- 错误页 "Could not connect to 文枢 gateway" 已对，gateway 启动问题不在本单（属 apps/desktop 启动链路）
- success 页小字"您可以从这里启动，也可以随时从终端运行 hermes desktop"必须删

## 2. 实际跑通结果 (CC R14 跑通，PID 8882 真完成 + PID 8868 wrapper 17:06:08 退出)

### 改动文件

| 文件 | 改动 |
|------|------|
| apps/bootstrap-installer/src/components/brand-mark.tsx | 改为 WENSHU 文字标识（同 desktop），无旧 nous-girl.jpg 引用 |
| apps/bootstrap-installer/src/routes/progress.tsx | 72 行新增/29 行删除：10 步骤名改用 `tStep(key)` 走 i18n，加 STAGE_NAME_TO_STEP_KEY 映射 |
| apps/bootstrap-installer/package.json | +1 devDep (prettier 3.9.6) |
| apps/desktop/src/components/brand-mark.tsx | 已先改 (R1 时)：WENSHU 文字标识 |
| apps/bootstrap-installer/src/i18n/zh.ts (新) | 10 步骤中文翻译：系统环境检查 / 拉取文枢源码 / 创建 Python 虚拟环境 / 安装 Python 依赖 / 安装 Node 依赖 / 配置命令行入口 / 准备配置和技能 / 配置 API 密钥和设置 / 配置网关服务 / 完成安装 |
| apps/bootstrap-installer/src/i18n/en.ts (新) | 10 步骤英文 key |
| apps/bootstrap-installer/src/i18n/index.ts (新) | i18n 入口 |
| apps/bootstrap-installer/src/i18n/languages.ts (新) | Translations 类型 + tStep 函数 |

### success.tsx (R14 不必改，源码已对)

- 启动前 R14 已把 "您可以从这里启动" 删了（PM-direct R5 之前改过）
- 当前 success.tsx 仅保留 WENSHU 已就绪 + 启动按钮 + 错误兜底

## 3. 派单失败真值表 (R14 实战 8/28)

| 派单 | 失败模式 | 修法 |
|------|---------|------|
| R14 第一次（PID 8557） | zsh `unmatched "`（inline prompt 含未转义引号） | 改用 prompt 文件方式，cat heredoc 到 /tmp/cc-out/wo-XXX-prompt.md |
| R14 第二次（PID 8868 + 8882） | 跑通，但 11 分 0 字节火警 | fire.log 0 字节时仍可能有进度（CC 思考/读文件），3 文件改动是真实信号。设 10 分钟阈值降级 |
| cc-watch 第一次（PID 10165） | zsh 不认 `${WO_ID,,}` lowercase | 改用 `tr '[:upper:]' '[:lower:]'` |

## 4. 飞书退知机制 (8/28 装机 user 拍)

装机 user 拍"实时同步我进度，不要等几分钟就问"。已装：

- `~/.hermes/profiles/my-pm/scripts/feishu-dm.py` - 飞书 DM 推送
- `~/.hermes/profiles/my-pm/scripts/cc-watch.sh` - 5min 巡检 + 飞书推状态

派单后立即跑：
```bash
/Users/anbaiqiang/.hermes/profiles/my-pm/scripts/cc-watch.sh WO-XXX
```

实战 R14 发了 4 条飞书 DM（PM-direct 状态报告 + 巡检 + 完成报告）。

## 5. AC 自验

| AC | 内容 | 结果 |
|----|------|------|
| AC1 | success.tsx 不含 "您可以从这里启动" / "hermes desktop" 小字 | ✅（R14 启动前 R5 已删，R14 保持） |
| AC2 | progress.tsx 10 步骤名翻译为中文 | ✅（走 `tStep(key)` i18n） |
| AC3 | brand-mark.tsx 改用纯文本 WENSHU 标识 | ✅（install + desktop 都换） |
| AC4 | i18n zh.ts 含 10 步骤中文翻译键值对 | ✅（zh.ts 落档完整 10 步骤） |
| AC5 | cd apps/bootstrap-installer && pnpm exec prettier --check 全部通过 | ✅（"All matched files use Prettier code style"） |

## 6. 后续动作

- WO-001BI-R15: 重 build desktop DMG + 装到 /Applications + 跑 hermes serve 自验
- WO-001BI-R16: gateway 启动链路修复（apps/desktop/electron/main.ts 默认 home 改为 ~/.wenshu-hermes）
- WO-001BI-R17: online update 链路接通（hermes update + hermes desktop --build-only）

## 7. 落档位置

- 本文件：`wenshu-pour/architecture/R14-bootstrap-installer-i18n-logo-2026-07-28.md`
- 派单失败真值表：`~/.hermes/profiles/my-pm/skills/cc-fire-cc-cli-mechanics/references/pitfall-65-cc-failure-table.md`
- fire.log 零字节根因：`~/.hermes/profiles/my-pm/scripts/README-fire-log-zero-bytes.md`
- 派单边界真值：`~/.hermes/profiles/my-pm/skills/pm/pm-workflow/references/pitfall-56-pm-direct-vs-cc-boundary.md`
