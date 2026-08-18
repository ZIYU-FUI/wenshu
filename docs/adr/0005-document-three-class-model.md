# ADR-0005: Document = 3-class MD 模型 (章节 / 设定 / 资料库)

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍 Editor zone 内容 = 3-class 文档网格 (章节 / 设定 / 资料库), 不是单 markdown 文档流. v0.07 之前 `BookOutlineView` 走 .environment(library) 但分类维度是 Book, 不是 Document. 老板 8/18 答 Q3: 3 蓝矩形 = 未来 ICON 占位, 实现不渲染仅留空间 (180 PX 宽, 60 PX 等距).

## Decision

`Document` 数据类 3 个 category: chapter / setting / reference. `BookOutlineView` 按 Book.id 拉 Documents, 3 个 section 渲染. 每个 zone 内容 = DocumentCard (后续 v0.09+ 实现).

## Consequences

- Book 不直接含 markdown, 而是含 Documents 列表
- 3 蓝矩形 ICON 占位预留 180 PX 宽, 未来 ICON 设计完直接插

## Alternatives considered

- 单 markdown 字符串 — 拒绝, 老板 3-class 拍
- NSDocument (Apple NSDocumentController) — 推迟, 当前 scope 不需
- Apple Notes 同款链接数据库 — 推迟, v0.10+ 再说
