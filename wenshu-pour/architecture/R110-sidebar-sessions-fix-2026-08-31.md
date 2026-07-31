# R110 · 桌面侧边栏会话列表 skeleton + 空状态修复（2026-08-31）

> 装机 user 8/31 一天内反复催 4 次（"在修吗 / 派单了吗 / 还在跑 / 修好了没"）。
> 桌面 sidebar 0 行 sessions 时永远转骨架图，empty state 只一行"暂无会话"也不出"新建会话"按钮。

## 1. 真值（装机 user 截图 + 日志）

- 截图：sidebar 一直显示"暂无会话" + 5 行 skeleton 永远转。
- desktop log：`Timed out connecting to 文枢 backend after 60000ms`（一次性事件，但暴露了 root cause）。
- `state.db` 的 `sessions` 表 0 行（新装，从未建过 session）。

## 2. 根因（5 层串联）

1. `apps/desktop/src/store/session.ts:247` 把 `$sessionsLoading` 初始设为 `true`。
2. `use-session-list-actions.ts:147` 计算 `showLoading = $sessions.get().length === 0`，初次 mount 必为 true。
3. `use-session-list-actions.ts:215-218` 的 `finally` 块里 `if (showLoading && refreshSessionsRequestRef.current === requestId) setSessionsLoading(false)`——只要 `refreshSessions` 被新请求覆盖（重连 / 切 profile / 后端超时重试），原请求的 `requestId` 失配，`setSessionsLoading(false)` 永远不命中。
4. `index.tsx:1059` `showSessionSkeletons = sessionsLoading && sortedSessions.length === 0` 永远 true → `SidebarSessionSkeletons` 永远渲染。
5. `index.tsx:1279` emptyState 二元里即便 dismiss skeleton 也只显一行 `<div>暂无会话</div>`，没"新建会话"按钮 —— `SidebarBlankState` 组件已存在但 `showSessionSections` 掩护下走不到。

## 3. 修法（装机 user 拍单 8/31）

- **A. finally 必 dismiss**：`use-session-list-actions.ts` finally 去掉 `requestId` 守卫，`setSessionsLoading(false)` 无条件触发；新请求接管也是 finally 自己负责 dismiss，不互踩。
- **B. 空状态接 SidebarBlankState**：`section-states.tsx` 把 `onNewProject` 改为 `onNewSession`，按钮文案改 `s.newSessionButton`（新建会话）。`index.tsx` two 处（emptyState + !showSessionSections fallback）都改成 `<SidebarBlankState onNewSession={() => onNewSessionSplit('right')} />`。
- **C. i18n 新 key**：`zh.ts / en.ts / ja.ts / zh-hant.ts / types.ts` 加 `sidebar.newSessionButton = '新建会话' / 'New session' / '新規セッション' / '新增工作階段'`。
- **D. 选用 SplitDir='right'**：SplitDir 类型 4 值 (`'bottom' | 'left' | 'right' | 'top'`)，跟父级 route 已存在的 `onNewSessionSplit(dir)` 契约一致。

## 4. diff summary

- `apps/desktop/src/app/session/hooks/use-session-list-actions.ts` — finally 必 dismiss（+3/-2 行）
- `apps/desktop/src/app/chat/sidebar/section-states.tsx` — SidebarBlankState prop 名 + 按钮 i18n（+2/-2 行）
- `apps/desktop/src/app/chat/sidebar/index.tsx` — two 处空状态接 SidebarBlankState（+2/-4 行）
- `apps/desktop/src/i18n/{zh,en,ja,zh-hant,types}.ts` — 新增 `newSessionButton` key（5 文件 +1 行）

## 5. 验

- `pnpm exec tsc --noEmit -p tsconfig.json` → 0 命中
- `pnpm build` → ✓ built in 2.92s
- `node scripts/assert-dist-built.mjs` → ✓ dist/index.html + assets present
- 页面路径：`Sidebar → 0 sessions → SidebarBlankState 渲染 '暂无会话' + '新建会话' 按钮 → 按钮 trigger onNewSessionSplit('right')`

## 6. Pitfall 沉淀

- **Pitfall #71 实战姿势**：本单 add 显式 8 个 path（`git add` 逐 path），不 `git add -A`；push 双仓 `origin` + `old-origin`。
- **Pitfall #97 / #107 调研必跑**：5 段 grep 验 AC 有效性（store/actions/sidebar/component/i18n），派单前已验。
- **Pitfall #99 版本不动**：0.1.0 基础版里程碑不动，本次仅前端 5 文件 + i18n 5 文件 + 文档 1 文件。
- **新 pitfall R110-A：loading flag dismiss 不要用 requestId 守卫**。`refreshSessions` 是可重入的，timeout / 重连 / 切 profile 都会让新请求覆盖原 requestId。如果 UI 状态依赖某个 race-prone 守卫（requestId / ref），就会有"什么都不错但永远不 dismiss"的鬼魅 bug。改 atomic / unconditional 是正确方向。
- **新 pitfall R110-B：死代码 = 漏接 UI**。`SidebarBlankState` 组件写好了但渲染路径走不到，跟没写一样。grep 死代码是空状态类 bug 必跑项。
