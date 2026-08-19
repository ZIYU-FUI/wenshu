# 10 — LayoutShellViewModelTests 期望值改用 ratio sum 校验 (老板 2026-08-19 拍 "按比例, 不是绝对值")

**What to build:**
137 tests / 4 issues 全在 `LayoutShellViewModelTests`. 测试期望值用绝对 PT (editorW=797, aiChatW=1519, 上 band sum=1917) = 8/18 旧 LayoutTokens 值. LayoutTokens 8/19 改 794/1518 (mcp__sketch__run_code 真值, ticket 012 commit `a513b67`), 实现 `totalW * ratio` 算出来正确 (794/1518/1914), 但测试期望值仍写死旧绝对 PT.

老板 2026-08-19 拍: "现在实现的都是按比例, 不是绝对值了, A 这个事清掉, 别修了". 死原则 = "已实现代码 = 死原则, 不动" (LayoutTokens 真值 794/1518 不动). 修测试期望值改用 ratio sum 校验, 不用绝对 PT.

**改完:**
- 测试期望值从绝对 PT 改成 ratio sum 校验 (跟 `totalW * LayoutTokens.ratio` 实现一致)
- 4 个 issues 清掉 (editorW / aiChatW sum / 上 band sum / 注释)
- swift test exit 0 (137/137 pass)
- 不改 LayoutTokens 真值 (794/1518 保留)
- 不改 LayoutShellView / LayoutShellViewModel / NativeSplitter 实现

**Blocked by:** None

**Status:** ready-for-agent → impl done → commit (老板 8/19 自行决策授权 + 不需要验收)

## Acceptance criteria
- [ ] Tests/WenshuAppTests/Layout/LayoutShellViewModelTests.swift 默认 ratio test 改用 `vm.editorWRatio == Double(LayoutTokens.editorWRatio)` 校验 (ratio, 不用 editorW=794 绝对值)
- [ ] 上 band sum test 改用 `abs(sum - 1.0) < 0.0001` ratio sum 校验 (200+520+794+400 = 1914 ≠ 1920, 但 ratio 加和 = 1914/1920, 用 1.0 校验 = 总宽 ratio 守恒, 留 ±6 PT 给拖拽线占位)
- [ ] 下 band sum test 改用 `abs(sum - 1.0) < 0.0001` ratio sum 校验 (1518+400 = 1918/1920)
- [ ] 注释同步 (删 "editor 794 PT" "aiChat 1518 PT" "上 band 1914" "下 band 1918" 绝对值描述, 改 "ratio 跟 LayoutTokens 一致" "sum 加和 ratio 守恒")
- [ ] swift test exit 0 (137/137 pass)
- [ ] swift build exit 0 (0 warning)
- [ ] 不动 LayoutTokens / LayoutShellView / LayoutShellViewModel / NativeSplitter / DesignTokens
- [ ] 不动 hermes app / ~/.hermes/profiles/pocock/

## 业务语言描述 (老板懂)
- 实现走"按比例 × 总宽"算子 (任何窗口大小自适应), 测试期望值用绝对 PT 校验 = 旧范式, 改用 ratio 校验对齐实现
- 不改 layout 真值, 改测试校验方法
- 137 tests 全 pass

## 真值引用
- LayoutShellView 实现 (line 321-323, 355): `let editor = totalW * CGFloat(vm.editorWRatio)`, `let aiChatW = totalW * CGFloat(vm.aiChatRatio)` — 老板 8/19 拍 "用比例写" 范式
- v0.15 ticket 022.5 (commit a37c560f) 撤回 ticket 022 `.containerRelativeFrame` 改回 `LayoutTokens.ratio * totalW` (可拖拽 + 响应 resize)
- v0.15 ticket 012 (commit a513b67) LayoutTokens.editorWRatio = 794/1920, aiChatRatio = 1518/1920 (mcp__sketch__run_code 真值)
