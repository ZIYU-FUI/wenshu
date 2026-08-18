AGENTS.md

本文件 = wenshu 项目基线 + 跨角色称谓硬约束。单 agent (pocock profile) 直接对话,不走派单 / 不走看板 / 不走 6 角色流程。版本号 8/18 拍 v0.07(pocock single agent 净化版)。

执行硬规:
- 第一行是事实
- 末行就是事实
- 禁中性词:可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说
- 用确词:是/否/行/不行/可以/不可以/不变/变
- 修真词禁用 (修真/渡劫/筑基/返虚/结丹/金丹/元婴/飞升/天劫/雷劫/心魔/魔障):修真 = 之前 agent 把修正误写成修真,沿 8/18 排查真值。commit body / 注释 / 文档 / prompt / 卡 body 一律改用 修 / 改 / fix / 替换 / 调整
- 对老板 的唯一称谓 = 老板,不混用旧称谓

# 11 项目基线

- 架构:Swift/SwiftUI + CoreData + 单进程协程 + 自建轻量 AI 内核
- 不调任何外部 AI 平台
- 第一版 LLM provider 只支持 minimax cn(Anthropic 兼容协议)
- .ws 单文件 = CoreData + 附件,本地自管
- Apple 全家桶专属(macOS/iPad/iPhone)
- 项目根 = /Volumes/ANAN/Engineering/wenshu/
- Apple Developer Program 发布时再付(个人 $99/年)
- 版本号:三位(Hermes 风格),中间位 = 阶段号,第三位 = hotfix
- 3 文档 = 本文件 + README.md + CLAUDE.md
- 不带 hermes monorepo 痕迹(不再 fork)
- 不带 Tauri / Rust / SQLite / Vue 3 痕迹
- 不带 sparse clone 假设
- 不带 novel-platform / novel-craft / Hermes-Slate-Desk 旧 V0.5.x 协议
- 不调任何外部 AI 平台任何代码文件
- 不替老板 决定 LLM key 配置
- 不在 ~/wenshu-plugin/ 之外建项目目录
- 不写 ~/.wenshu/ 任何文件
- 不自写 wenshu CLI(文枢 = Swift 桌面应用,不是 CLI)
- 不动 ~/.hermes/ 下 hermes 自带文件
- 不动 .archive/wenshu-monorepo-fork/ 任何文件

# 12 跨角色表达硬约束

- 对老板 的唯一称谓 = 老板,任何对话 / 文档 / commit message / comment / prompt 一律用老板
- 不出现任何指向该用户的旧称谓写法