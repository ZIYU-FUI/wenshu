# wenshu → hermes 白名单 (装机 user 8/29 拍)

> 装机 user 8/29 拍板真值:
> "要不要搞一个 hermes / hermes-agent 白名单, 我会告诉你, 哪些位置要保留 hermes. 然后下次修改的时候, 要跳过白名单."

## 白名单真值

白名单 = 仓内**应保留 `hermes` / `hermes-agent` 字面量**的位置 (即"对 hermes 的致敬/合规/上游引用/版权"), 不在 R28 改名范围.

PM-direct 派单时, 任何搜索/替换/Python 包名/IPC channel/启动命令都**必须跳过**白名单位置.

## 装机 user 已确认白名单 (8/29 第一批)

| 位置 | 字面量 | 原因 |
|------|--------|------|
| `apps/bootstrap-installer/src/routes/welcome.tsx:40` | "基于 hermes 修改而来" 文案 | 对上游 hermes 的致敬声明 (MIT 协议要求保留) |

## 默认上游白名单 (PM-direct 自动保留, 装机 user 不需明示)

| 类别 | 例子 | 保留原因 |
|------|------|---------|
| `hermes-agent.nousresearch.com` 全部 URL | `https://hermes-agent.nousresearch.com/docs/...` | 上游文档链接 (我们文档里 ping) |
| `git@github.com:NousResearch/hermes-agent.git` | install.sh/git URL | 真实上游仓 |
| `git@github.com:ZIYU-FUI/wenshu.git` | 我们 fork | 我们自己的 fork URL |
| 上游 release tag 引用 | `v2026.7.20` | 上游版本基线 |
| `Copyright (c) 2025 Nous Research` | LICENSE | MIT 协议要求 |
| 包内 `__pycache__/` | hermes_*.pyc | 编译产物 (R28 改名后会清掉重建) |
| `node_modules/hermes-parser` | npm 包名 | 第三方 npm 依赖 |
| `node_modules/hermes-estree` | npm 包名 | 第三方 npm 依赖 |
| `website/static/img/hermes-agent-banner.png` | 老 build 资源 | 待 R32 后清掉 |
| `packaging/homebrew/hermes-agent.rb` (如 R28 没改名) | 上游 homebrew formula | 待 R30 后清掉 |
| `skills/.../hermes-agent*` | skills 目录命名 | skills 标识符 (跟仓包名解耦) |

## 派单时白名单使用姿势

派单 prompt 加段:

```
[白名单跳过]
以下位置保留 hermes 字面量 (装机 user 8/29 拍):
- apps/bootstrap-installer/src/routes/welcome.tsx:40 致谢语
- 上游 URL (hermes-agent.nousresearch.com)
- 上游仓 (NousResearch/hermes-agent)
- MIT 协议版权 (Copyright 2025 Nous Research)
- node_modules/ 第三方包
- 仓根 docs/ 文档历史引用
- 任何 [装机 user 显式标记 hermes 保留] 的位置

不在白名单内的 hermes 字面量 → 全部改名 wenshu.
```

## 装机 user 维护白名单方式

装机 user 拍"X 位置要保留 hermes" → PM-direct 立即:

1. `pm-direct` 在本文件加新行
2. `pm-direct` 派单 prompt 引用本白名单
3. 派单 CC 跑改时自动跳过白名单

## 当前白名单版本

v1.0 (2026-08-29, 装机 user 拍"app 致谢语基于 hermes")

后续装机 user 拍"X 保留 hermes" → 增量加.
