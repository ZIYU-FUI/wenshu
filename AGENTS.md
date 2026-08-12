AGENTS.md

本文件 = wenshu 项目协作规则真理源。任何对角色边界 / 派单 / 插件策略 / 数据资产 / 跨设备 / 阶段门 / 自进化机制的查询,只查本文件。迭代日志在 .hermes/AGENTS_LOG.md(本文件不写)。

执行硬规:
- 第一行是事实
- 末行就是事实
- 禁中性词:可/应当/或许/可能/应该/建议/考虑/试图/尽量/大概/也许/或/任意/大概率/通常/一般来说
- 用确词:是/否/行/不行/可以/不可以/不变/变
- 对老板 的唯一称谓 = 老板,不混用旧称谓

# 1 角色边界

- 研发流程 6 角色:PM-direct / designer / CC / cc-runner / reviewer / AIF
- 老板 = 流程拍板权唯一权威
- ANAN = hermes 管家,不在研发 6 角色
- 老板召集团策群力会 = 主持,角色 reply
- 多 agent 各司其职,不用 1 个 agent 通吃

# 2 派单

- PM-direct 派单
- 单卡 ≤ 80 行硬上限
- 派单前必跑 hermes gateway status + hermes config check + hermes approvals suggest --days 7
- 派单看板 = wenshu(不混 novel-platform / default / archive)
- 派单卡 body 必含 §3.2 4 件套
- CC 调用权永久 = cc-runner,5 profile 之间不存在派单中转

# 3 派单原则

3.1 P12 6 截图固定化 = AIF 拉起必拍(标题栏 / 左上 5 tab / 中上 / 右上 / 底部 chat / 底部时间线),与 v0-fix-N-1 对比,功能消失 = 必回退
3.2 派单卡 4 件套(沿 PM-direct 9 协议):
  - 目标
  - 范围
  - 标准
  - 边界
3.3 单条件退出门(Ralph 三层 AND) = 完成指示器 AND CUA 6 截图 AND 无新红色批注,任一不满足 = 不进 done
3.4 派单前 dispatcher 必跑的 3 件 = hermes gateway status + hermes config check + hermes approvals suggest --days 7
3.5 派单卡 body 必含 §14.2 2 落点提示:本卡 done 前 4 角色按 assignee 必落 1 行 STATE.md(≤ 30 字, 3 选 1:规则冲突 / 冗余 / 新规则需求 + 1 句理由)
3.6 派单卡 assignee 硬约束:沿 §14.2 2 落点
3.7 designer 卡派发硬约束 (2026-08-12 老板 拍, 沿 t_ca73c613 跑 26.5 分钟案例):
- workspace 必填 dir 模式 + workspace_path = /Volumes/ANAN/Engineering/wenshu, 不用 scratch (designer 必须能直接定位项目根, 不跑 find ~)
- skills 字段必带 swiftui-design-patterns,wenshu-designer-onboarding (沿 t_1f92c929 修过的版本, 缺一 = PM-direct 重派)
- body "边界"段必含 "不做 X / Y / Z" 清单 (列 3-5 条, 例: 不选 ICON 库 / 不测像素 / 不写 Python 脚本 / 不写代码 / 不提交), 缺 = PM-direct 重派

# 4 11 段研发闭环

本节把 PM↔CC 单 loop 展开为 11 段;§2 派单、§3 派单原则、§5 拍单边界与跨边界红线继续有效。

- 1. 老板 提需求
- 2. AIF 沟通需求 + 拍卡
- 3. designer 出 DESIGN-*.md 主信源
- 4. PM-direct 沿 §2 + §3 四件套拆卡,单卡 ≤ 80 行
- 5. CC fire CLI = 唯一有权调用 cloud code(其他角色无调用权)
- 6. reviewer 派单后独立 read-only 审查,沿 §3.3 Ralph 三层 AND 退出门
- 7. CC 收 reviewer 的 PASS / FAIL 反馈,reviewer 不直接反馈 PM
- 8. PM-direct 关执行卡 + 多子卡完成后关总派单卡
- 9. designer 代码级验收 UI
- 10. AIF 关卡 + 阶段门聚合,沿 §13.2
- 11. 老板 验收,真机拍摄为证据

# 5 拍单边界 + 跨边界红线

5.1 CC 写代码(wenshu/ 根下):
  - SwiftUI 视图 + ViewModel
  - CoreData model + actor store + 检索接口
  - minimax cn LLM client(Anthropic 兼容协议)+ SSE parser
  - 标记系统(※ 待定、伏笔/信息点/历史事实)
  - 看板组件、修订候选展示
  - 单元测试 + 用户旅程测试
  - git commit(本任务权限下)
  - Package.swift / .xcodeproj 依赖增删(版本号变更需 PM 拍)

5.2 PM 改(CC 不动):
  - README.md / AGENTS.md / CLAUDE.md / CHANGELOG.md
  - Kanban 工单
  - .ws 文件结构
  - 跨设备同步策略
  - 蒸馏风格入库策略
  - 阶段门升级 + 阶段回流触发
  - minimax 模型名清单(PM 拍)

