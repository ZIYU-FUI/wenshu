# R79 skills 简介中文翻译落档（2026-08-30）

## 目标

将仓库 `skills/**/SKILL.md`（排除 `index-cache`）YAML frontmatter 中的 `description` 全部翻译为中文，让英文不好的用户能直接理解技能用途。

## 范围与策略

- 共枚举并修改 72 个 `SKILL.md`，每个文件只改 frontmatter 的 `description`。
- 保留 WENSHU、Yuanbao、Hermes、MCP、OpenAI、Anthropic、Claude、GitHub、API、CLI 等产品名和技术名。
- 将实际功能、操作和适用场景翻译为清晰中文。
- 未修改 skill 正文、`name`、版本、标签或其他 frontmatter 字段。
- 未修改 `plugins/`、`wenshu_cli/tools_config.py`、`zh.ts`、`en.ts`、白名单内容或上游版权。
- `apps/desktop/electron-main.mjs` 为既有未跟踪文件，未触碰、未暂存。

## 官方资料

已检查 i18next Translation Function Essentials：
https://www.i18next.com/translation-function/essentials

本轮仅涉及静态 YAML frontmatter 文案，不新增或修改 i18next key。

## 验证

- 文件枚举：72。
- frontmatter：72/72 均包含唯一且非空的 `name` 与 `description`。
- 中文检查：72/72 个 `description` 均包含汉字；无纯英文简介残留。
- YAML 解析：72/72 frontmatter 可成功解析。
- 改动形状：72 个 skill 文件均只改 `description`；另新增本落档文件。

## 提交边界

R78 工具/插件简介翻译作为独立提交保留；R79 仅提交上述 72 个 skill 文件和本落档，随后推送 `origin/main`。
