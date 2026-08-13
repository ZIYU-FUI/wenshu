# 文枢弹窗规范 (FCP 项目标题弹窗参照) · 2026-08-13 · t_ce783c49

真值来源 = 老板 8/13 01:25 OOB: 参考 FCP 项目标题弹窗 — 横向紧凑布局 +
选择框横向 chip 排列 + 间距紧凑 + 桌面应用规范 + 弹窗宽度 480-560pt。
代码落点 = `Sources/WenshuApp/Components/Popup/` 4 文件。 尺寸常量单一真值
= `PopupMetrics` (PopupFrame.swift), 改常量 = 全弹窗跟着改。

## 1 弹窗尺寸

| 项 | 值 | 落点 |
|----|----|------|
| 宽度 | 480-560pt, 默认 520pt | `PopupMetrics.width` |
| 高度 | auto 跟内容 (`height: nil`) | `PopupFrame.height` |
| 外边距 | 16pt 四边 | `PopupMetrics.outer` |
| 圆角 | 12pt | `PopupMetrics.corner` |

宽度锁 520pt = 区间中位。 高度不锁 = 内容多一行弹窗长一行, 不留空白。
例外: ProjectCreateView 540×480 硬固定 (V0-fix-1 Fix D + 源码字面量断言) → 传 `width: nil` 自己挂 frame。

## 2 横向 grid

一行 = 一个 `PopupFormRow`: label 居左 / control 居右。

- label: 固定 96pt (80-100pt 区间), 右对齐, `.subheadline` + secondary 色
- control: 吃掉剩余宽度 (`maxWidth: .infinity`, 居左)
- 多行 label 因固定宽度自动竖向对齐成一列 = 视觉基准线

不用 `Form` + `Section` = 那是 iOS list 竖排观感 (label 在上 control 在下),
纵向吃高度, 与"横向紧凑"冲突。

## 3 chip 样式

选择框不用 `.pickerStyle(.segmented)` (系统分段框视觉重), 改横排 chip,
落点 = `PopupChipGroup`。

| 状态 | 背景 | 文字 |
|------|------|------|
| 选中 | `Color.accentColor` 填充 | 白字 |
| 未选 | `.quaternary` 填充 | primary 字 |

- 圆角 8pt (`PopupMetrics.chipCorner`), 内边距 = 横 8pt / 竖 6pt
- chip 间距 6pt, `.buttonStyle(.plain)` (无系统矩形背景, 沿 V0-fix-8 范式)
- 配色跟随系统强调色 = 老板 换 macOS 强调色时弹窗自动跟

## 4 控件间距

| 间距 | 值 | 落点 |
|------|----|------|
| 行 ↔ 行 (竖) | 8pt | `PopupMetrics.row` |
| 行内 label ↔ control (横) | 12pt | `PopupMetrics.inner` |
| 分段 (标题/内容/按钮) | 12pt + Divider | `PopupMetrics.section` |
| 弹窗外边距 | 16pt | `PopupMetrics.outer` |

## 5 macOS 桌面规范

- 主操作 = `.buttonStyle(.borderedProminent)` (系统 accent 填充 + 白字,
  不自绘背景, HIG 兼容); 取消 = 次级按钮; 整条右对齐
- 键盘: 取消 = Esc (`.cancelAction`), 主操作 = Enter (`.defaultAction`)
- 不用 iOS list 风格 (无 `Form` / `Section` / `.insetGrouped`)
- sheet 抢 key window: `.onAppear` 调 `WindowActivation.forceKeyToWenshuSheet()`
  + 0.3s 后 `@FocusState` auto-focus (沿 WO-006 / WO-007), 否则 parent app
  非 foreground 时键盘事件路由回原 key app
- sheet 不挡主窗口 = SwiftUI 默认行为, 不额外加修饰符

## 示例 1 · ProjectCreateView (540×480 硬固定)

5 行横向 grid: 项目名 (TextField) / 文笔风格 (严肃·轻松·诗意·幽默·口语
5 chip 横排) / 注水量 (1-9 Slider + 当前值) / 标签 (逗号分隔) / 预览 (名 +
风格 + 注水 + 标签串)。 按钮栏 = 取消 + 创建 (项目名空则禁用)。 风格由
`.pickerStyle(.segmented)` 迁 chip 横排 = 本次唯一交互变更。

## 示例 2 · ProjectSettingsView (520pt 宽, 高度 auto)

6 行横向 grid: 项目名 (TextField) / 题材 (玄幻·都市·历史·科幻·言情
5 chip 横排) / 开始时间 (DatePicker 日期+时分) / 视频 (Toggle) /
音频 (Toggle) / 自定义设置 (Toggle)。 按钮栏 = 取消 + 保存。

已知缺口: `ProjectSnapshot` 无 genre / startTime / video / audio / custom
字段 → 该 5 项现只活在视图 @State, `onSave` 只回写 name。 加字段 = 改
Models (本卡 7 文件范围外), 留 v0.06 扩 schema 时接上。