5.3 双向要问老板(CC 不自决):
  - 跳质量门禁
  - 改 LLM provider 适配层签名
  - 改主进程 / actor / 阶段门触发逻辑
  - 改 .ws schema
  - 跨阶段(v0.00.x → v0.01.x)
  - 改离线 / 在线状态切换
  - 改多设备冲突解决

5.4 红线(任何 → 改下列都越界):
  - AIF → PM:替 PM 派工单 / 验收
  - AIF → CC:直接调 CC(必须走 PM)
  - PM → AIF:替 AIF 定方向 / 推动阶段门
  - PM → CC:替 CC 执行
  - 任何 → 同时多项目并行
  - AIF / PM / CC → .archive/wenshu-monorepo-fork/(只读历史)
  - CC → 改任何 AI 平台任何代码文件
  - CC → 改 LLM provider 适配层签名
  - CC → 改 .ws schema
  - CC → 跳质量门禁
  - PM → 改 wenshu/ 源码(改 = 替 CC 执行)
  - 任何 → 替老板 拍产品需求
  - 任何 → 替老板 做 LLM key 配置决策
  - 任何 → 上传老板 .ws 到云端

# 6 评论

任何评论必带:task_id(自动)+ 时间戳(自动)+ 内容 < 5 行

3 种规范答复:
  - ✅ 采纳:做了 + 何时生效
  - ❌ 拒绝:理由 + 改做什么
  - ⏸ 延后:原因 + 重新打开触发条件 + 跟踪 owner

# 7 数据资产

- 数据资产 = 老板 自管
- .ws 单文件 = 老板 的项目数据,文枢不依赖云端服务
- 跨设备靠老板 自管(复制 .ws / iCloud / OneDrive / Git / U 盘)
- 多设备多入口经主控路由,iPhone 记录想法经主进程处理
- 冲突解决:版本号 + 老板 后置决定
- 卸载软件后数据仍可用
- 格式:CoreData store + 附件包 + 资源目录
- LLM key 存 macOS Keychain,不入文件 / log / commit message
- 封存的旧 monorepo fork 不可读不可写

# 8 阶段门

| 阶段 | 节点 | 验收标准 |
|------|------|---------|
| v0.00.0 | 项目基线 | 3 文档定稿 + Swift 包初始化 + CoreData 单文件 + minimax cn LLM 接入 |
| v0.01.0 | 极简闭环 | 创建项目 → 写一句话故事 → AI 举一反三 → 老板 选择 → 生成人物/世界骨架 |
| v0.02.0 | 完整闭环 | 聊天驱动设定演化 + 资料库后台调研 + 看板实时反映 + 修订候选不覆盖 + 5 区 layout grammar + 折叠 + 拖拽(FCP 风格, layout 状态存 .ws) |
| v0.03.0 | 阶段门 | 想法讨论 → 设定 → 大纲 → 正文,老板 控制节奏,AI 判断成熟度 |
| v0.04.0 | 长篇工具 | 章节拖拽卡片 + 情绪曲线 + 关系图 + 时间线 + 注水量 1-9 级 + 文笔风格 |
| v0.05.0 | 标记系统 | ※ 待定 + 伏笔/信息点 + 历史事实 |
| v0.06.0 | iPhone 端 | 想法记录 + 聊天创作 + 项目状态查看 + 标记系统 |
| v0.07.0 | 离线模式 | 本地写正文 + 看板 + 标记,LLM 联网,网络恢复增量合并 |
| v1.00.0 | 发布候选 | App Store 提交 |

8.1 Layout Grammar 5 区:详细见 Sources/WenshuApp/Views/DESIGN-V0-fix-*.md

# 9 活动区 vs 归档区

规则:
  - 改 active 的 wenshu/(Swift/SwiftUI/CoreData/3 文档)
  - 改沙盒 ~/Engineering/llm-call-test/ + ~/Engineering/wenshu-arch-experiments/
  - 不动 /Volumes/ANAN/Engineering/.archive/wenshu-monorepo-fork/(只读)
  - 不动 /Volumes/ANAN/Engineering/novel-platform/(历史包袱)
  - 不动 /Volumes/ANAN/Engineering/Hermes-Slate-Desk/(Tauri 时代留档)
  - 不动 ~/.hermes/ 下 hermes 自带文件
  - 不动 老板 自带的其他 hermes profile(~/.hermes/profiles/ 下非 wenshu)

# 10 风险与缓解

3 条底线:
  - 数据资产不丢
  - 真机拍是底线
  - CUA 是底线

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

- 对老板 的唯一称谓 = 老板,任何对话 / 文档 / 卡 body / metadata / commit message / comment / prompt 一律用老板
- 不出现任何指向该用户的旧称谓写法
- 研发角色 = PM-direct / designer / CC / cc-runner / reviewer / AIF 共 6 个
- ANAN = hermes 管家,不做流程活(见 §14 落位总图)

# 13 自进化方法论

