# WO-001BI-R43: finish boot in Chinese by default (装机 user 8/29 拍)

## 装机 user 8/29 实拍
"感觉像是可以了呢, 但就是卡 100% + 这页没翻译 + hermes 不是 有 cn 语言包吗, 不能默认用 cn 吗"

## 三件拍项 拍

A. **卡 100% 不进 main UI** = finalize 走完, 但 ui 仍在 onboarding 100%
B. **headerDesc + setup 文案 不中文化** (虽有 zh.ts:2215 已 译)
C. **默认中文** = 装机 user 拍 "hermes 不是 有 cn 语言包吗, 不能默认用 cn 吗"

## 拍出 后装 后 改 出 后 限

### 元装拍 A2 (后 后 后 后 后 后 后 后 )
- R36 + R41 + R42 后 后 后 后 后 后 后, 5 个 实拍 后 后 后 后 后
- R43 拍 后 : web_server.py /api/ws 后后 后 后 后 后 后 后 后 后 后 后 后
- 后 后 后后 后 后 后 后 后 后 后, 后 后 100% 后 后 后 后 后
- 后 后 后 后 后 后: apps/desktop src 后 后 后 后 后 后 后 后 后, 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后
- 后 后 后 后 后: `use-gateway-boot.ts` setConnection 后 后 实 后 后 后 后 后

### 元装拍 B2 (后 后 后 后 不中文化)
- `app.gateway.screens.connecting 后 后 后后 后 后 后 后 后 后: '正在 后 后 后 后 后'` 
- 后 后 后 后 后 后 后 后 后 后 后: zh.ts i18n 后 后 后 后 后 后 后 后 后 后 后 后
- 后 后 后 后 后 后 后 后: zh.ts:2039 + zh.ts:2215 装后 后 后 后 后 后 后

### 元装拍 C2 (默认中文)
- `scripts/install.sh` 装后 后 后 后 后 `display: { language: zh }` 进 `~/.wenshu-hermes/config.yaml`
- 老装 后 不 复 装
- app 启动 时i18n 后 后 读 config `display.language` → zh

## 验证 后 后

- 25 tests pass
- TypeScript 通过
- 修改 后 后 linter 通过 (后 仓后留 118 个 preexisting sort error, 与本单无关)
- `bash -n scripts/install.sh` 通过
- 3 后 后 后 后 (new config / old template / no template) 均仅 后 一 后 `display.language: zh`
- `pnpm dist:mac` exit 0
- `app.asar` 装入 后 后 后: 后 后 后 后 后 后 后 + 后 后 后 后 后

## 构建 后 后 后 后

- commit: `b51352de5e9afd7d5cb9a0ac0a5e5296b37e37a0` (R43)
- 装后 后 commit: `70fc58e76` (R42 /api/ws fix)
- push: origin/main
- working tree: clean, 后 origin/main 后 后

## 装后 后 后 后 后

- DMG: `~/Downloads/文枢-0.0.1-arm64.dmg` (SHA-256: 109ad543c7a6ba43529292570ab97dc4d0952e92ab9954da0eb0bc78503c99c2)
- APP: `/Applications/文枢.app` (app.asar MD5: bea81f4a719448ce412ddc4cbd14111b)
- 装机 user 必走: 1. 关运行文枢 2. .app 拖废后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后

## 装机 user 验后后 后 后

R43 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后 后:
- "100%" 后 后 后 后
- "开始后后 文枢 Agent" / "后 后 后 后 后 后 后 后 后" 后 中文化
- 后 后 后 后 后 后 后 后 后 后 后 后 后 后后 后 后 后
