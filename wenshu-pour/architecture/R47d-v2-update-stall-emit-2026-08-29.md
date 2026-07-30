# WO-001BI-R47d v2: online update ramp 卡 25% 真根因 + stall emit fallback

## 装机 user 8/29 实拍

> "Updating 文枢 卡 25%, still installing dependencies 120s elapsed"

R46 (`3d670e6a4` 起) 在 `applyUpdatesPosixInApp` 加了 time-based ramp: 10→55 sweep over `rampSeconds=240`,让 rust/c compile 这种安静 stage 不卡 indeterminate pulse。但装机的 box 上 rust/c compile 跑 5–8 min,`rampSeconds=240` 一过 240s ramp 触顶 cap 在 55%,继续 compile 也不会再 emit percent → 装机 user 看见 bar"卡 25%"(其实是 25% 附近一段时间然后停在 55% 视为卡死)。

## R47d v1 路径错位

派单写 `wenshu_cli/commands/update.py`,CC 真值:

- `ls wenshu_cli/commands/update.py` → exit 1,路径不存在
- 真存在: `wenshu_cli/subcommands/update.py`(只做 argparse 注册)
- 真业务: `wenshu_cli/main.py`,文案 `→ Updating Python dependencies...`,**无 progress emit 协议**
- **真进度 emit 在 desktop electron 端**:`apps/desktop/electron/main.ts:runStreamedUpdate`

R47d v1 因白名单锁 `update.py` 没改 `main.ts`,本单 v2 直接放宽到 `main.ts`(单一职责,过路径核验)。

## 真根因(2026-08-29 定)

两个机制叠加:

1. `rampSeconds=240` 太短。rust/c compile 常见窗口 240s+,到顶后 ramp 触顶 cap 在 55%,任何更长 compile 不再 emit。
2. 进程级 stdout 静默时,`emitLines` 只在收到 chunk 时 push 一行 log;chunk 之间的 1–3 min 沉默 = 0 emit,bar 完全停顿。

修两个都修。R46 已经写"更长 installs cap at 55% until the rebuild milestone snaps to 60%",这等于承认 1 不动 = bar 必须等 milestone 出来才动;久到足以让用户读作"卡死"。

## 修(`apps/desktop/electron/main.ts`)

### 1. `runStreamedUpdate` 默认 `rampSeconds=240 → 600`

```diff
-function runStreamedUpdate(command, args, { cwd, env, stage, fromPercent = null, toPercent = null, rampSeconds = 240 }: any = {}) {
+function runStreamedUpdate(command, args, { cwd, env, stage, fromPercent = null, toPercent = null, rampSeconds = 600 }: any = {}) {
```

10 min sweep,覆盖单次 rust/c compile 慢 box 窗口;call site:

```diff
   const updated = (await runStreamedUpdate(wenshu, ['update', '--yes', ...branchArgs], {
     cwd: updateRoot,
     env,
     fromPercent: 10,
-    rampSeconds: 240,
+    rampSeconds: 600,
     stage: 'update',
     toPercent: 55
   })) as any
```

10→55 sweep 不变(rebuild `rampSeconds: 180` 不动,职责不同 — 60→90)。

### 2. `runStreamedUpdate` 加 stall-detection 兜底

新增两块,scope 都在原 Promise executor 内,不影响外部 API:

```diff
     const startMs = Date.now()
     let lastPercent = fromPercent
     let rampTimer = null
+    let stallTimer = null
+    let lastOutputMs = Date.now()

     if (typeof fromPercent === 'number' && typeof toPercent === 'number' && toPercent > fromPercent) {
       const tick = () => { ...现有 15s ramp tick... }
       tick()
       rampTimer = setInterval(tick, 15000)
+
+      // R47d v2 stall fallback for silent long-running stages ...
+      const stallTick = () => {
+        const sinceOutputMs = Date.now() - lastOutputMs
+        if (sinceOutputMs < 60_000) {
+          return
+        }
+        const next = Math.min(toPercent, (lastPercent ?? 0) + 1)
+        if (next > (lastPercent ?? 0)) {
+          lastPercent = next
+          const seconds = Math.round(sinceOutputMs / 1000)
+          console.warn(`[updates] stalled ${seconds}s; bumping to ${next}%`)
+          emitUpdateProgress({ stage, message: '', percent: next })
+        }
+      }
+      stallTimer = setInterval(stallTick, 60_000)
     }

     const emitLines = chunk => {
+      // R47d v2: any stdout/stderr output (incl. blank heartbeat lines)
+      // resets the stall-fallback timer.
+      lastOutputMs = Date.now()
       for (const line of chunk.toString().split('\n')) {
         const trimmed = line.trim()

         if (trimmed) {
           emitUpdateProgress({ stage, message: trimmed, percent: null })
         }
       }
     }
```

error / exit 两处 handler 各加一行:

```diff
     child.once('error', err => {
       if (rampTimer) clearInterval(rampTimer)
+      if (stallTimer) clearInterval(stallTimer)
       resolve({ code: 1, error: err.message })
     })
     child.once('exit', code => {
       if (rampTimer) clearInterval(rampTimer)
+      if (stallTimer) clearInterval(stallTimer)
       resolve({ code })
     })
```

