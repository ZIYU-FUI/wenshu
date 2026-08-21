# 24 — 编辑框一整条 Apple 标准出现/消失动画真硬真值

依赖: ticket 21 + 22 + 23 commit

**What to build:**
撤 .formStyle(.grouped) 拦截 (1 行 patch) = 编辑框一整条出现/消失 Apple 默认动画生效

**Why:**
老板 2026-08-22 07:14 拍 "红框内一整条没出现/消失动画" + 授权 agent 按核心原则自主推进. Q28 查文档真值: Apple SwiftUI .formStyle(.grouped) 拦截 .transition + .animation = 老板看到"瞬时".

**Acceptance:**
- 老板 macOS 真验: 编辑框一整条 (红框) 出现/消失 Apple 默认动画优雅
- swift build exit 0
- swift test exit 0 (ProviderKeychain 5/5 pass)
- 双轴 code-review verbatim 进 commit body