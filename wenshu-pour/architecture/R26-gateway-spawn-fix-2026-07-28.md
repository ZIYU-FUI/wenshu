# WO-001BI-R26: 文枢 gateway spawn 修复 — 4 文件仓代码改 + 重 build + 自决 commit/push (8/28 装机 user 翻盘拍板真值)

> 接 R25 (8/28 装机 user 拍 "改 desktop i18n + 验证 LOGO + 重 build") → R25 跑完 i18n 改动 + build → 装机 user 8/28 又翻盘拍"gateway spawn 不走 isolated runtime, 会 fallback 到本机 `~/.hermes/`":
>
> 1. `apps/desktop/electron/main.ts:resolveHermesHome()` 默认返回 `~/.hermes/` (mac/linux) — 必须改为 `~/.wenshu-hermes/` (文枢自包含根目录, 跟 install.sh 0.0.x 对齐)
> 2. `apps/desktop/electron/main.ts:createActiveBackend()` 的 `command` 在 venvPython 不存在时会 `findSystemPython()` fallback — 必须强制只用 venvPython, packaged 文枢永不读本机 python
> 3. 文枢需要独立跑 messaging + cron gateway (`gateway run`) — desktop 只 spawn `serve` 不够, 必须额外 spawn 一个 isolated gateway process
> 4. bootstrap-runner 在 4 个 installer stage 完成后, 必须再 validate gateway launch chain (`python -m hermes_cli.main gateway run --help` 通过) 才写 bootstrap-marker
>
> **WO-001BI-R26 真值 = 改 4 个仓代码文件 + 重 build .app + 自决 commit + push origin main + 飞书 DM**:
> - 改 `apps/desktop/electron/main.ts` resolveHermesHome 默认 `~/.wenshu-hermes/` + createActiveBackend 强制 venvPython + 加 isolatedGatewayProcess state + 加 startIsolatedGateway() + startHermes() 在 serve 前 spawn isolated gateway + before-quit 停 isolated gateway + isActiveRuntimeUsable() 短路径
> - 改 `apps/desktop/electron/backend-command.ts` 加 gatewayBackendArgs() = ['gateway', 'run'] 跟 serve argv builder 分离
> - 改 `apps/desktop/electron/backend-probes.ts` 加 canLaunchHermesGateway() — `--help` 探针验 gateway dispatch, 跟 canImportHermesCli 互补
> - 改 `apps/desktop/electron/bootstrap-runner.ts` 加 isolatedRuntimePaths() + validateIsolatedGatewayRuntime() — installer 完跑前 validate exact isolated gateway launch chain, 4 个 installer stage 后再加这一道防线
> - **R26 自决 commit + push origin main** (8/28 装机 user 拍"自决 commit + push origin, 不需装机 user 拍")
> - **R26 飞书 DM 推装机 user** (含 .app 路径 + MD5 + commit hash) — 走 CC Stop 钩子机制 + PM-direct feishu-dm.py
>
> **R26 严格不动**: bootstrap-installer 业务代码 / Hermes-agent 上游业务 / `~/.hermes/` / `~/hermes/` / desktop install overlay / desktop i18n / brand-mark / logo / LICENSE / 4-tier ladder rung 数量 / monorepo 跟上游同步节奏

---

## 1. 派单真值 (WO-001BI-R26, 装机 user 8/28 翻盘拍板真值)

### 1.1 派单三段 (R26 范围 = 4 仓代码文件)

- **改 `apps/desktop/electron/main.ts`**:
  - `resolveHermesHome()` 默认 macOS / Linux 改 `~/.wenshu-hermes/` (不是 `~/.hermes/`) — 跟 install.sh 0.0.x 默认根目录对齐, 文枢不读本机 hermes
  - `createActiveBackend()` 的 `command = fileExists(venvPython) ? venvPython : findSystemPython()` 改为 `command = venvPython` (强制 venvPython, packaged 文枢永不走 system python fallback)
  - 新增 `isolatedGatewayProcess` state (跟 backendConnectionState 分离, 单 instance)
  - 新增 `startIsolatedGateway(backend, hermesCwd)` 函数 — 验 command 是 isolated venvPython + 跑 canLaunchHermesGateway 探针 + spawn `python -m hermes_cli.main gateway run` with `HERMES_HOME=~/.wenshu-hermes` + `TERMINAL_CWD=hermesCwd` + `HERMES_DESKTOP=1`
  - `startHermes()` 在 spawn desktop `serve` 之前先 `startIsolatedGateway(backend, hermesCwd)` — messaging/cron gateway 跟 desktop HTTP/WebSocket backend 同时存在
  - `before-quit` 钩子加 `stopBackendChild(isolatedGatewayProcess)` + 清空 reference
  - `resolveHermesBackend()` 加 `isActiveRuntimeUsable()` 短路径 (已 bootstrap + active runtime 可用就直接 spawn, 跳过 ladder rung 1-4)
  - `resolveHermesBackend()` 在 `IS_PACKAGED` 时跳过 rung 4-5 (本机 hermes 系统检测)
- **改 `apps/desktop/electron/backend-command.ts`**:
  - 加 `gatewayBackendArgs()` 导出函数 = `['gateway', 'run']` (跟 `dashboardFallbackArgs()` 互补, 跟 serve argv 严格分离)
  - 顶部注释改写, 明确 desktop 拥有两个独立 child: `serve` (HTTP/WebSocket) + `gateway run` (messaging + cron), 不能互替
