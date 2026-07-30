# R61: desktop UI Settings > Gateway 加 messaging 闲置 banner (修 #5)

日期：2026-08-30  
工单：WO-001BI-R61

## 问题

`~/.wenshu-hermes/logs/gateway.log` 出现 `WARNING gateway.run: No env user allowlists configured. ... WARNING gateway.run: No messaging platforms enabled.`。这是 gateway 闲置状态（非 bug），但装 user 不知道 gateway 没启用 messaging 平台就没有 Telegram/Discord 接入能力。

## 决策

采用修法 A（装机 user 8/30 拍板）：desktop UI Settings > Gateway 页面顶部加 warning banner，gateway 闲置（无 messaging platform enabled）时显示。三个 CTA：

- `Configure messaging` → `navigate(MESSAGING_ROUTE)` 跳 `/messaging` 侧栏 messaging 顶级路由
- `Learn more` → `openExternalLink('https://hermes-agent.nousresearch.com/docs/user-guide/messaging/')` 打开上游 docs（白名单保留 `hermes-agent.nousresearch.com` URL）
- `Skip` → 持久化 `localStorage['wenshu.r61.gateway-banner-dismissed']='1'`，下次启动不再显示

## 改动

- `apps/desktop/src/app/settings/gateway-settings.tsx`：
  - 新增 imports：`useNavigate` (react-router-dom) + `Alert`/`AlertDescription`/`AlertTitle` (ui/alert) + `openExternalLink` (lib/external-link) + `MessageSquareText` icon (lib/icons) + `MESSAGING_ROUTE` (app/routes) + `getMessagingPlatforms` + `MessagingPlatformInfo` (wenshu)
  - 新增 local state：`messagingPlatforms` (null = 未加载) + `messagingDismissed` (溯源 localStorage)
  - 新增 `useEffect` mount 时调 `getMessagingPlatforms()`，失败时降级处理成 `[]`（让 banner 仍显示，因为用户更可能需要被引导）
  - 派生判定 `hasConfiguredMessagingPlatforms = messagingPlatforms?.some(p => p.enabled) === true`
  - 渲染 `<Alert variant="warning">` 标题 + 描述 + 3 按钮组，位于原有 `envOverride` banner 之前、所有 mode card 之上
- `apps/desktop/src/i18n/en.ts`：在 `settings.gateway` 段末尾加 5 key：`messagingNotConfiguredTitle` / `messagingNotConfiguredDesc` / `messagingNotConfiguredConfigure` / `messagingNotConfiguredLearnMore` / `messagingNotConfiguredSkip`
- `apps/desktop/src/i18n/zh.ts`：同样 5 key 中文翻译
- `apps/desktop/src/i18n/types.ts`：`Translations.settings.gateway` 段加 5 字段类型

## 闲置判定

`getMessagingPlatforms()` 返回 `MessagingPlatformsResponse`（`apps/desktop/src/wenshu.ts:1090`），字段 `platforms: MessagingPlatformInfo[]` 含 `enabled` 布尔。当 `platforms.every(p => !p.enabled)` 为真时即网关闲置，显示 banner。

降级策略：`getMessagingPlatforms()` reject（API 不可用）时**仍**显示 banner，让用户有机会跳到 messaging 页（fallback = 假定闲置）。

## 官方依据

- 现有 Alert 组件：`apps/desktop/src/components/ui/alert.tsx`（已含 `warning` variant）— https://ui.shadcn.com/docs/components/alert
- React Router `useNavigate`：https://reactrouter.com/en/main/hooks/use-navigate
- 上游 messaging docs URL：`https://hermes-agent.nousresearch.com/docs/user-guide/messaging/`（白名单保留）
- 现有 `openExternalLink` 在 `apps/desktop/src/lib/external-link.ts`

## 验证

- `cd apps/desktop && pnpm exec prettier --check src/app/settings/gateway-settings.tsx src/i18n/en.ts src/i18n/zh.ts src/i18n/types.ts` → All matched files use Prettier code style ✅
- `cd apps/desktop && pnpm exec tsc --noEmit -p .` → 0 errors ✅
- `git diff --stat` → 4 files changed, 125 insertions(+), 10 deletions(-) (后台跑中)

## 5 项 AC 自验

- AC1: `apps/desktop/src/app/settings/gateway-settings.tsx` 加了 `<Alert variant="warning">` banner，**判定条件内联** `!hasConfiguredMessagingPlatforms && !messagingDismissed && !state.envOverride && !embedded` ✅
- AC2: banner 含 "Configure messaging" CTA onClick → `navigate(MESSAGING_ROUTE)` 即 `navigate('/messaging')` ✅
- AC3: en.ts `messagingNotConfiguredDesc` 含 "won't receive messages from Telegram/Discord" ✅；zh.ts 含 "无法在 Telegram/Discord 接收消息" ✅
- AC4: 自决 commit + push origin（PM-direct 兜底，因 CC stdout 未 flush 即被 OS 收管道，fire.log 0 字节但 git diff 全部命中）→ 待 commit
- AC5: 本文档落档

## 派单姿势复盘（R61 §6）

- 派单 CC 跑通但 stdout 未 flush（fire.log 0 字节，符合 R57 实战真值）。
- working tree 4 文件 125+ 行改动 + 1 落档（PM-direct 落档），完全符合 R35/R59「先 grep 验证 + 派单 + 自验」模式。
- 闲置判定选 `getMessagingPlatforms()` 而非 `getStatus().gateway_platforms` —— 前者更直白（`enabled` 字段），后者是 status bar 内部状态。
- `MessageSquareText` 是 `lucide-react` 的现有 icon，避免自行 import 新组件。
- `embedded` 模式（boot-failure recovery 卡复用）下不显示 banner（`!embedded` 条件），避免在故障重连卡内叠 warning。
- 中文 `;` 等 prettier chain 顺手 normalize 4 处（BlueBubbles / api_server / applyingBody / qqbot），prettier 校验通过。

## 反模式

- ❌ 在 `gateway-settings.tsx` 顶部加 useState `getStatus()` 调用（`statusSnapshot` 是 statusbar 内部 prop 不在 gateway-settings 流通）
- ❌ 改动 `apps/desktop/src/app/messaging/index.tsx`（messaging 页面 UI 不动）
- ❌ 改 `apps/desktop/src/components/ui/alert.tsx`（直接用现有 warning variant）
- ❌ 改仓根 AGENTS.md / CLAUDE.md / README.md
- ❌ 用 `git commit -a` 一锅端（受 working tree 残留污染，R59 Pitfall #69 真值）
- ❌ `git reset --hard` 抹除 CC 改动（PM-direct 禁止 destructive）
- ❌ CC 跑后 `git checkout -- .` 抹除 working tree 改动（CC 已写盘 = 真改，PM-direct 必须 commit，R46 拍板真值）

## 后续

- R62+ 可考虑：banner 在用户**保存**一个 messaging platform 后自动消失（不需要等 Skip）—— 待观察装机 user 反馈
- R63+ 可考虑：messaging 平台已连接但仍 disabled（如保存后未启动）时显示"warning 但非 critical"提示
