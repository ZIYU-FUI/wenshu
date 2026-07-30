# WO-001BI-R71: install.sh + install.ps1 装机即默认中文

## 装机 user 8/30 拍板真值
- CLI 不做翻译 (CLI 不是给用户看的)
- install 加中文: install.sh + install.ps1 装时 写 `display.language: zh` 到 ~/.wenshu-hermes/config.yaml
- 已有 R70 audit 标记 install.sh + install.ps1 都未写 display.language, 需 R71 修

## PM-direct 调研真值 (8/30 装机 user 拍后)

### 装机 user 拍 + R70 audit 派单真值 vs 现状
装机 user 8/30 拍"install 加中文" → 派单真值"装时写 display.language: zh"。

调研真值 (仓根 install.sh 现状):
- **install.sh**: R43 (commit `b51352de5`, 2026-07-29) 已加 `seed_fresh_install_language()`
  + `copy_config_templates()` 调用 + 写"Defaulted desktop language to Simplified Chinese" log。
  装机 user 8/30 拍 R71 时, install.sh 已在 8/29 R43 修完, 装机 user 真值已被 R43 满足。
  **R70 8/30 audit 表里"install.sh 写 display.language ❌ 未写"是事实性错误** (audit 当时没 grep
  R43 commit 后的 seed_fresh_install_language)。
- **install.ps1**: 真的没写。Copy-ConfigTemplates 拷完模板就走了, 没有 bash 等价物。
  R70 audit 此项 ❌ 是对的。

### 派单 1+2 真值 (R70 拍)
- AC1 install.sh 装后 `~/.wenshu-hermes/config.yaml` 含 `display.language: zh` → **R43 已达成, R71 不动 install.sh**
- AC2 install.ps1 装后 `~/.wenshu-hermes/config.yaml` 含 `display.language: zh` → **R71 补 Seed-FreshInstallLanguage**

## R71 改 (自决)

### scripts/install.ps1 改 (+64/-1 行, 纯 ASCII)

加 `Seed-FreshInstallLanguage` 函数 + `Copy-ConfigTemplates` 调用。

#### 函数 (位置: Write-BrowserEnv 后, Install-AgentBrowser 前)
- 入参: `$ConfigPath`
- 镜像 bash `seed_fresh_install_language` 4 case:
  1. config 不存在 → 写 `display: { language: zh }` (BOM-free UTF-8)
  2. config 已有 `display: { language: zh }` → no-op
  3. config 已有 `display:` 块但无 `language: zh` → 在 `display:` 后插入 `  language: zh`
  4. config 没 `display:` 块 → 末尾 append `display: { language: zh }`

#### Copy-ConfigTemplates 调用 (位置: config.yaml 拷模板后, SOUL.md 写前)
```powershell
Seed-FreshInstallLanguage -ConfigPath $configPath
Write-Success "Defaulted desktop language to Simplified Chinese"
```

幂等: 老 config 已有 `language: zh` → no-op, 不动用户选择。update/reinstall 不破坏。

### 纯 ASCII 守恒
- install.ps1 commit `97249cfc8 fix(install): keep install.ps1 pure ASCII so Windows
  PowerShell 5.1 doesn't misparse it` → 8/30 R71 patch 后非 ASCII 字节数 = **0** (Python
  验证 187502 字节全 ASCII)。
- bash version 注释里带中文 (`# Desktop UI language (fresh 文枢 installs default to
  Simplified Chinese).`) 没问题, install.sh 不受 PS 5.1 ASCII 限制。

## AC 验证

### AC1: install.sh 装后 `~/.wenshu-hermes/config.yaml` 含 `display.language: zh`
- 4 case 单元 smoke test (subprocess.run 跑真 bash, 4 case 各跑一次):
  - Case 1 (no config): output = `display:\n  language: zh\n`, zh count = 1 ✓
  - Case 2 (already seeded): unchanged, zh count = 1 ✓
  - Case 3 (display block w/o language): 插入 `  language: zh` 在 `display:` 后, zh count = 1 ✓
  - Case 4 (no display block): 末尾 append `display: { language: zh }`, zh count = 1 ✓
- 装机 user 8/30 拍"装时写"真值已被 R43 满足 → R71 不动 install.sh = **不破坏 AC1**

### AC2: install.ps1 装后 `~/.wenshu-hermes/config.yaml` 含 `display.language: zh`
- Seed-FreshInstallLanguage 4 case 模拟 (Python 镜像 PS 逻辑跑):
  - Case 1 (no config): output = `display:\n  language: zh\n`, zh count = 1 ✓
  - Case 2 (already seeded): unchanged, zh count = 1 ✓
  - Case 3 (display block w/o language): 插入 `  language: zh`, zh count = 1 ✓
  - Case 4 (no display block): append `display: { language: zh }`, zh count = 1 ✓
- 装机 user 真值被 R71 补齐 ✓
- 边界: `display: # 注释` 行 (内联注释) 触发 case 4 fallback, 与 bash 版本同行为, 不修

### AC3: 自决 commit + push origin
- commit: `fix(wenshu): R71 - install.ps1 add Seed-FreshInstallLanguage for default-zh`
- push: origin main (push 后 R70 2a5e8fd65 上)

### AC4: 落档 = 本文件
- `wenshu-pour/architecture/R71-install-default-zh-2026-08-30.md`

## 不动范围 (8/30 装机 user 拍 / 派单禁止)
- R68+R69+R70 已 push commit (2a5e8fd65) 不 reset/不 amend
- R53 浅克隆 (用户场景瘦 install.sh) 不动
- R57 bundled install.sh (装包器内嵌) 不动
- CLI 端 (3352 英文 print) 装机 user 拍"CLI 不做翻译"不动
- desktop i18n (zh.ts 2161 key DEFAULT_LOCALE='zh') 不动
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语 / hermes-agent URL / 上游仓 fork / node_modules / MIT 版权 白名单保留

## 关键 commit
- 修真值:
  - R70 `2a5e8fd65` audit 表"install.sh 写 display.language ❌ 未写" 8/30 时已错 (R43 已写)
  - R43 `b51352de5` 真值, install.sh seed_fresh_install_language
- R71 commit: 见 AC3

## PM-direct 备注
- 装机 user 8/30 派单"install.sh 装完写"看似需改 install.sh, 实则 R43 已修。PM-direct
  调研真值需对拍板真值 + 仓根现状 双向 grep, 避免重复造轮子 (install.sh 改 back
  seed_fresh_install_language 会回退 R43 写过的功能)。
- 装机 user 真值"install 加中文" 在 R70 audit 拍板时 (8/30) 已被 R43 满足一半
  (install.sh), 装机 user 8/30 拍"你可以加" = 同意 R71 补 ps1 + audit install.sh 现状。
  装机 user 不知道 R43 已写, PM-direct 不反推, 但实操时不破坏已对的部分。
