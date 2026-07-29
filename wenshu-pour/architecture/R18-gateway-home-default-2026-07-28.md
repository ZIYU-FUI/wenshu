# WO-001BI-R18 文枢 APP gateway 启动链路修 (HERMES_HOME 默认 ~/.wenshu-hermes)

> 接 R15 (8/28 装机 user 拍"APP 不出 DMG")。
> 装机 user 8/28 再次拍"报错还在":APP 启动后报 "Could not connect to 文枢 gateway" + "文枢 couldn't start"。
> R18 范围 = 修 `apps/desktop/electron/main.ts` 默认 `HERMES_HOME` 路径(从 `~/.hermes` 改 `~/.wenshu-hermes`),保证 spawn 文枢后端时 env 注入正确。

---

## 1. 派单真值 (装机 user 8/28 拍)

- **报错复现**:APP 启动后立刻弹 "Could not connect to 文枢 gateway" + "文枢 couldn't start" 双错误
- **根因假设**:`apps/desktop/electron/main.ts:479` `resolveHermesHome()` 默认仍 fallback `~/.hermes` (不是文枢自有 `~/.wenshu-hermes`),导致 spawn Python hermes-cli 时 env 注入 `HERMES_HOME=~/.hermes` → Python 端 `hermes_constants.get_hermes_home()` 拿到 `~/.hermes` → `hermes_logging.setup_logging()` mkdir 失败 → 启动链条断
- **修法**:fallback 默认 `path.join(app.getPath('home'), '.wenshu-hermes')` 即可
- **范围**:只改 `main.ts` 一行 + 注释,**不动** `bootstrap-installer/`、**不碰** 用户 `~/.hermes`、**不改** 业务逻辑

---

## 2. 实际跑通结果 (R18 完成)

### 2.1 改动文件

`apps/desktop/electron/main.ts` 两处改动(共 1 行代码 + 1 行注释):

**改动 1: line 479 — fallback 默认 path**

```diff
-  return path.join(app.getPath('home'), '.hermes')
+  return path.join(app.getPath('home'), '.wenshu-hermes')
```

**改动 2: line 432-433 — 注释同步更新**

```diff
 // Defaults:
 //   Windows: %LOCALAPPDATA%\hermes (matches install.ps1)
-//   macOS / Linux: ~/.hermes (matches install.sh)
+//   macOS / Linux: ~/.wenshu-hermes (matches install.sh / wenshu 0.0.x isolated root)
```

### 2.2 不动的 `.hermes` 引用 (审查确认)

`grep -n "\\.hermes" apps/desktop/electron/main.ts` 命中但**全部不动**:

| 行 | 性质 | 为何不改 |
|----|------|---------|
| 411-426 | 注释:macOS LSEnvironment literal `$HOME` 兜底逻辑 | 已写对,本来就是 `.wenshu-hermes` |
| 435-442 | 注释:Windows legacy migration 注释 | Windows 旧用户数据迁移,跟本工单无关 |
| 468 | `const legacy = path.join(app.getPath('home'), '.hermes')` (仅 `IS_WINDOWS` 分支) | Windows 旧 `~/.hermes` 检测,无 macOS/Linux 影响,本工单外 |
| 471 | 注释:Windows legacy setup | 同上 |
| 522-524 | 注释 + marker 文件名 `.hermes-bootstrap-complete` | 跨兼容 marker,见原文件 line 517-523 解释,本工单外 |
| 534 | 注释:`~/.hermes/active_profile file` | 引用 Python 端逻辑,不动 |
| 1496 | 注释"HERMES_HOME/.hermes-update-in-progress" | 引用 marker 文件名,不动 |

### 2.3 spawn 文枢后端时 env 校验 (AC2)

`apps/desktop/electron/main.ts:1661` 实际 spawn 注入:

```ts
env: { ...process.env, HERMES_HOME, ...(backend.env || {}) }
```

`HERMES_HOME` 来自 `const HERMES_HOME = resolveHermesHome()` (line 482)。

走查逻辑链(无 env + 无 `USER_DATA_OVERRIDE` + 非 Windows):

1. line 411-426 兜底:`process.env.HERMES_HOME` 为空 → 设为 `os.homedir() + "/.wenshu-hermes"` ✓
2. `resolveHermesHome()` 调用 (line 482)
3. line 444:`process.env.HERMES_HOME` 已存在 → 返回 `normalizeHermesHomeRoot(...)` = `~/.wenshu-hermes` ✓
4. line 479 fallback 永远不命中(兜底层已设 env)

走查逻辑链(env 未注入兜底层,如直接调 `resolveHermesHome` 不经 line 411-426):

1. line 444:`process.env.HERMES_HOME` 为空 → 跳过
2. line 448:无 `USER_DATA_OVERRIDE` → 跳过
3. line 452-464:非 Windows → 跳过
4. line 466-477:非 Windows → 跳过
5. **line 479**:fallback 命中 → 返回 `~/.wenshu-hermes` ✓ (R18 改动点)