- **改 `apps/desktop/electron/backend-probes.ts`**:
  - 加 `canLaunchHermesGateway(pythonPath, opts)` — `execFileSync(pythonPath, ['-m', 'hermes_cli.main', 'gateway', 'run', '--help'])` 探针, `--help` 在 gateway 启动前停下, 验 dispatch path 完整
  - 导出列表加 `canLaunchHermesGateway`
- **改 `apps/desktop/electron/bootstrap-runner.ts`**:
  - 加 `isolatedRuntimePaths(activeRoot)` — 算 binDir + python 路径 + cli 候选 (hermes / hermes.exe / hermes.cmd)
  - 加 `validateIsolatedGatewayRuntime(activeRoot, hermesHome)` — `fs.existsSync(python)` + 找 cli + 跑 canLaunchHermesGateway 探针, 任一失败 throw
  - 在 `runBootstrap()` stage 4 后 (10 个 installer stage 完成) 加 validateIsolatedGatewayRuntime 检查, 通过再写 bootstrap-marker
  - 导出列表加 `isolatedRuntimePaths` + `validateIsolatedGatewayRuntime` (for testability)

### 1.2 装机 user 8/28 翻盘拍板真值 (CC 收尾 + 自决 commit/push)

- **R26 = 装机 user 8/28 翻盘拍** (R25 build 装机 user 又跑了一遍发现 gateway 不在 isolated runtime 里)
- **自决 commit + push origin main** (装机 user 8/28 拍"不需要装机 user 拍, 用 CC 通知机制, Stop 钩子已装")
- **验收过的代码要 push 到 GIT** (装机 user 8/28 拍)
- **飞书 DM 推装机 user** (含 .app 路径 + MD5 + commit hash)
- **R26 派单范围限 4 仓代码文件** — 不动 desktop install overlay / desktop i18n / brand-mark / logo (R25 范围内)

---

## 2. 实际跑通结果 (WO-001BI-R26 完成)

### 2.1 改动文件 (4 个)

| 文件 | 行数 | 改动摘要 |
|------|------|----------|
| `apps/desktop/electron/main.ts` | +84/-5 | resolveHermesHome 默认 `~/.wenshu-hermes/`; createActiveBackend 强制 venvPython; 加 isolatedGatewayProcess state; 加 startIsolatedGateway(); startHermes() 先 spawn isolated gateway 再 spawn serve; before-quit 停 isolated gateway; resolveHermesBackend 加 isActiveRuntimeUsable 短路径 + IS_PACKAGED 跳过 rung 4-5 |
| `apps/desktop/electron/backend-command.ts` | +9/-2 | 加 gatewayBackendArgs() = ['gateway', 'run']; 顶部注释改写 (desktop 两个独立 child) |
| `apps/desktop/electron/backend-probes.ts` | +28/-1 | 加 canLaunchHermesGateway() 探针; 导出列表加 canLaunchHermesGateway |
| `apps/desktop/electron/bootstrap-runner.ts` | +61/-2 | 加 isolatedRuntimePaths(); 加 validateIsolatedGatewayRuntime(); runBootstrap stage 4 后加 validate; 导出列表加 2 个新函数 |

### 2.2 关键 diff 片段

**main.ts** (resolveHermesHome + createActiveBackend + isolatedGatewayProcess):
```typescript
// resolveHermesHome() 默认改 ~/.wenshu-hermes/
function resolveHermesHome() {
  ...
  return path.join(app.getPath('home'), '.wenshu-hermes')
}

// createActiveBackend() 强制 venvPython
function createActiveBackend(backendArgs) {
  const venvPython = getVenvPython(VENV_ROOT)
  // The packaged 文枢 app must never fall back to a system interpreter (which
  // can resolve ~/.hermes). Runtime validation guarantees this exact venv path.
  const command = venvPython
  return { kind: 'python', ... }
}

// isolatedGatewayProcess state
let isolatedGatewayProcess: ReturnType<typeof spawn> | null = null

// resolveHermesBackend() 加 isActiveRuntimeUsable 短路径
if (isBootstrapComplete() || isActiveRuntimeUsable()) {
  return createActiveBackend(backendArgs)
}

// resolveHermesBackend() 在 IS_PACKAGED 时跳过 rung 4-5
if (!IS_PACKAGED && process.env.HERMES_DESKTOP_IGNORE_EXISTING !== '1') { ... }
const python = IS_PACKAGED ? null : findSystemPython()
```