13.1 落点机制:
- 路径 = /Volumes/ANAN/Engineering/wenshu/.hermes/STATE.md(项目级,不入 git,kanban 自动 append)
- 触发 = 每张卡 done 前必落 1 行(≤ 30 字, 3 选 1:规则冲突 / 冗余 / 新规则需求 + 1 句理由)
- 触发角色:
  - CC / designer / PM-direct / reviewer 4 角色按 assignee 必落
  - AIF 在以下情况必落或必写:
    (a) 阶段门聚合按 §14.2 3 主动读写(回流触发)
    (b) 老板 新拍规则进 §13 时,AIF 直接写
    (c) AIF 被 assignee 的卡(流程切换自查型)= 豁免走 §14.2 7 阶段门聚合,自查本身充数
- 漏落 = 下次阶段门聚合时 AIF 主动问"为什么没落",不进 §14.2 4 砍

13.2 聚合周期:
- 阶段门控节点(v0.03.0 → v0.04.0 → ...)
- 老板 显式触发"聚合"

13.3 改 AGENTS.md 4 动作:
- 加 = 新规则有 ≥ 2 个实例支持
- 合 = 2 条规则重复
- 降 = L3 → L1(沿 §1 §3 L1/L2/L3 三级)
- 砍 = 规则 0 实例支持超过 1 个阶段门

13.4 AIF 改 AGENTS.md 走 §13:不在对话里直接改 + commit + push = 不派 fire-wrapper 卡(沿 §1 老板 头尾规则)

13.5 首期聚合 = 老板 拍本节生效后立即触发

13.6 回流触发 = 老板 拍 AGENTS.md 改动后,AIF 落 comment 标记"v0.X.Y 自进化生效"+ 关闭本轮 STATE.md 段

# 14 自纠承诺 (老板 8/12 拍: "下次派卡,不要再出现跑完了,但给我看的 APP 没更新的情况")

14.1 派单派代码前 AIF 大管家必查 5 件现状 (≤ 2 分钟):
  (a) `git log --oneline -10 <主分支>` 确认最新 commit message + 文件清单
  (b) `git show <最新 commit> --name-only` 确认改动文件实际路径(不是 commit body 写的路径, 是 git 真值)
  (c) 老板 看的 APP 实际加载哪个资源链 (e.g. swift build 复制源 = Resources/Brand/X.icns vs .appiconset 是否被 actool 编译)
  (d) bundle/Contents/Resources/ 实际文件 mtime + MD5 对比
  (e) 5 件现状写进派单卡 body (§3 派单规则 v4 沿用)

14.2 派单卡 body 必含 5 件老板 验货段:
  (a) `git log --oneline -5` 输出 (派单前一刻抓, 让 reviewer 看到主线)
  (b) 改动的真值文件路径(不是 commit body 写的)
  (c) bundle 实际加载链路 + mtime 验证
  (d) 老板 验货命令 (e.g. `md5 .build/out/Products/Debug/*/Contents/Resources/AppIcon.icns`)
  (e) FAIL 标准:老板 跑命令 MD5 与 commit 改的不一致 = 派单方主动重做(不阻塞老板)

14.3 AIF 大管家自纠(8/12 14:15 拍):
  - 根因 1: commit 2bdd0d8cf body 写"Assets.xcassets/AppIcon.appiconset/" 裸路径, git 真值带"Sources/WenshuApp/" 前缀, AIF 没核对 → 误导后续沟通
  - 根因 2: AIF 大管家没查老板 实际看的 APP 资源链路(SPM .copy 源 = Brand/, .appiconset 不进 .car)→ 派单方改错位置
  - 根因 3: AIF 大管家把 LOGO v2 全面应用当成"PNG/ICNS 复制完成", 没在 commit 末尾加一段"老板 验货: 跑 swift build 后看 bundle/Contents/Resources/AppIcon.icns MD5 = e7aa024d..."
  - 自纠:AIF 大管家以后任何"改了资源/改了 UI/改了图标"的卡, commit message 末尾必加 1 行"老板 验货: <具体命令> 期望 = <MD5/size>"(沿 §14.2 (e))
  - 用词:AIF 大管家写注释 / commit message / 派单 body 用正常汉语, 不堆砌"修真"这种修仙小说词(沿老板 8/12 14:20 OOB 强调);写"对老板 的称呼"统一用"老板"(沿 §12 + 老板 8/12 14:12 OOB 强调)

14.4 §14.3 根因 1+2+3 已 8/12 14:15 AIF 大管家主动落地:
  - cp LOGO-v2 dark AppIcon.icns → Sources/WenshuApp/Resources/Brand/AppIcon.icns (mtime 8/12 14:15, MD5 e7aa024d...)
  - cp LOGO-v2 light + mono AppIcon.icns → Brand/light/ + Brand/mono/ (备 .icns 3 variant)
  - Package.swift exclude Brand/{light,mono} (避免 SPM unhandled warning 复发)
  - 待 swift build → bundle/Contents/Resources/AppIcon.icns MD5 应变 e7aa024d... (老板 验货段 §14.2 (d))
  - 待 commit + push 双仓 (沿 8 段双向闭环)

Wenshu AGENTS.md v0.04.0
