#!/usr/bin/env python3
"""
v0.30 boss OOB '角色一个文件拆成六个吧, 正常以后也是一个角色一个文档
功能模块也是, 一个功能模块拆成一个文档'.

Splits:
1. 角色/六个Agent.md → 6 separate files (one per agent)
2. 小说正文/功能模块说明.md → 8 separate files (one per function module)

Each split file = self-contained (= readable independently).
Uses stable UUIDs for consistency (= same UUIDs if re-run).
"""
import json
import sys
import os
from pathlib import Path
from datetime import datetime, timezone

if len(sys.argv) < 2:
    print("Usage: split-help-docs.py <library-root>")
    sys.exit(1)

library_root = Path(sys.argv[1])
book_id = "11111111-1111-1111-1111-111111111111"
shelf_root = library_root / "shelves" / "00000000-0000-0000-0000-000000000000" / "books" / book_id

NOW_ISO = datetime.now(timezone.utc).isoformat()


def write_md(folder_name: str, filename: str, title: str, content: str) -> Path:
    """Write a .md file to the specified folder, replacing if exists."""
    folder = shelf_root / folder_name
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / filename
    path.write_text(content, encoding="utf-8")
    print(f"  ✓ {folder_name}/{filename} ({len(content)} chars)")
    return path


# ============================================================
# 1. Characters: Split 6-agents.md → 6 separate files
# ============================================================

print("\n=== 1. 角色: 六个Agent → 6 files ===")

# Also update entities.json to reflect the split
# (No entity changes needed — these are book-level help docs, not entities)