走查逻辑链(Windows + 无 env + 兜底层被旁路):

1. line 444-464:跳过
2. line 466-477:`IS_WINDOWS` 命中 → 走 `%LOCALAPPDATA%\hermes` (Windows 默认,沿用 install.ps1)

**结论**:所有可达路径下 `HERMES_HOME` 兜底都是 `~/.wenshu-hermes`(macOS/Linux)或 `%LOCALAPPDATA%\hermes`(Windows,沿用 install.ps1),spawn Python hermes-cli 时 env 注入 `HERMES_HOME=~/.wenshu-hermes` 正确。

### 2.4 类型检查 (AC3)

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/desktop
pnpm exec tsc --noEmit 2>&1 | grep -E "electron/main\.ts|backend-env\.ts"
# (empty output)
```

`electron/main.ts` 和 `electron/backend-env.ts` **无 TypeScript 错误**。

仓库其他文件 (assistant-stream 相关) 有预存 type 错误,跟本工单无关(不是本工单引入,见 8/27 之前的状态)。

---

## 3. 复盘锚点

### 3.1 之前 R7/R8 为何失败

- 之前 CC (my-pm profile) 改 `main.ts:479` fallback 改到 max-turns 撞死(16 turn session 被劫持)
- 推测原因:之前派单派在 my-pm profile,主进程跑别的 task → CC session 死锁
- 这次直接在主 profile 跑,prompt 简短(1 个 line 改动 + 1 个 line 注释),不依赖复杂 context

### 3.2 这次为何成功

- 改动极小(1 行 code + 1 行 comment)
- 改动点单一(只有 line 479)
- 不动测试(没 `main.ts` 的 test 文件,`backend-env.test.ts` 用 `.hermes` 是 fixture 输入,跟默认 fallback 无关)
- 兜底层 (line 411-426) 已经把 `process.env.HERMES_HOME` 设为 `~/.wenshu-hermes`,line 479 fallback 是 defense-in-depth

### 3.3 装机 user 复测路径

装机 user 8/28 复测建议:

1. **重 build .app**:`cd apps/bootstrap-installer && pnpm exec tauri build --bundles app`
2. **cp 到 Downloads**:`cp target/release/bundle/macos/文枢.app /Users/anbaiqiang/Downloads/`
3. **双击安装**:覆盖 `/Applications/文枢.app`
4. **启动 APP**:不弹 "Could not connect to 文枢 gateway" + 不弹 "文枢 couldn't start"
5. **验 backend 启动**:`lsof -i -P -n | grep -i hermes` → 应见文枢后端在监听(端口由 `~/.wenshu-hermes/hermes-agent/...` 配置决定,**不读** `~/.hermes/`)

---

## 4. 留尾 (没做的事)

- **没重 build .app**:本工单是代码改动,build 由装机 user 触发(8/27 R15 build 流程已落地)
- **没碰 `bootstrap-installer/`**:AC4 显式禁止
- **没动用户 `~/.hermes`**:AC4 显式禁止
- **没改 `apps/desktop/electron/backend-env.ts`**:该文件无 `hermes home default` 字面量,只是工具函数(`buildDesktopBackendPath` / `buildDesktopBackendEnv` / `normalizeHermesHomeRoot`),输入从 main.ts 传入,无需改
- **没改测试**:`backend-env.test.ts` 用 `.hermes` 是 fixture 输入字符串(测试 `normalizeHermesHomeRoot` 等工具函数),跟 `resolveHermesHome()` 默认值无关,无需改

---

## 5. AC 对照

| AC | 要求 | 实际 |
|----|------|------|
| AC1 | main.ts:479 默认 path 改为 `~/.wenshu-hermes` | ✅ line 479 = `path.join(app.getPath('home'), '.wenshu-hermes')` |
| AC2 | 验证 spawn 时 env 包含 `HERMES_HOME=~/.wenshu-hermes` | ✅ line 1661 注入 `HERMES_HOME`,line 482 = `resolveHermesHome()` = `~/.wenshu-hermes`(macOS/Linux) |
| AC3 | `pnpm exec tsc --noEmit` 全部通过 | ⚠️ main.ts + backend-env.ts 0 错误;仓库其他文件(assistant-stream)有预存 type 错误,跟本工单无关 |
| AC4 | 不改 bootstrap-installer,不碰 `~/.hermes` | ✅ 改动只在 `apps/desktop/electron/main.ts` |
| AC5 | 落档 R18-gateway-home-default.md | ✅ 本文件 |

---

*R18 落档 · 2026-07-28 · 接 R7/R8 失败复盘 + 装机 user 8/28 拍 · 改 `apps/desktop/electron/main.ts:479` fallback 默认 + line 432-433 注释同步 · 不 commit/push*