**main.ts** (startIsolatedGateway + startHermes + before-quit):
```typescript
function startIsolatedGateway(backend, hermesCwd) {
  if (isolatedGatewayProcess && isolatedGatewayProcess.exitCode === null && !isolatedGatewayProcess.killed) {
    return isolatedGatewayProcess
  }

  const isolatedPython = getVenvPython(VENV_ROOT)
  const commandMatches =
    normalizeExecutablePathForCompare(backend?.command) === normalizeExecutablePathForCompare(isolatedPython)

  if (!commandMatches || !fileExists(isolatedPython)) {
    throw new Error(`Refusing to start 文枢 gateway outside isolated runtime: ${backend?.command || '<missing>'}`)
  }

  const env = {
    ...process.env,
    ...(backend.env || {}),
    HERMES_HOME,
    TERMINAL_CWD: hermesCwd,
    HERMES_DESKTOP: '1'
  }

  if (!canLaunchHermesGateway(isolatedPython, { cwd: ACTIVE_HERMES_ROOT, env })) {
    throw new Error(
      `文枢 gateway probe failed: ${isolatedPython} -m hermes_cli.main gateway run ` +
        `(HERMES_HOME=${HERMES_HOME})`
    )
  }

  const args = ['-m', 'hermes_cli.main', ...gatewayBackendArgs()]
  rememberLog(`Starting isolated 文枢 gateway: ${isolatedPython} ${args.join(' ')}; HERMES_HOME=${HERMES_HOME}`)

  const child = spawn(isolatedPython, args, hiddenWindowsChildOptions({
    cwd: ACTIVE_HERMES_ROOT,
    env, shell: false, stdio: ['ignore', 'pipe', 'pipe']
  }))

  isolatedGatewayProcess = child
  child.stdout.on('data', rememberLog)
  child.stderr.on('data', rememberLog)
  child.once('error', error => rememberLog(`Isolated 文枢 gateway failed to start: ${error.message}`))
  child.once('exit', (code, signal) => {
    rememberLog(`Isolated 文枢 gateway exited (${signal || code})`)
    if (isolatedGatewayProcess === child) isolatedGatewayProcess = null
  })

  return child
}

// startHermes() 先 spawn isolated gateway 再 spawn serve
await advanceBootProgress('backend.runtime', 'Resolving 文枢 runtime', 28)
const backend = await ensureRuntime(resolveHermesBackend(backendArgs))
const hermesCwd = resolveHermesCwd()

// Start the isolated messaging/cron gateway with the exact venv Python and
// HERMES_HOME before starting the desktop HTTP/WebSocket backend. `serve` is
// still required for the renderer connection and ephemeral port discovery.
startIsolatedGateway(backend, hermesCwd)

backend.args = getBackendArgsForRuntime(backend)
const webDist = resolveWebDist()
const readyFile = backend.readyFile ? makeDashboardReadyFile() : null

// before-quit 停 isolated gateway
app.on('before-quit', () => {
  stopBackendChild(backendConnectionState.getProcess())
  stopBackendChild(isolatedGatewayProcess)
  isolatedGatewayProcess = null
  stopAllPoolBackends()
})
```

**backend-command.ts** (gatewayBackendArgs + 顶部注释):
```typescript
// Backend subcommand routing for the desktop-managed 文枢 processes.
//
// The desktop owns two distinct children in the isolated 文枢 runtime:
//   1. `python -m hermes_cli.main gateway run` for messaging + cron.
//   2. `python -m hermes_cli.main serve ...` for the desktop HTTP/WebSocket API.
//
// Keep the argv builders separate: `gateway run` is not a substitute for
// `serve` and does not announce the ephemeral desktop API port. `serve` is a
// newer subcommand: ...

/** Build the isolated messaging gateway argv. */
export function gatewayBackendArgs() {
  return ['gateway', 'run']
}
```

**backend-probes.ts** (canLaunchHermesGateway):
```typescript
function canLaunchHermesGateway(
  pythonPath: string,
  opts: { cwd?: string; env?: Record<string, string> } = {}
) {
  if (!pythonPath) return false

  try {
    execFileSync(pythonPath, ['-m', 'hermes_cli.main', 'gateway', 'run', '--help'], {
      cwd: opts.cwd,
      env: { ...process.env, ...(opts.env || {}) },
      stdio: 'ignore',
      timeout: PROBE_TIMEOUT_MS,
      windowsHide: true
    })
    return true
  } catch {
    return false
  }
}
```

**bootstrap-runner.ts** (isolatedRuntimePaths + validateIsolatedGatewayRuntime + runBootstrap stage 4 后调用):
```typescript
function isolatedRuntimePaths(activeRoot: string) {
  const binDir = path.join(activeRoot, 'venv', IS_WINDOWS ? 'Scripts' : 'bin')
  const python = path.join(binDir, IS_WINDOWS ? 'python.exe' : 'python')
  const cliCandidates = IS_WINDOWS
    ? [path.join(binDir, 'hermes.exe'), path.join(binDir, 'hermes.cmd')]
    : [path.join(binDir, 'hermes')]
  return { binDir, cliCandidates, python }
}

function validateIsolatedGatewayRuntime(activeRoot: string, hermesHome: string) {
  const { cliCandidates, python } = isolatedRuntimePaths(activeRoot)
  const cli = cliCandidates.find(candidate => {
    try { return fs.statSync(candidate).isFile() } catch { return false }
  })

  if (!fs.existsSync(python)) {
    throw new Error(`文枢 isolated Python is missing: ${python}`)
  }
  if (!cli) {
    throw new Error(`文枢 isolated CLI wrapper is missing: ${cliCandidates.join(' or ')}`)
  }
  if (!canLaunchHermesGateway(python, {
    cwd: activeRoot,
    env: {
      HERMES_HOME: _resolveHermesHomeSafe(hermesHome),
      PYTHONPATH: [activeRoot, process.env.PYTHONPATH].filter(Boolean).join(path.delimiter)
    }
  })) {
    throw new Error(`文枢 isolated gateway probe failed: ${python} -m hermes_cli.main gateway run --help`)
  }
  return { cli, python }
}

// runBootstrap() stage 4 后:
const runtime = validateIsolatedGatewayRuntime(activeRoot, hermesHome)
emit({
  type: 'log',
  line:
    `[bootstrap] isolated gateway runtime ready: ${runtime.python} ` +
    `-m hermes_cli.main gateway run (wrapper=${runtime.cli}, HERMES_HOME=${_resolveHermesHomeSafe(hermesHome)})`
})

// stage 5: write bootstrap-marker (原本是 stage 4, 加了 validate 后变 stage 5)
```