agent_files = [
    {
        "filename": "主Agent-Conductor.md",
        "title": "主 Agent (Conductor)",
        "content": f"""# 主 Agent (Conductor)

你是直接对话的那个 (= 文枢打开后的主聊天窗口)。它读你当前选中的章节和设定, 帮你:

- 想下一段怎么写
- 检查你的设定有没有矛盾
- 给你改稿子

## 它能做什么

- 跟你聊天 (你打字, 它回话)
- 读你当前选中的章节、世界观、角色 (= 自动加载上下文)
- 检查设定一致性 (= 写过的设定里有没有前后矛盾)
- 帮你改稿子 (= 你贴一段, 它帮你润色)
- 派活给副 Agent (= 启动长任务)

## 它不能做什么

- 不能跑长任务 (= 一次性超过 1 分钟的活)
- 不能直接修改原始资料库 (= 派给 Wiki 派去做)
- 不能直接执行备份 (= 派给 Backup 派去做)

## 谁叫它

- 你 (主 Agent 永远在等你说话)
- 副 Agent (= 副 Agent 干完活会回来报告主 Agent)

## 怎么调它

直接打字就行。Cmd+K 唤起输入框。
""",
    },
    {
        "filename": "副Agent-SubAgent.md",
        "title": "副 Agent (SubAgent)",
        "content": f"""# 副 Agent (SubAgent)

副 Agent 是主 Agent 叫去做长任务的。比主 Agent 多了"持续运行"能力 (= 跑几分钟到几小时都行)。

## 它能做什么

- 跑全文一致性检查 (= 读 50 万字找前后矛盾)
- 从参考资料里提取实体 (= 读 100 个网页找历史人物)
- 大批量文件分析 (= 一次跑 1000 个文件的模式匹配)
- 长对话 (主 Agent 跑一会儿就累 = 副 Agent 不会)

## 它不能做什么

- 不能直接跟你对话 (= 它只听主 Agent 的)
- 不能保存东西 (= 副 Agent 跑完会报告主 Agent, 主 Agent 决定要不要存)

## 谁叫它

主 Agent (= Conductor 派活) = 通过 "看板" + "待办" 派发任务。

## 你怎么调它

- 间接: 你跟主 Agent 说"帮我跑全文一致性检查", 主 Agent 会自动派给副 Agent
- 直接: 工具栏的"派活"按钮 (= v0.30+), 你手动起一个长任务

副 Agent 的工作面板在右下角 (看板 + 待办)。它跑的时候你能看到进度 (= 进度条 + 当前步骤)。
""",
    },
    {
        "filename": "资料库Wiki派-Reference.md",
        "title": "资料库 Wiki 派 (Reference)",
        "content": f"""# 资料库 Wiki 派 (Reference)

你的资料库里有原始资料 (= 网页摘抄、PDF 摘录、采访稿)。Wiki 派读取这些, 提取出:

- 实体 (= 人物、地点、组织、事件、概念)
- 关系 (= 父子、师徒、敌友)
- 时间线

提取出来的内容放资料库的 "实体" 层。

## 它能做什么

- 读你导入的原始资料 (网页 / PDF / 采访稿)
- 提取实体 + 分类 (= 人物 → 文学/历史, 地点 → 地理, etc.)
- 识别实体间关系
- 生成时间线

## v0.30 增强 (= 老板新拍)

实体现在按**图书馆分类法**自动归档:

- 22 个一级分类 (= 文学 / 历史 / 哲学 / 军事 / 经济 / etc.)
- 9 个实体类型 (= 人物 / 地点 / 事件 / 概念 / 物品 / 组织 / 朝代 / 作品 / 其他)
- 分类文件夹随内容增加 (= 你导入新资料, 自动出现新分类, 不用手动建)

## 它不能做什么

- 不能写小说 (= 它只整理资料, 不创作)
- 不能改稿子 (= Wiki 派只读, 不写)

## 谁叫它

- Conductor (主 Agent): 跑资料整理任务时
- 你: 工具栏"导入资料"按钮

## 怎么调它

- 工具栏: "资料库 → 导入资料" 按钮, 选 PDF / 网页 / 采访稿
- 跟主 Agent 说: "我有一份 XX 资料, 帮我整理"
""",
    },
    {
        "filename": "状态追踪派-Status.md",
        "title": "状态追踪派 (Status)",
        "content": f"""# 状态追踪派 (Status)

主 Agent 想知道"主角这章有没有按计划推进"或者"支线 1 现在走到哪了"。它调用状态追踪派去查。

## 它能做什么

- 读你的大纲 (= 章节结构 + 计划)
- 读你的章节 (= 实际写了什么)
- 读你的伏笔表 (= 埋了哪些伏笔)
- 对比计划 vs 实际进度
- 报告当前进度 (例如: 主角支线完成 60%, 伏笔 3 已收回, 伏笔 5 还没)

## 它不能做什么

- 不能修改任何东西 (= 它只读, 不写)
- 不能给出建议 (= 它只报告, 不建议; 建议由主 Agent 做)

## 谁叫它

- Conductor (主 Agent): 当需要"现在写到哪了"信息时
- 副 Agent: 跑一致性检查时会顺便调用 (= 知道上下文)

## 怎么调它

- 间接: 跟主 Agent 问"我写到哪了", 主 Agent 会自动调 Status 派
- 直接: 工具栏"状态报告"按钮 (= v0.30+), 手动触发
""",
    },
    {
        "filename": "备份派-Backup.md",
        "title": "备份派 (Backup)",
        "content": f"""# 备份派 (Backup)

你调一次"备份"按钮, 它把整个 .ws 库打包成一个 zip, 存到桌面或者你想存的位置。

## 它能做什么

- 把当前 .ws 库打包成 .zip (= 含全部 shelves/books/ 资料)
- 存到桌面 / Documents / 你指定的位置
- 加上时间戳 (= 文件名带日期, 不覆盖旧备份)
- 验证 zip 完整性 (= 打包后解压一次确认 OK)

## 它不能做什么

- 不能恢复 (= 恢复是单独的"恢复派"功能, v0.31+ 实现)
- 不能增量备份 (= v0.30 只做全量; 增量备份是 v0.32+ roadmap)
- 不能云端同步 (= 本地备份; 云同步是 v0.33+ roadmap)

## 谁叫它

- 你: 工具栏"备份"按钮 (= 立即执行)
- Cron 派: 定时任务 (= 比如每周日 0:00 自动备份)
- 副 Agent: 长任务结束时可触发 (= 任务结果先备份再继续)

## 怎么调它

- 工具栏: 备份按钮 (= 立即打包)
- 跟主 Agent 说: "帮我备份", 主 Agent 会调 Backup 派
- 设置菜单: 定时备份 (= 通过 Cron 派)
""",
    },
    {
        "filename": "定时任务派-Cron.md",
        "title": "定时任务派 (Cron)",
        "content": f"""# 定时任务派 (Cron)

你可以设一些定时跑的任务:

- "每天 23:00 自动跑一致性检查"
- "每周日 0:00 自动备份"
- "每月 1 号 0:00 自动整理上个月新导入的资料"

## 它能做什么

- 在指定时间自动跑任务
- 跟 macOS 系统的 launchd 集成
- 系统重启后定时任务还在 (= launchd 持久化)
- 失败重试 (= 最多 3 次, 间隔 1 小时)
- 日志记录 (= 每次跑都写日志)

## 它不能做什么

- 不能跑超过 24 小时的单次任务 (= launchd 限制)
- 不能跨机器同步 (= 定时任务 = 本机)

## 谁叫它

- 你: 设置菜单 → 定时任务 → 添加
- 系统: launchd (= macOS 后台进程调度器)

## 怎么调它

- 设置菜单 → 定时任务 → 添加任务
- 跟主 Agent 说: "每周日帮我自动备份", 主 Agent 帮你设
""",
    },
]

