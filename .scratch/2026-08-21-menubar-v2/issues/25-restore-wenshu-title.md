# 25 — 设置菜单 title 恢复 "文枢" + 渐显渐隐动画保持

依赖: ticket 24 revert commit `654bac679`

**What to build:**
- 渐显渐隐动画保持 (providerApiEditor L436-454 已修真因, ticket 22 + 23 落地不动)
- Info.plist CFBundleDisplayName + CFBundleName 改回 "文枢" (撤 ticket 21 + 23 真值, brand 恢复)

**Why:**
老板 2026-08-22 07:22 拍 "恢复成'文枢'设置" + 接受渐显渐隐动画. 修真因 brand "文枢" + 修真因 macOS 14+ SwiftUI Settings Scene API 不支持自定义 title 真值 (Q44 swiftinterface 验).

**Acceptance:**
- 老板 macOS 真验: 弹窗 title = "文枢 设置" (品牌恢复) / 编辑框 3 元素渐显渐隐 Apple 默认动画
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)
- 双轴 code-review verbatim 进 commit body