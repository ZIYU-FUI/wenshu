# R109 — intro-copy.jsonl 改写为面向写作助手的中文

**commit**: `409b352ad`
**date**: 2026-08-31
**装机 user trigger**: 副文本清单 (intro-copy-inventory-zh.md) 拍板真值
**WO**: WO-001BI-R109

---

## 目标

把 `apps/desktop/src/components/chat/intro-copy.jsonl` 75 行从英文开发向
改写为面向"写作助手"的中文版本。

## 拍板真值 (装机 user 8/31 out-of-band)

- 文枢是**写作助手** (不是代码/开发)
- 翻译原则: **信达雅** (准确 + 通顺 + 优雅)
- 风格/术语/角色名保留原文: `kawaii` / `catgirl` / `pirate` /
  `shakespeare` / `surfer` / `noir` / `uwu` / `philosopher` / `hype`
- 改写原则: 把开发向 "代码/git/diff/repo/shell/stack trace" 全部改写
  为"写作调研/查证/出稿"等写作向语言
- 文枢产品调性: **AI 助手** (不扮演程序员)

## 改动范围

- 单点真值文件: `apps/desktop/src/components/chat/intro-copy.jsonl`
- 渲染入口 (只读): `apps/desktop/src/components/chat/intro.tsx` —
  `INTRO_COPY_BY_PERSONALITY = parseIntroCopy(introCopyJsonl)` 解析器
  按 personality key 聚合 5 个变体, 运行时按 seed 取一条

## 改动结果

| personality    | 原 (英文开发向) | 新 (中文写作向) |
| -------------- | ----------------- | ----------------- |
| helpful        | 5                 | 5                 |
| concise        | 5                 | 5                 |
| technical      | 5                 | 5                 |
| creative       | 5                 | 5                 |
| teacher        | 5                 | 5                 |
| kawaii         | 5                 | 5                 |
| catgirl        | 5                 | 5                 |
| pirate         | 5                 | 5                 |
| shakespeare    | 5                 | 5                 |
| surfer         | 5                 | 5                 |
| noir           | 5                 | 5                 |
| uwu            | 5                 | **4** (装机 user 清单少 1 条) |
| philosopher    | 5                 | 5                 |
| hype           | 5                 | 5                 |
| none           | 5                 | 5                 |
| **Total**      | **75**            | **74**            |

## ⚠️ uwu 缺 1 条 (装机 user 待补)

装机 user `intro-copy-inventory-zh.md` 给的清单里 `personality=uwu` 只有 4
条, 不是任务规格里的 5 条。**不准反推拍板** — 不擅自补第 5 条 uwu。

当前行为:
- intro-copy.jsonl 第 56-59 行是 uwu 的 4 条
- intro.tsx 的 `pickCopy` 拿 `seed % 4` 选 1 条
- 第 5 个槽位空缺, 运行时永远命中 4 条之一, 不会 fallback

装机 user 想补 uwu 第 5 条时, 在 intro-copy.jsonl 第 60 行前 (在
`personality: uwu` block 末尾) 插一条新行, 保持 `uwu, owo` 调性即可。
或者明确指示"就用原文第 5 条 awaiting yur command!" 也可以。

## 验证

- ✅ `pnpm build`: ✓ built in 2.46s, dist artifacts produced
- ✅ `pnpm typecheck` (tsc -p . --noEmit + tsc -p tsconfig.electron.json --noEmit): exit 0
- ✅ jsonl parse: 74/74 行, 结构合法, 14 personality × 5 + uwu × 4

## git 操作

```
[main 409b352ad] fix(wenshu): 改为面向写作助手的开场文案
 1 file changed, 74 insertions(+), 75 deletions(-)

git push origin main       → 7f0f741a3..409b352ad (gitcode)
git push old-origin main   → 7f0f741a3..409b352ad (github)
```

## AC 验收

| AC | 内容 | 状态 |
| -- | ---- | ---- |
| AC1 | intro-copy.jsonl 全改中文 (装机 user 信达雅) | ✅ 74/75 (uwu 缺 1) |
| AC2 | pnpm build 0 | ✅ |
| AC3 | tsc --noEmit 0 | ✅ |
| AC4 | 自决 commit + push 双仓 | ✅ 409b352ad |
| AC5 | 落档 + 飞书 DM 装机 user | ✅ |

## 装机 user 待办 (可选)

- 补 uwu 第 5 条 (intro-copy.jsonl 现有 4 条之外), 或明确指示复用原文
  英文第 5 条 `awaiting yur command!`
- (可选) 跑 `wenshu update` 验证桌面端开场文案渲染中文