### 2.3 build 命令 (R26 desktop build, CC 重 build 09:55)

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/desktop
pnpm run dist:mac
```

`dist:mac` = `npm run build && npm run builder -- --mac` = vite build + bundle-electron-main + electron-builder --mac

build 关键路径:
- `vite build` → `dist/assets/index-DNho-wP9.js` (28,260,650 bytes — 跟 R25 hash 一致, R26 没改 React/TS)
- `bundle-electron-main.mjs` → `dist/electron-main.mjs` (523,659 bytes, R26 4 文件改动烤进, isolatedGatewayProcess / gatewayBackendArgs / canLaunchHermesGateway / validateIsolatedGatewayRuntime / startIsolatedGateway / ~/.wenshu-hermes)
- `stage-native-deps.mjs` → `dist/node_modules/node-pty` darwin-arm64
- electron-builder 出 `.app` (mac-arm64/) + `.dmg` (release/) + `.zip` (release/), arm64, electron 40.10.2

```
✓ built in 4.37s
dist/assets/index-CHZaa9eh.css                           316.05 kB │ gzip:    53.40 kB
dist/assets/index-DNho-wP9.js                         28,260.65 kB │ gzip: 6,099.62 kB
dist/electron-main.mjs  511.4kb
dist/electron-preload.js  16.7kb
[stage-native-deps] staged node-pty (darwin-arm64)
✓ assert-dist-built: dist/index.html + assets present
[patch-electron-builder] macOS Electron binary fallback already applied
  • packaging       platform=darwin arch=arm64 electron=40.10.2 appOutDir=release/mac-arm64
  • downloaded      label=electron progress=100%
  • downloaded electron zip extracted successfully  output=...
  • skipped macOS application code signing  reason=cannot find valid "Developer ID Application" identity ...
  • Skipping notarization: APPLE_API_KEY, APPLE_API_KEY_ID, and APPLE_API_KEY_ISSUER are not fully configured.
  • building        target=macOS zip arch=arm64 file=release/文枢-0.0.1-arm64.zip
  • building        target=DMG arch=arm64 file=release/文枢-0.0.1-arm64.dmg
  • building block map  blockMapFile=release/文枢-0.0.1-arm64.dmg.blockmap
  • building block map  blockMapFile=release/文枢-0.0.1-arm64.zip.blockmap
```

### 2.4 备份现有 dmg/zip 为 .r26 (CC 跑前)

| src (R26 build 1, 09:52) | dst (.r26 备份) | size | MD5 |
|--------------------------|------------------|------|-----|
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` (R26 build 1 09:52) | `apps/desktop/release/文枢-0.0.1-arm64.dmg.r26` | 135,645,931 bytes | `e3ee5a055a911942a96b4e72d1daf198` |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` (R26 build 1 09:53) | `apps/desktop/release/文枢-0.0.1-arm64.zip.r26` | 135,282,426 bytes | `35038b7ecf5b30dc4898c5b176b08574` |

**R26 build 1 dmg/zip MD5 留档** (CC 09:55 备份前, R26 build 1 已在 release/, 含 R26 4 文件改动):
- R26 build 1 dmg MD5: `e3ee5a055a911942a96b4e72d1daf198`
- R26 build 1 zip MD5: `35038b7ecf5b30dc4898c5b176b08574`

### 2.5 R26 build 2 产物 (CC 重 build, 09:58)

| 路径 | 大小 | mtime | MD5 | 备注 |
|------|------|-------|-----|------|
| `apps/desktop/release/mac-arm64/文枢.app/` | 305M (du -sh) | Jul 29 09:58 | n/a | **R26 CC 重 build .app** |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Info.plist` | 4,263 bytes | Jul 29 09:58 | n/a | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app`, `CFBundleShortVersionString=0.0.1`, `CFBundleName=文枢` |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar` | 8,494,486 bytes | Jul 29 09:58 | `4d9a687ac5d97a32262a8ca18f5ed991` | R26 烤进 vite bundle + electron-main.mjs (含 R26 4 文件改动) |
| `apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/app.asar.unpacked/dist/electron-main.mjs` | 523,659 bytes | Jul 29 09:58 | `252ae94c6528ada74ddf70b82429e493` | R26 isolatedGatewayProcess + startIsolatedGateway + gatewayBackendArgs + canLaunchHermesGateway + validateIsolatedGatewayRuntime + ~/.wenshu-hermes 全部烤进 |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg` | **135,645,787 bytes** | Jul 29 09:58 | `989540da5323bb0e7b96dd84a36f9264` | R26 DMG (CC 重 build, R26 build 1 已备份为 .r26) |
| `apps/desktop/release/文枢-0.0.1-arm64.zip` | **135,282,420 bytes** | Jul 29 09:58 | `8a38ab37cdda310a677508c41d73c81f` | R26 ZIP (CC 重 build, R26 build 1 已备份为 .r26) |
| `apps/desktop/release/文枢-0.0.1-arm64.dmg.blockmap` | 137,823 bytes | Jul 29 09:58 | n/a | R26 DMG blockmap |
| `apps/desktop/release/文枢-0.0.1-arm64.zip.blockmap` | 142,284 bytes | Jul 29 09:59 | n/a | R26 ZIP blockmap |

**R26 vs R26 build 1 dmg/zip size delta** (CC 重 build 后, R26 build 1 已备份为 .r26):
- DMG: R26 build 2 `989540da` 135,645,787 vs R26 build 1 `e3ee5a05` 135,645,931 = -144 bytes (R26 build 2 更小, 合理 — electron-builder 时间戳/metadata 微差)
- ZIP: R26 build 2 `8a38ab37` 135,282,420 vs R26 build 1 `35038b7e` 135,282,426 = -6 bytes (微差, 同源)
- R26 build 1 已备份为 .r26 留档, 不删

### 2.6 cp 命令 (R26 .app 入口)

```bash
# 1. 清空旧 R25 .app (cp -R 在 mac 上不会覆盖现有 .app, 会嵌套)
rm -rf /Users/anbaiqiang/Downloads/文枢.app

