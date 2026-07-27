# wenshu-setup 调研真值 (8/26)

> 装机 user 拍 "给我一份最新的 wenshu-setup".

## 拍板真值 (PM-direct 5 分钟调研完)

### 三层拍板

| 层 | 路径 | 内容 | 拍板 |
|---|---|---|---|
| 1. 装机 binary | `/Applications/文枢.app/` | 7.7M Mach-O arm64 (binary + icon + Info.plist) | ✅ 装机 user 7/24 装 |
| 2. 源码仓 | `/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/` | Tauri 2 + React 19 + Vite + TypeScript + 66 src-tauri/ Rust | ✅ 装机 user 拍板 wenshu fork |
| 3. 装路径隔离 | `~/.wenshu-hermes/` | logs/ (bootstrap-installer.log) | ✅ 装机 user 7/24 装 |

### 装机 binary 真值

```
/Applications/文枢.app/
├── Contents/
│   ├── Info.plist (1145 bytes)
│   │   - CFBundleDisplayName: 文枢
│   │   - CFBundleExecutable: WenShu-Setup
│   │   - CFBundleIdentifier: com.wenshu.app.setup
│   │   - CFBundleShortVersionString: 0.0.1
│   │   - CFBundleVersion: 0.0.1
│   │   - LSApplicationCategoryType: public.app-category.developer-tools
│   │   - LSMinimumSystemVersion: 11.0
│   │   - NSHumanReadableCopyright: Copyright © 2026 文枢 Project
│   ├── MacOS/
│   │   └── WenShu-Setup (7.7MB, Mach-O 64-bit executable arm64)
│   │       - 内嵌字符串: 文枢 / wenshu / hermes / KaTeX / DBVGDLLs / JetBrainsMono
│   │       - 内嵌 dist/ 前端 (no filesystem dist 依赖)
│   │       - framework 链接: AppKit / WebKit / ApplicationServices /
│   │                      CoreGraphics / Carbon / CoreVideo / CoreFoundation / Foundation
│   └── Resources/
│       └── icon.icns (370KB, 文枢墨檐 LOGO)
```

### 源码仓真值

```
/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/
├── .gitignore (602 bytes)
├── README.md (3.4KB)
├── dist/ (前 build 产物)
├── eslint.config.mjs
├── index.html (84 bytes, Vite entry)
├── node_modules/
├── package.json (1.85KB)
├── pnpm-lock.yaml (224KB)
├── pnpm-workspace.yaml
├── public/
├── scripts/
├── src/ (36 files, React 19 + TS + Vite 8 frontend)
│   ├── App.tsx
│   ├── main.tsx
│   ├── components/ (StageIndicator, ProgressBar, ...)
│   ├── lib/ (invoke, store, ...)
│   └── styles/
├── src-tauri/ (12 files, Rust + Tauri 2 backend)
│   ├── Cargo.toml
│   ├── build.rs (含 cargo:rerun-if-changed=../dist 修复蓝屏)
│   ├── tauri.conf.json
│   └── src/
│       ├── main.rs
│       ├── lib.rs (含 webview debug tracing)
│       ├── install_script.rs (fork URL = ZIYU-FUI/wenshu)
│       ├── bootstrap.rs (hermes_is_installed check)
│       └── ...
├── tsconfig.json
├── vite.config.ts / vite.config.js
└── (build artifacts)
```

### 装路径隔离真值 (per-user wenshu 配置)

```
/Users/anbaiqiang/.wenshu-hermes/
└── logs/
    └── bootstrap-installer.log (装机 user 7/24 装机日志)
```

⚠️ 装机脚本没拷入 SOUL.md / AGENTS.md / methodologies/ — 装 user 7/24 装的 hermes-agent 1:1 fork 没这些文件, wenshu fork 才有.

## 15 commit trace (8/24-8/26 装机 user 拍板 + commit 我自决)

```
7f6b4dbc2 docs(wenshu-pour/architecture): hfc 测试拍板真值 (smoke 缺 config)
d5839469f docs(wenshu-pour/architecture): hfc (hermes-feishu-streaming-card) 没生效根因排查报告
df6d51278 docs(wenshu-pour/architecture): hfc 拍板真值修正 = Feishu Card
e678eb9fb docs(wenshu-pour/taxonomy): 100 标签 × 9 字段总表
6bd5d393d docs(wenshu-pour/architecture): 数据层拍板真值 — 不引入数据库
2050b8e89 docs(wenshu-pour/architecture): 文枢系统总览 (大概括文档)
8f44071b2 docs(wenshu-pour/legacy-surveys): 8 老项目 + novel-platform 调研报告
15148e72e docs(wenshu-pour): PM-direct pour 目录 + 装机边界 + 用户故事 v0.2
2c9d9026d docs(wenshu): user stories v0.1 — Story 1 首次进入 + 5 步向导建项目
2eef5e5e5 feat(wenshu): translate 9 public-domain foreign methodologies (法无定法 expansion)
6512d5751 docs(wenshu): add first SCQA methodology example
41bc9613e feat(wenshu): default writing-assistant role + 法无定法 methodology framework
93c4621b4 chore(deps): drop tui_gateway/ui-tui/web redundant surfaces
6cab7c457 fix(installer): embed frontendDist on every dist rebuild
f77545fb6 translate(installer): stage names 中文化 + error messages 翻中文 (装机 user 7/24 最后 commit, baseline)
```

## 装机 user 拍板 5 件事 8/26

1. ✅ wenshu-setup 装机 binary = `/Applications/文枢.app/` 7.7MB Mach-O arm64 (文枢 0.0.1)
2. ✅ wenshu-setup 源码仓 = `/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/`
3. ✅ wenshu-setup 装路径隔离 = `~/.wenshu-hermes/` (1:1 跟 hermes `~/.hermes/`)
4. ⚠️ wenshu-setup 装脚本没拷入 SOUL/AGENTS/methodologies (装机 user 拍板时机未定)
5. ⚠️ wenshu fork vs hermes 1:1 拍板: 装机 user 拍 "完全一模一样" (不加任何东西)

## 装机 user 后续拍板

按 "commit 我自决" + 周末不打扰 — 等装 user 周末拍:
- Story 2 v0.2 草稿审改
- Story 3 描述
- lego/ 残骸处理
- wenshu/methodologies/style/ commit 时机
- hfc 修法 (Layer 1/5)
- 装机脚本装入 SOUL/AGENTS/methodologies 时机

## 关联拍板

- `wenshu-pour/architecture/system-overview.md` — 大概括
- `wenshu-pour/architecture/data-decision.md` — 不引入 DB
- `wenshu-pour/architecture/hfc-investigation.md` — hfc 拍板真值
- `wenshu-pour/architecture/hfc-root-cause.md` — hfc 没生效根因
- `wenshu-pour/architecture/hfc-test-status.md` — hfc 测试拍板真值
- `wenshu-pour/taxonomy/100-tags-survey.md` — 100 标签总表 (已发飞书)
- `wenshu-pour/methodologies/style/` — 笔法库 (12 作者)
- `wenshu-pour/legacy-surveys/` — 8 老项目 + novel-platform 调研