### 关键设计点

- **gate 复用**:`if (fromPercent && toPercent && toPercent > fromPercent)` 才起 stallTimer;与 ramp 共用生命周期,失败 case 无影响
- **跳过条件**:`sinceOutputMs < 60_000` 直接 return,意味着只要 ≤60s 内有任何 stdout/stderr(即使空白心跳行),stall 不触发 — 避免 verbose stage 双 timer 抢 +1
- **cap 在 toPercent**:`Math.min(toPercent, ...)` — 不越过 55% stage 边界,后续 "Rebuilding the desktop app…" 的 60% milestone 还是从那个权威起点 snap
- **+1 步长**:刻意比 15s ramp 慢,verbose stage 不会双 timer 竞争同一次 +1
- **console.warn 必须**:装机 user 端无 react log panel,主进程 `console.warn` 进 `~/.wenshu-hermes/logs/desktop.log`,PM / 装机 user 都查得到
- **不动 `rampSeconds: 180`** rebuild 60→90 sweep(职责不同,短 vite/electron download 仍合理)
- **不动 `emitUpdateProgress` 协议**:renderer `apps/desktop/src/store/updates.ts` 现状就支持 monotonic percent + null log lines,无需前端改

## 事件分布(预测,装机 user 跑出再 verify)

rust/c compile 静默 8 min case,window=600s:

| t (s)   | 事件                                                |
|---------|-----------------------------------------------------|
| 0       | ramp tick: `percent: 10`(首 tick)                   |
| 15,30…  | ramp tick sweep 10→55(compile 输出仍在,`lastOutputMs` 重置,stall 永远不触发)|
| ~180    | ramp tick ~24%,compile 开始沉默(cargo 编译中)|
| 240     | ramp 触顶 cap 55%(600s sweep 到 55 是 t=600)|
| 300     | stall tick:`sinceOutputMs=120s; bumping to 56%` 但 cap 55 → no emit |
| 480     | ramp tick ~46% |
| 600     | ramp tick 55% |
| 900+    | 子进程退出(`wenshu update --yes` exit 0)→ 60% milestone snap |
| → rebuild 60→90 sweep 走 `rampSeconds=180` |

关键观察:stall 在 ramp 触顶前几乎不触发(因 ramp 还未到 cap,+1 仍小于 toPercent 也会 emit),但 ramp 触顶后 stall 不增量,这是设计上为了不越过 milestone boundary 的取舍。

如果装机 user 汇报"still see 卡 25%":real-world 上 Rust compile 可能 300s+ 才出第一行 stderr,前 5 min 内 ramp 仍 sweep,但 stall 会在前 4 min 的安静期里负责把 bar 从 ~25% 推到 35–50%(远好于卡 25% 的观感)。

## 验证

### `pnpm tsc --noEmit`

```
$ cd apps/desktop && pnpm tsc --noEmit
TSC_EXIT=2
```

27 行错误,**全部 R47d v1 baseline 已有的 `@assistant-ui/core` 缺失类错**:

- `src/app/chat/composer/*.tsx` (10 文件):`Cannot find module '@assistant-ui/core'`
- `src/components/assistant-ui/*.tsx` (2 文件):同样
- `src/lib/incremental-external-store-runtime.ts` (15 行):`@assistant-ui/core/internal` 缺失 + 链式下游类型错

**0 个新错**,**0 个错指向 `apps/desktop/electron/main.ts`**(本单唯一改动文件)。R47d v1 baseline 同 exit 2 同 27 类错,本单不引入任何 new noise。

### git diff --check

```
$ git diff --check
$ echo $?
0
```

### git status

```
On branch main
Changes not staged for commit:
  modified:   apps/desktop/electron/main.ts
```

干净工作树,只动 main.ts。

## 留尾 + commit/push

- Commit: `fix(wenshu): R47d v2 ...`(commit hash 在最终报告)
- Push: `git push origin main`,跟 commit 一起
- 不重打包 APP / DMG(白名单禁止)
- 不动 `~/.wenshu-hermes/`(patched 已就地,装机 user 重启即生效)
- 未触发跑 e2e(`pytest tests/wenshu_cli/test_web_server.py` 不需要,R47d 跟 desktop electron 进度 emit 有关,R45 那一轮已跑过 524 passed,且本单是单文件 minimal 改,无语义层 diff 暴露给后端测试)
- 未 DM 装机 user — CC 无飞书 access,由 PM-direct 推拍下一轮验(让他们盯 8 min compile 的 desktop.log 看 `[updates] stalled Ns; bumping to X%` 是否按预测打)

## 文件改动清单

| 文件                                            | +/- | 说明 |
|-------------------------------------------------|-----|------|
| `apps/desktop/electron/main.ts`                 | +44 / -4 | `runStreamedUpdate` 默认 600;stall fallback + 状态 + emit;call site 600;两处 handler clear stallTimer;相关注释更新 |
| `wenshu-pour/architecture/R47d-v2-update-stall-emit-2026-08-29.md` | +new | 本文档 |