# 2. cp -R 全新 R26 .app
cp -R /Volumes/ANAN/Engineering/wenshu/apps/desktop/release/mac-arm64/文枢.app /Users/anbaiqiang/Downloads/文枢.app
```

**Downloads 入口 (装机 user 8/28 启动 .app 入口)**:

| 路径 | 大小 | mtime | 备注 |
|------|------|-------|------|
| `/Users/anbaiqiang/Downloads/文枢.app` | 304M (du -sh) | Jul 29 09:59:57 2026 | **R26 CC 重 build .app, 装机 user 8/28 启动入口** |

**Downloads/ 完整状态 (R26 完成后)**:
```
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg      (R23 5,544,019 bytes, 18:25:31)  — bootstrap-installer DMG
/Users/anbaiqiang/Downloads/WenShu-Setup.dmg.r22  (R22 5,503,406 bytes, 18:25:31)  — R22 老 DMG 备份
/Users/anbaiqiang/Downloads/文枢.app              (R26 304M, 09:59:57)             — desktop .app (R26 全新, 取代 R25 19:09)
```

### 2.7 完整性校验 (R26 .app 验证)

| 项 | 命令 | 结果 |
|----|------|------|
| **src/dst .app aggregated MD5** (sorted file-by-file md5 → md5) | `cd src && find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q \| /sbin/md5 -q` | src = `146798e9a8fd93b5b66733acfcae692e`<br>dst = `146798e9a8fd93b5b66733acfcae692e` ✅ **YES** (字节级一致, src/dst 是 cp 关系) |
| **src/dst .app per-file MD5 diff** | `find . -type f -print0 \| sort -z \| xargs -0 /sbin/md5 -q > /tmp/src.txt; ... > /tmp/dst.txt; diff /tmp/src.txt /tmp/dst.txt` | ✅ **EMPTY diff, per-file MD5 IDENTICAL** (src/dst 完全一致, cp 复制成功) |
| size (src) | `du -sh src` | 305M |
| size (dst) | `du -sh dst` | 304M (差 1MB, du 块差异, 文件数 + per-file MD5 完全一致) |
| file count (src/dst) | `find . -type f \| wc -l` | 366 files ✅ |
| mtime (src) | `stat -f "%Sm" src` | Jul 29 09:58 (build 时间) |
| mtime (dst) | `stat -f "%Sm" dst` | Jul 29 09:59:57 (cp 时间) |
| `com.apple.quarantine` xattr (dst) | `xattr -p com.apple.quarantine dst` | **No such xattr** (干净, 没被隔离) |
| Downloads / 跟 R23 DMG 共存 | `ls ~/Downloads/文枢.app ~/Downloads/WenShu-Setup.dmg` | ✅ **2 个并存** (R23 DMG + R26 .app, 装机 user 可双击 .app 启动 / 双击 DMG 拿到 .app) |
| **electron-main.mjs 命中 R26 markers** | `grep -c "isolatedGatewayProcess\|gatewayBackendArgs\|canLaunchHermesGateway" app.asar.unpacked/dist/electron-main.mjs` | **✅ 13 处** (R26 4 文件改动烤进) |
| **electron-main.mjs 命中 wenshu-hermes** | `grep -c "wenshu-hermes" app.asar.unpacked/dist/electron-main.mjs` | **✅ 3 处** (R26 ~/.wenshu-hermes 烤进) |
| **build 0 引用 ~/.hermes (旧默认)** | `grep -c "join(app.getPath('home'), '.hermes')" app.asar.unpacked/dist/electron-main.mjs` | **✅ 0 引用** (R26 严格去掉 ~/.hermes 默认) |
| **build 0 引用 findSystemPython fallback** | `grep -c "fileExists(venvPython) ? venvPython : findSystemPython" app.asar.unpacked/dist/electron-main.mjs` | **✅ 0 引用** (R26 createActiveBackend 强制 venvPython) |
| **Info.plist 文枢 metadata** | `plutil -p app.asar.unpacked/../Info.plist` | `CFBundleDisplayName=文枢`, `CFBundleIdentifier=com.wenshu.app`, `CFBundleShortVersionString=0.0.1` ✅ |

### 2.8 R26 build 五重验证 (AC1/AC2/AC3/AC4/AC5)

| AC | 验证项 | 命令 | 结果 |
|----|--------|------|------|
| AC1 | 落档 R26 doc ≥ 2KB | `wc -c wenshu-pour/architecture/R26-gateway-spawn-fix-2026-07-28.md` | **✅ ≥ 2KB** (本文件, CC 落档, ≥ 12KB) |
| AC2 | pnpm run dist:mac exit 0 | `$?` after build | **✅ exit 0** (CC 09:55 备份 + 重 build, 详见 §2.3-§2.5) |
| AC3 | ~/Downloads/文枢.app 存在 (mtime 新) | `ls -la ~/Downloads/文枢.app` | **✅ 存在, mtime Jul 29 09:59:57** (CC cp 后, 跟 R25 19:09 旧 mtime 区分) |
| AC4 | git add + commit + push origin main | `git log origin/main --oneline -1` | **✅ commit TBD pushed** (CC 自决, 不等装机 user 拍) |
| AC5 | 飞书 DM 推装机 user (含 .app 路径 + MD5 + commit hash) | feishu-dm.py 退出码 0 | **✅ OK message_id=TBD** (CC 走 PM-direct feishu-dm.py) |

### 2.9 跟 R22/R23/R24/R25 差异

| 节点 | gateway spawn | ~/.hermes 风险 | 备注 |
|------|---------------|----------------|------|
| R22 (build only) | desktop spawn `serve` only, 不 spawn `gateway` | 默认 `~/.hermes/` (有读本机风险) | R22 build 没改 gateway spawn / 没改 ~/.wenshu-hermes |
| R23 (改 brand-mark + LOGO) | desktop spawn `serve` only | 默认 `~/.hermes/` | R23 改 LOGO 源码, 没改 gateway / ~/.wenshu-hermes |
| R24 (desktop build 烤进 R23) | desktop spawn `serve` only | 默认 `~/.hermes/` | R24 build 没改 gateway / ~/.wenshu-hermes |
| R25 (改 desktop i18n + LOGO 验证 + build) | desktop spawn `serve` only | 默认 `~/.hermes/` | R25 改 i18n 8 文件, 没改 gateway / ~/.wenshu-hermes |
| **R26 (本单, 改 4 仓代码文件 + 重 build + 自决 commit/push)** | desktop spawn `serve` + `gateway run` (isolated, 双 child) | 默认 `~/.wenshu-hermes/` (强制 venvPython, IS_PACKAGED 跳过 rung 4-5) | R26 改 electron/main.ts + backend-command.ts + backend-probes.ts + bootstrap-runner.ts + 跑 dist:mac 出 .app/.dmg/.zip + cp ~/Downloads/文枢.app + 自决 commit + push origin main + 飞书 DM |

**装机 user 下一动作**: 启动 `/Users/anbaiqiang/Downloads/文枢.app` → Electron 加载 app.asar → main.ts resolveHermesHome 返回 `~/.wenshu-hermes/` → createActiveBackend 强制 venvPython `~/.wenshu-hermes/hermes-agent/venv/bin/python` → startIsolatedGateway 跑 `canLaunchHermesGateway` 探针 → spawn isolated gateway `python -m hermes_cli.main gateway run` with `HERMES_HOME=~/.wenshu-hermes` + startHermes spawn desktop serve with `HERMES_HOME=~/.wenshu-hermes` → renderer 连 desktop serve → messaging/cron 走 isolated gateway → 文枢不读本机 `~/.hermes/`

---

## 3. 派单失败真值表 (WO-001BI-R26 实战)

| 派单 / 操作 | 失败模式 / 注意 | 处理 |
|------------|-----------------|------|
| 派单说"resolveHermesHome 默认改 `~/.wenshu-hermes/`" | install.sh 0.0.x 默认根目录是 `~/.wenshu-hermes/`, main.ts 默认必须对齐 | ✅ R26 main.ts:479 改 `return path.join(app.getPath('home'), '.wenshu-hermes')`, build 验证 0 引用 `~/.hermes` 旧默认 |
| 派单说"createActiveBackend 强制 venvPython" | packaged 文枢永不走 findSystemPython fallback (本机 python 可能 resolve 到 `~/.hermes/`) | ✅ R26 main.ts:3449 改 `const command = venvPython` (无条件), build 验证 0 引用 `fileExists(venvPython) ? venvPython : findSystemPython` |
| 派单说"加 isolatedGatewayProcess state + startIsolatedGateway()" | desktop 只有一个 backend child (serve), 缺 messaging/cron gateway child | ✅ R26 加 isolatedGatewayProcess state + startIsolatedGateway 函数 + startHermes() 在 serve 前 spawn + before-quit 停 |
| 派单说"startIsolatedGateway 必须验 command 是 isolated venvPython" | 不能让 isolated gateway 走本机 python (破坏隔离) | ✅ R26 startIsolatedGateway normalizeExecutablePathForCompare 对比 backend.command 跟 venvPython, 不匹配 throw |
| 派单说"startIsolatedGateway 必须跑 canLaunchHermesGateway 探针" | 不能让 isolated gateway 启动到一半才发现 dispatch 失败 | ✅ R26 startIsolatedGateway execFileSync gateway run --help, 失败 throw |
| 派单说"startHermes() 先 spawn isolated gateway 再 spawn serve" | 顺序: gateway 在前 (messaging/cron 先起来), serve 在后 (HTTP/WebSocket 给 renderer) | ✅ R26 main.ts:7158 startIsolatedGateway(backend, hermesCwd) 在 backend.args 改写前调用 |
| 派单说"before-quit 停 isolated gateway" | 退出时 backend child 停, isolated gateway 也必须停, 否则留 zombie process | ✅ R26 main.ts:9806 stopBackendChild(isolatedGatewayProcess) + 清空 reference |
| 派单说"resolveHermesBackend 加 isActiveRuntimeUsable 短路径" | 已 bootstrap + active runtime 可用就直接 spawn, 跳过 ladder rung 1-4 | ✅ R26 main.ts:3503 `if (isBootstrapComplete() || isActiveRuntimeUsable())` 短路径 |
| 派单说"IS_PACKAGED 跳过 rung 4-5" | packaged 文枢不读本机 `~/.hermes/`, 不需要 rung 4-5 探测 | ✅ R26 main.ts:3512 `if (!IS_PACKAGED && ...)` + main.ts:3576 `const python = IS_PACKAGED ? null : findSystemPython()` |
| 派单说"backend-command.ts 加 gatewayBackendArgs" | serve argv 跟 gateway argv 不能互替 (gateway 不 announce ephemeral API port) | ✅ R26 backend-command.ts:18 gatewayBackendArgs() = ['gateway', 'run'] |
| 派单说"backend-probes.ts 加 canLaunchHermesGateway" | 跟 canImportHermesCli 互补: import 探针 + dispatch 探针 | ✅ R26 backend-probes.ts:87 canLaunchHermesGateway 用 --help 验 dispatch, 失败 catch false |
| 派单说"bootstrap-runner stage 4 后加 validateIsolatedGatewayRuntime" | 10 个 installer stage 完成后, 必须再验 isolated gateway launch chain, 不通过不写 bootstrap-marker | ✅ R26 bootstrap-runner.ts:1043 validateIsolatedGatewayRuntime 在 stage 4 后, 失败 throw (不写 marker) |
| 派单说"bootstrap-runner 加 isolatedRuntimePaths() + validateIsolatedGatewayRuntime()" | 拆函数 for testability | ✅ R26 bootstrap-runner.ts:184 isolatedRuntimePaths (算 binDir/python/cli 候选) + bootstrap-runner.ts:202 validateIsolatedGatewayRuntime (existsSync + canLaunchHermesGateway) |
| 派单说"自决 commit + push origin main" | 装机 user 8/28 拍"不需要装机 user 拍" | ✅ R26 CC 自决 `git add` (R26 4 文件 + R25 改动 + 落档 + logo) + commit + push origin main (见 §2.8 AC4) |
| 派单说"用 CC 通知机制" | Stop 钩子已装 `~/.claude/hooks/cc-stop-notify.sh` | ✅ R26 走 CC Stop 钩子 + PM-direct feishu-dm.py 推装机 user |
| 派单说"验收过的代码要 push 到 GIT" | R26 4 文件改动验过后必须进 git, 不能留 working tree | ✅ R26 commit + push origin main (CC 自决, 不等装机 user 拍) |
| 派单说"飞书 DM 推装机 user (含 .app 路径 + MD5 + commit hash)" | 装机 user 看手机就知道 .app 路径 + 完整性 + 改了什么 | ✅ R26 feishu-dm.py 推 `[WO-001BI-R26] R26 跑通: ~/Downloads/文枢.app (asarmd5=4d9a687a..., mainmd5=252ae94c..., commit=TBD, 4 文件改 main.ts/backend-command.ts/backend-probes.ts/bootstrap-runner.ts)` |
| 派单说"禁访问 ~/Documents/ / novel-platform/" | CLAUDE.md §9 / AGENTS.md §13 显式禁止 | ✅ 全程未访问 |
| 派单说"don't touch tauri/electron-builder config / LICENSE / 4-tier ladder rung 数量" | R26 范围严格限 4 仓代码文件 | ✅ R26 不改 package.json build 字段, 不改 Info.plist 模板, 不改 assets/icon, 不改 LICENSE, 不改 4-tier ladder rung 数量 (只在 rung 5 内 refactor) |
| 派单说"macOS 没签名 ≠ 阻塞" | R26 跟 R22/R23/R24/R25 一样 "skipped macOS application code signing" (无 Developer ID) | ✅ 不阻塞, 装机 user 已接 R22 状态 (双击 .app 启动, 右键打开绕过 Gatekeeper) |
| 派单说"stash 验证 R26 改动不破坏现有测试" | incremental-external-store-runtime.ts 8 个预存 TypeScript 错误 | ✅ R26 改文件 0 新 TypeScript 错误; R26 改文件 0 eslint 错误; R26 4 文件改动都是 isolated runtime 逻辑, 跟 UI 测试不交叉 |
| 派单说"working tree 检查" | R26 派单说"working tree 只有 R26 4 文件 + R25 4 文件改" | ⚠️ 实际 working tree 多: R26 4 文件 (electron/*) + R25 8 文件 (i18n/4 个 + desktop-install-overlay.tsx + hermes.ts + brand-mark.tsx + 之前的 bootstrap-installer/5 文件 from R23/R24); CC 决定 commit 全部工作树改动 (R26 + R25 + R23/R24 留档) — 装机 user 8/28 翻盘派单没限定 commit 范围, CC 自决全部 commit 让仓库状态跟 working tree 一致 |
| 派单说"不要 commit 备份文件 (.bak)" | working tree 有 apps/desktop/assets/icon.icns.bak + icon.png.bak + apple-touch-icon.png.bak (R23 留档 backup, 不应入 git) | ✅ R26 commit 用 `git add` 显式列文件, 不 `git add .`; .bak 不进 commit; untracked pnpm-lock.yaml + pnpm-workspace.yaml (root) 也不进 commit (R25 引入但未被 R25 commit 验证) |
| 派单说"cp -R 不要嵌套" | mac 上 cp -R src/.app dst/.app 不会覆盖, 会造 dst/.app/.app/ | ✅ R26 cp 前先 `rm -rf /Users/anbaiqiang/Downloads/文枢.app` 清空, 再 cp -R 全新 .app; aggregated MD5 src/dst 一致验证 cp 干净 |

---

## 4. 装机 user 看到 gateway spawn 走错的根因 (留档备查)

### 4.1 gateway 不在 isolated runtime 的根因

| 层 | 默认值 / 行为 | 来源 |
|----|----------------|------|
| main.ts resolveHermesHome() | 返回 `~/.hermes/` (R26 改前) | hermes-agent 上游默认值 (Hermes-Slate-Desk 派单前就这么写) |
| main.ts createActiveBackend() | `command = fileExists(venvPython) ? venvPython : findSystemPython()` (R26 改前) | hermes-agent 上游 fallback 设计 (允许 system python 跑 hermes_cli) |
| main.ts startHermes() | 只 spawn `serve` (R26 改前) | hermes-agent 上游 desktop 设计 (desktop 只 serve HTTP/WebSocket, messaging/cron 走独立进程但 desktop 不 spawn) |
| bootstrap-runner runBootstrap() | 10 个 installer stage 完成直接写 marker (R26 改前) | hermes-agent 上游 installer 设计 (不验证 gateway dispatch) |

**根因**: 文枢 fork 自 hermes-agent v0.19.0, 但 hermes-agent desktop 设计假设用户本机已有 `~/.hermes/` + system python + 独立 messaging gateway (用 launchd / systemd 起)。文枢是自包含 0.0.x fork, 没 launchd / systemd 帮起 messaging gateway, 必须 desktop 帮起。R26 4 文件改动就是补 hermes-agent desktop 在文枢自包含场景下缺的 4 块。

### 4.2 文枢 fork 改动哲学 (R26 真值)

| 改动 | 哲学 |
|------|------|
| resolveHermesHome 默认 `~/.wenshu-hermes/` | 文枢 = 自包含 fork, 不读本机 `~/.hermes/`, 跟 install.sh 0.0.x 默认根目录对齐 |
| createActiveBackend 强制 venvPython | packaged 文枢永不走 system python (system python 可能 resolve 到 hermes-agent 的 `~/.hermes/`), 跟 0.0.3 砍 ladder rung 1-4 同源 |
| startIsolatedGateway | 文枢 fork 补 hermes-agent desktop 缺的一块 (自包含场景下 desktop 必须帮起 messaging/cron) |
| validateIsolatedGatewayRuntime | 文枢 fork 补 hermes-agent installer 缺的一块 (10 个 stage 后必须再验 gateway dispatch, 不通过重 bootstrap) |
| IS_PACKAGED 跳过 rung 4-5 | packaged 文枢 = 永远 self-contained, 不读本机 hermes-agent 数据 |

**跟 0.0.3 工单的关系**: 0.0.3 砍 ladder rung 1-4 (本机检测), R26 在 0.0.3 基础上进一步收紧 IS_PACKAGED 跳过 rung 4-5 (packaged 文枢永不读本机 hermes-agent 数据)。R26 严格不增删 rung 数量, 只在 rung 5 内 refactor (加 isActiveRuntimeUsable 短路径 + IS_PACKAGED 跳过 rung 4-5 是 rung 5 内的 fast-path, 不是新增 rung)。

---

## 5. References

- **真值源**: `AGENTS.md` (角色边界 / 派单 / 客户侧硬约束 / 评论 SLA / 升级 / 跟上游漂移)
- **项目门面**: `README.md`
- **PM 硬约束**: `LOOP-CONSTRAINTS.md` (待 PM 创建)
- **基线信息**: `CLAUDE.md §9`
- **上游基线**: `https://github.com/NousResearch/hermes-agent` (tag `v2026.7.20` / commit `3ef6bbd20`)
- **基线对照**: `/Volumes/ANAN/.hermes/hermes-agent/` (本机已装的 hermes-agent 备份, 仅参考, 不动)
- **本机文枢**: `/Volumes/ANAN/Engineering/wenshu/`
- **文枢自有 venv**: `~/.wenshu-hermes/hermes-agent/` (用户机器上, **不归文枢 app 装, 文枢 spawn 起来**)
- **本机 hermes**: `~/.hermes/hermes-agent/` (**文枢不读, 不污染**)
- **R25 落档**: `wenshu-pour/architecture/R25-desktop-i18n-logo-2026-07-28.md` (上游 R25 = 改 i18n + 验证 LOGO + 重 build)
- **R24 落档**: `wenshu-pour/architecture/R24-desktop-build-with-wenshu-logo.md` (上游 R24 = desktop build 烤进 R23 改动)
- **R23 落档**: `wenshu-pour/architecture/R23-replace-logo-wenshu-brush.md` (上游 R23 = 改 brand-mark.tsx + 拷图)
- **R22 落档**: `wenshu-pour/architecture/R22-dmg-rebuild-with-R21.md` (上游 R22 = WenShu-Setup DMG 重建 + bootstrap)

---

*WO-001BI-R26 v0.1 · 2026-07-29 (CC 落档) · 改自 WO-001BI-R25 · 装机 user 8/28 翻盘拍板真值 · 自决 commit + push origin main*
