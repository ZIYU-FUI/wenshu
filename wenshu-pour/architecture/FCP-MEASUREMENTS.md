# FCP-OWNC baseline measurement (= boss 19:10 "精准测量")
#
# Source: wenshu-pour/architecture/screenshots/FCP-owner-baseline-2026-08-14.png
# Resolution: 2904x1968 px @2x retina = 1452x984 pt (= owner Mac screen)
# Measurement method: PIL pixel sampling, line-by-line
#
# This addendum = the source-of-truth pixel data for boss的"FCP 风格" wenshu layout.
# Edit when boss拍 "再看一次 FCP 截图" (= don't re-measure; the numbers below are ground truth).

## Window outer dimensions
| Field | px | pt |
|---|---|---|
| Width | 2904 | **1452** |
| Height | 1968 | **984** |

## Toolbar bottom (≈ 50-55 pt from window top)
- Toolbar 高度 ≈ 50 pt (= 8 buttons + 标题栏 + traffic light region)
- Upper band 起点 y=55 pt

## Upper band horizontal zones (y=300 pt mid-sampling)
| Zone | x-range px | pt range | % of 1452 pt | RGB | Color name |
|---|---|---|---|---|---|
| Library 列 (含缩略图) | 0..600 | 0..300 | **20.7%** | (32,32,32) | 深灰 (panel bg) |
| Library 缩略图区 | 350..550 | 175..275 | sub-zone | (69..114, 136..173, 180..198) | DJI 蓝绿色缩略图 |
| Editor (= FCP Viewer) | 650..2050 | 325..1025 | **51.7%** | (0,0,0) | 纯黑 |
| Inspector | 2150..2850 | 1075..1425 | **27.6%** | (45,45,45) | 浅灰 |

## Upper band vertical splitters
| Position | RGB | Visual |
|---|---|---|
| x=300 pt (Library↔Editor) | (45..50, 45..50, 47..50) | 1pt 细线 NSColor.separatorColor |
| x=1050 pt (Editor↔Inspector) | (45..50, 45..50, 47..50) | 1pt 细线 NSColor.separatorColor |

## Lower band horizontal zones (y=750 pt mid-sampling)
| Zone | x-range pt | % of 1452 pt | RGB | Color name |
|---|---|---|---|---|
| Timeline (= FCP lower-left) | 0..550 | 37.9% | (30,52,84) | 蓝色 (timeline band) |
| Inspector (= FCP lower-mid) | 550..1075 | 36.2% | (24,24,24) | 浅黑 |
| 转场列表 (= FCP lower-right) | 1075..1450 | 25.9% | (30,30,30) → RGB(53..150) | 多色 (缩略图) |

**Note**: FCP lower band ≠ Wenshu lower band (= FCP = Timeline+Inspector+转场, Wenshu = Chat+Console+Status).
Boss拍 = 视觉风格借鉴, 不是抄布局 (= Q4 owner decision: 5 functional zones with names).

## Splitter specifications (boss 19:10 拍)
| Spec | FCP 实测 | Wenshu 实施 |
|---|---|---|
| 粗细 | 1pt 细线 (= NSSplitView .thin dividerStyle) | NativeSplitterView.visibleDividerThickness = 1pt |
| 颜色 | NSColor.separatorColor (RGB ~46,46,46 in dark mode) | NativeSplitterView draw() |
| Hit area | 8pt (= NSSplitView .thin default) → boss拍 "右边多一块" | LT-01-fix16 = 1pt (= 视觉 0 间距) |
| Hover 颜色 | controlAccentColor (RGB ~10,132,255 in dark mode) | NSColor.controlAccentColor |
| Cursor | NSCursor.resizeLeftRight / .resizeUpDown | NativeSplitterView.mouseEntered |

## Window initial dimensions (boss 19:10 拍 "打开 APP 时整个 APP 初始大小")
- 1452x984 pt (= 老板电脑全屏)
- min 1280x800 (= Apple HIG default for desktop apps, smaller rooms still work)

## Defaults that boss has拍'd but NOT measured (= v0.02.0+ 验证)
- Shelf/Project 内部比例: 之前 v0.01.0 默认 50/50 (= hardcoded, not user-resizable)
- Chat/(Console+Status) 比例: 25/75 (= 老板之前拍 "Chat 25% / Console 50% / Status 50%")
- Lower band 比例: 50/50 (= upper/lower 各占一半)
