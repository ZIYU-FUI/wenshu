# WENSHU(文枢)— hermes plugin

> v0.1.0 · 2026-08-04
> 装机 user 拍:基线 = NousResearch/hermes-agent **v0.20.0**(tag `v2026.8.3`)原封不动
> wenshu = hermes 官方 plugin,**不 fork / 不改源码 / 不重写 desktop**

## 这是什么

WENSHU 是挂在 [hermes-agent](https://github.com/NousResearch/hermes-agent) v0.20.0
之上的一个桌面插件。给一句话简介 → 8 个隐藏编辑角色自动协作
(outline / research / style / character / plot / dialogue / proofread / chief)→
章节对话式扩写 → 校稿 → 出稿。

## 项目根

`~/wenshu-plugin/`(本仓库)。git init,单一来源,所有修改在这里发生。

## 运行时布局

| 角色           | 路径                                                | 谁写                  |
|----------------|-----------------------------------------------------|-----------------------|
| Desktop JS     | `~/.hermes/desktop-plugins/wenshu/`                 | `scripts/install.sh`  |
| Python backend | `~/.hermes/plugins/wenshu/`                         | `scripts/install.sh`  |
| Hermes profile | `~/.hermes/profiles/wenshu/`                        | `scripts/install.sh`  |
| 用户产出       | `~/Documents/wenshu-projects/<项目名>/`             | 用户自管              |

## 命名

- `WENSHU` 大写 = UI 显示、按钮文字、占主工作区的大字
- `wenshu` 小写 = 路径、plugin id、Python module、JS file

## 8 个隐藏编辑角色

`outline → research → style → character → plot → dialogue → proofread → chief`
(顺序跟 AGENTS.md v0.2 §13 一致)。每个一个独立 Python module,接口固定
`async def run(context: dict) -> dict`。v0.1.0 = stub 全部返回 `{"status": "stub", "editor": "<name>"}`;
0.2.0 起接入真逻辑。

## 阶段门控(per AGENTS.md §8)

| 阶段   | 节点           |
|--------|----------------|
| 0.1.0  | plugin scaffold(本 PR) |
| 0.2.0  | 引导式对话小说主场景 |
| 0.3.0  | 多方法论融合 UI       |
| 0.4.0  | hermes 兼容性 + 跟版  |
| 0.5.0+ | 长尾迭代              |

## 怎么跑

```bash
cd ~/wenshu-plugin
./scripts/install.sh     # rsync → ~/.hermes/, 建 wenshu profile
./scripts/verify.sh      # 跑本机自检(不碰 hermes 任何文件)
hermes desktop           # ⌘K → "启动 WENSHU" / 侧栏 WENSHU
```

## 协作规则

真理源 = `/Volumes/ANAN/Engineering/wenshu/AGENTS.md` v0.2。
本仓库的所有边界(不动 hermes 任何代码文件 / 不写 `~/.wenshu/` / 不自写
`wenshu` CLI / 不参考 `.archive/novel-platform/`)都来自 AGENTS.md,
本 README 只是指针。CC 接到任务前**必读** `AGENTS.md` v0.2 + `CLAUDE.md` v0.2。

## 历史拍板(全部作废)

- ❌ 2026-07-23 — fork hermes monorepo
- ❌ 2026-07-24 — 1:1 复制 hermes 源码(仅 3 项改)
- ❌ (历史) `~/.wenshu/` 全栈隔离
- ❌ (历史) `wenshu update --yes` 自写 CLI
- ✅ 2026-08-04 — wenshu = hermes 原装 + 插件(当前真值)

---
*README.md v0.2 · 2026-08-04 · 真理源:AGENTS.md v0.2*