# Track that the parent file 6-agents.md should be deleted
parent_role_file = shelf_root / "characters" / "六个Agent.md"

for agent in agent_files:
    write_md("characters", agent["filename"], agent["title"], agent["content"])

# Delete parent file
if parent_role_file.exists():
    parent_role_file.unlink()
    print(f"  ✗ DELETED: characters/六个Agent.md (split into 6 files)")

print(f"\n  Created {len(agent_files)} files in 角色/")


# ============================================================
# 2. Chapters: Split functional-modules.md → 8 separate files
# ============================================================

print("\n=== 2. 小说正文: 功能模块说明 → 8 files ===")

# We split into:
# 1. Project Management (Sidebar)
# 2. Material Preview (Project Preview)
# 3. Editor
# 4. Specialized Tools
# 5. Chat
# 6. Dynamic
# 7. Reference Library
# 8. Title + Status bar
# 9. Interaction conventions (Keyboard shortcuts)
# Total = 9 (the 8 zones + 1 keyboard reference)

module_files = [
    {
        "filename": "01-项目管理区-Sidebar.md",
        "title": "1. 项目管理区 (Sidebar)",
        "content": f"""# 项目管理区 (Sidebar)

你看到的左边的树状结构。它管理你的 .ws 库的内容。

## 结构

- **书架**: 你的书的分类 (= 玄幻、言情、剧本……, 你自己定)
- **书**: 一部长篇小说
- **书的下面 (= 8 个标准文件夹)**:
  - **世界观** (= 设定集, 你写)
  - **角色** (= 人物卡, 你写) [v0.30 拆成每角色一个文件]
  - **章节大纲** (= 结构, 你写)
  - **小说正文** (= 实际章节, 你写) [v0.30 功能模块拆成每模块一个文件]
  - **小说草稿** (= 没改好的半成品, 你写)

每个书都自带这一套目录。你不用建。

## 资料库 (= 书架列表最下面)

- 实体按分类自动归档 (= 历史/科学/文学/...)
- 你看分类, AI 看实体

## 交互

- 鼠标点文件夹 = 展开/收起
- 鼠标点文档 = 在编辑器里打开
- 鼠标点分类 (= 资料库) = 在素材预览区显示该分类下的 entity cards
- 拖拽 = 移动文档 (= v0.31+ 实现)
""",
    },
    {
        "filename": "02-素材预览区-Preview.md",
        "title": "2. 素材预览区 (Project Preview)",
        "content": f"""# 素材预览区 (Project Preview)

显示当前选中的书的所有文档。按文件夹分类列出 (= 世界观 / 角色 / 章节 / 草稿)。

## 3 个 mode (= v0.30 引入)

### Mode 1: Overview (= 默认, 没选任何分类时)
- 显示资料库所有 entities (= 9 个)
- 按 category 分组 (= 5 个 sections: 哲学 / 军事 / 经济 / 文学 / 历史)
- 每个 entity 显示为 card (= type icon + [type] badge + title + summary)

### Mode 2: Category-scoped (= 单击 sidebar 的 category)
- 只显示该 category 下的 entities
- 例如单击"文学" → 显示 [人物]李白 + [人物]杜甫 2 个 cards

### Mode 3: Single-entity detail (= 双击 card)
- 显示该 entity 的完整 .md body
- 包含 type/category chip + 全文

## 交互

- 鼠标点 card = (目前 no-op, v0.31+ 加 select 模式)
- 双击 card = 在编辑器打开 (= v0.30+ Ticket 3 计划)
- 滚动 = 浏览所有 entities
""",
    },
    {
        "filename": "03-编辑器-Editor.md",
        "title": "3. 编辑器 (Editor)",
        "content": f"""# 编辑器 (Editor)

你打字的地方。Markdown 格式:

- `#` = 一级标题
- `##` = 二级标题
- `*` = 斜体
- `**` = 粗体
- `[text](url)` = 链接
- `![alt](path)` = 图片
- ` ``` ` = 代码块

## 快捷键

- Cmd+S = 保存 (= 自动)
- Cmd+F = 找
- Cmd+Z = 撤销
- Cmd+Shift+Z = 重做
- Cmd+Shift+P = 切换预览 (= 看渲染效果)
- Esc = 取消当前操作

## 3 个 tab (= v0.30 引入)

- **编辑** (= book-open-text icon) = 当前主编辑器
- **大纲** (= puzzle icon) = 当前文档的结构大纲 (= H1/H2/H3)
- **反链** (= link icon) = 当前文档被哪些其他文档引用 (= wiki 链接追踪)

## 状态

- 保存状态: 自动保存, 你不用手动
- 同步: 编辑时不会阻塞 UI
- 冲突处理: 最后保存的版本为准 (= 单一用户场景)
""",
    },
    {
        "filename": "04-工具区-Tools.md",
        "title": "4. 工具区 (Specialized Tools)",
        "content": f"""# 工具区 (Specialized Tools)

中间偏右。两个 tab (= v0.29 替换: 从画布/数据库 → 伏笔/占位符):

## Tab 1: 伏笔 (Foreshadowing)

跨章节的伏笔追踪。老板 OOB v0.30+ = 自动扫描你正文里的"伏笔"标记。

- 显示所有伏笔 (= 在角色 folder 里定义)
- 标记每个伏笔"已回收" / "未回收" / "已过期"
- 按章节排序 (= 哪个伏笔在哪章被埋 / 被回收)
- AI 助手可以查这个面板, 帮你做一致性检查

## Tab 2: 占位符 (Placeholder)

内联占位引用。你正文里写 `[占位: 主角童年细节]`, 主 Agent 看到会自动去查。

- 扫描所有 .md 里的 `[占位: ...]` 标记
- 显示每个占位的位置 (= 文件 + 行号)
- 高亮已填充 / 未填充
- 主 Agent 用这个面板, 自动补充占位

## 未来 tabs (= roadmap)

- 关系图: 角色关系图 (= v0.31+)
- 时间线: 故事事件时间线 (= v0.32+)
- 风格: 写作风格统计 (= v0.33+)
""",
    },
    {
        "filename": "05-聊天区-Chat.md",
        "title": "5. 聊天区 (Chat)",
        "content": f"""# 聊天区 (Chat)

跟 AI 助手说话的地方。你打字, AI 回话。

## 上下文

它会自动读:
- 你当前选中的章节
- 当前书的世界观
- 当前书的角色
- 当前的伏笔

所以你不用每次告诉它"我在写哪本"。

## 模型选择

- 标题栏 (最顶) = 当前用的 LLM 模型
- 文枢 v1 用 minimax-cn (= Anthropic-compatible protocol)
- 切换模型: 标题栏 dropdown (= 不同任务不同模型)

## 多轮对话

- 上箭头 = 上一条历史
- 下箭头 = 下一条
- Cmd+L = 清空对话
- Cmd+R = 重试上一条

## 历史持久化

- 对话存在 `chat.sqlite` (= 全局, 不跟特定书)
- 跨 session 保留 (= 重启后还在)
- 按时间索引 (= 最新在最上)
""",
    },
    {
        "filename": "06-动态区-Dynamic.md",
        "title": "6. 动态区 (Dynamic)",
        "content": f"""# 动态区 (Dynamic)

底部右。两个子区:

## 子区 1: 看板 (Kanban)

副 Agent 跑的长任务的状态。

- 每条 = 一个长任务
- 状态: 排队中 / 跑 / 完成 / 失败
- 进度条: 显示当前步骤
- 任务描述: 谁派的 (= 主 Agent / Cron / 你)
- 日志: 实时显示副 Agent 干了什么

## 子区 2: 待办 (Todo)

你的待办事项 (= 不属于任何具体书的杂事)。

- 添加: 工具栏"+"按钮
- 完成: 双击 todo
- 删除: 右键 → 删除
- 按时间排序 / 按优先级排序
- 跟书内 todo 区分 (= 这里的 todo = 全局)

## 未来 (= roadmap)

- 搜索: 跨所有 todo/看板 找 (= v0.31+)
- 标签: 给 todo 加标签 (= v0.32+)
- 提醒: 到时间弹通知 (= v0.33+)
""",
    },
    {
        "filename": "07-资料库-ReferenceLibrary.md",
        "title": "7. 资料库 (Reference Library)",
        "content": f"""# 资料库 (Reference Library)

你的研究资料。原始网页、PDF 摘录、采访稿。

## 4 层结构 (= LLM Wiki)

1. **raw/** (= 原始资料) = 导入的网页/PDF, 你写的完整摘录
2. **entities/** (= 实体) = AI 提取的人物/地点/事件/概念, 按分类法归档
3. **abstracts/** (= 摘要) = 每份原始资料的简短摘要
4. **indexes/** (= 索引) = 反向索引, 从关键词找原始资料

## 分类法 (= v0.30 引入)

- **22 个一级分类** (= 图书馆分类法简化版, 中图法)
- **9 个实体类型** (= 人物/地点/事件/概念/物品/组织/朝代/作品/其他)
- **增量文件夹**: 分类文件夹随内容增加, 不用手动建
- 实体从目录树不可见, 按 category 自动归档

## 用户能看到什么

- **你看到**: 分类 (= 历史/科学/文学/...)
- **AI 看到**: 具体 entities (= 每个人物/事件)
- 资料库不是用来"浏览"的, 是用来"查"的 (= 写小说时 AI 自动引用)

## 怎么导入

- 工具栏"导入资料"按钮 → 选 PDF/网页/采访稿
- 拖拽到资料库 → 自动导入
- 跟主 Agent 说"我有一份 XX 资料, 帮我整理"
""",
    },
    {
        "filename": "08-标题栏和状态栏-ChromeStatusBar.md",
        "title": "8. 标题栏 + 状态栏 (Chrome + Status)",
        "content": f"""# 标题栏 (Title Bar) + 状态栏 (Status Bar)

## 标题栏 (= macOS 标准 + 文枢扩展)

最顶。从左到右:

- **红黄绿按钮** (= macOS 标准 close/min/max)
- **应用菜单** (= 文枢, 关于文枢, 偏好设置)
- **文件菜单** (= 新建 / 打开 .ws / 保存 / 关闭)
- **编辑菜单** (= 撤销/重做/剪切/复制/粘贴/查找)
- **视图菜单** (= 切换窗格 = Cmd+1 到 Cmd+6)
- **窗口菜单** (= 切换工作区)
- **帮助菜单** (= 文枢文档)
- **右侧**: 当前 LLM 模型 dropdown (= GPT / Claude / minimax-cn)
- **右侧**: AI 状态 (= Idle / Thinking / Working)

## 状态栏 (= Status Bar)

最底。3 个区域:

- **左**: 当前选中章节的字数 (= "章节: 1,234 字")
- **中**: 当前对话 ID (= "对话 #42", 跨 session 唯一)
- **右**: AI 状态 (= "Idle" = 在等你说话 / "Thinking" = 在想 / "Working" = 在跑任务)

## Liquid Glass (= v0.30 followup)

标题栏 + 状态栏用 macOS 26 标准 Liquid Glass 透明材质 (= 显示桌面背景模糊)。
""",
    },
    {
        "filename": "09-交互约定-KeyboardShortcuts.md",
        "title": "9. 交互约定 (Keyboard Shortcuts)",
        "content": f"""# 交互约定 (Keyboard Shortcuts)

按 macOS 标准 (= 跨 app 一致)。

## 全局

- **Cmd+N** = 新建书
- **Cmd+O** = 打开 .ws 库
- **Cmd+S** = 保存 (= 自动)
- **Cmd+W** = 关闭当前窗格
- **Cmd+Q** = 退出文枢
- **Cmd+,** = 设置
- **Cmd+1/2/3/4/5/6** = 切换窗格 (= 1=项目管理 / 2=素材预览 / 3=编辑器 / 4=工具 / 5=聊天 / 6=动态)
- **Esc** = 取消当前操作

## 编辑器

- **Cmd+F** = 找
- **Cmd+G** = 找下一个
- **Cmd+Z** = 撤销
- **Cmd+Shift+Z** = 重做
- **Cmd+S** = 保存 (= 自动, 但也支持手动)
- **Cmd+Shift+P** = 切换预览模式
- **Cmd+K** = 唤起 AI 助手
- **Cmd+/** = 注释 / 取消注释

## AI 聊天

- **Cmd+L** = 清空对话
- **Cmd+R** = 重试上一条
- **↑/↓** = 历史上下
- **Cmd+Enter** = 发送

## 侧边栏

- **Cmd+Shift+B** = 隐藏/显示 sidebar
- **Cmd+1** = 跳到项目管理区
- **Cmd+2** = 跳到素材预览区
- **Cmd+3** = 跳到编辑器
- **Cmd+4** = 跳到工具区
- **Cmd+5** = 跳到聊天
- **Cmd+6** = 跳到动态区

## macOS 标准补充

- **Cmd+Space** = Spotlight 搜索 (= 系统级, 跟文枢无关)
- **Cmd+Tab** = app 切换 (= 系统级)
- **三指上滑** = Mission Control (= 系统级)
""",
    },
]

# Track that the parent file functional-modules.md should be deleted
parent_module_file = shelf_root / "chapters" / "功能模块说明.md"

for module in module_files:
    write_md("chapters", module["filename"], module["title"], module["content"])

# Delete parent file
if parent_module_file.exists():
    parent_module_file.unlink()
    print(f"  ✗ DELETED: chapters/功能模块说明.md (split into {len(module_files)} files)")

print(f"\n  Created {len(module_files)} files in 小说正文/")

print()
print("=" * 70)
print("Summary:")
print(f"  角色: 1 file → {len(agent_files)} files (= 1 file per agent)")
print(f"  小说正文: 1 file → {len(module_files)} files (= 1 file per function module)")
print(f"  Total: 2 → {len(agent_files) + len(module_files)} files (= 6 + 9 = 15 new files)")
print("=" * 70)