# Legacy Requirements Surveys (PM-direct 调研)

PM-direct 7/25 调研了装机 user 在 wenshu 之前用 hermes-agent 跑的所有项目, 落档
到这里供后续功能规划 / Story 编写参考.

## 文件

- `8-legacy-projects-survey.md` (~58KB / 733 行, 装机 user 7/25 拍"调研所有老项目")
    8 工程目录调研:
    - Hermes-Slate-Desk (Tauri 2 + React, 8 sidebar)
    - novel-platform (V0.5.3 era, Tauri + Vue + Rust + SQLite)
    - novel-canvas (Next.js + Konva + tRPC + Prisma)
    - open-design (Apache-2.0 三方, 71 design systems)
    - loop-engineering (cobusgreyling fork, 7 patterns)
    - novel-research (FastAPI + MongoDB, 12 地仙 341 MD)
    - dev-tools (scratch cache)
    - wenshu (当前 fork, 7 commit)
    合计 ~330 需求, 跨项目总览 5 节:
    - 2.1 8 项目合计 ~330 需求
    - 2.2 已合到 wenshu (15 项借鉴)
    - 2.3 跟 wenshu 方向不一致废弃 (60+ 项)
    - 2.4 v1.0+ backlog (32 项)
    - 2.5 装机 user 关注 3 件事

- `novel-platform-survey.md` (~26KB / 371 行, 装机 user 7/25 拍"只看 platform 项目")
    novel-platform 84 需求 (10 主题分类) + 14 项装机 user 拍板 + 4 节跨项目总览
    (5.1 已合 10 / 5.2 废弃 20 / 5.3 v1.0+ backlog 17 / 5.4 协作留痕 4 类)

## 不打包给装机 user

按 wenshu-pour/install-boundary.md 协议, 本目录**不打包给装机 user 装的 wenshu 软件**,
仅 PM-direct / 装机 user 内部沉淀, 用于:
- Story 1/2/3 编写参考 (装机 user 拍板沉淀)
- 跨项目借鉴 (Hermes-Slate-Desk 8 sidebar → wenshu 桌面 sidebar 设计)
- novel-platform 时代经验复用 (方法论引擎 / 项目工作区 / MCP 集成)
- v1.0+ backlog 优先级 (装机 user 周末拍哪些做 / 哪些不做)

## 找 baseline

- commit 15148e72e (本目录创建)
- 改了什么: 加 wenshu-pour/legacy-surveys/2 文件
- 找回: `git checkout 15148e72e -- wenshu-pour/legacy-surveys/`
