# ADR-0005: Document = 3-class MD model (chapter / setting / reference)

> Status: accepted
> Date: 2026-08-18
> Decision-maker(s): 老板 (8/18)

## Context

老板 8/18 拍 Editor zone content = 3-class document grid (chapter / setting / reference), not a single markdown document stream. Pre-v0.07, `BookOutlineView` used .environment(library) but the categorization dimension was Book, not Document. 老板 8/18 answered Q3: 3 blue rectangles = future ICON placeholder, implementation does not render them but reserves space (180 PX wide, 60 PX equal spacing).

## Decision

`Document` data class has 3 categories: chapter / setting / reference. `BookOutlineView` fetches Documents by Book.id and renders 3 sections. Each zone content = DocumentCard (implemented in v0.09+).

## Consequences

- Book does not directly contain markdown; instead it contains a list of Documents
- 3 blue rectangle ICON placeholders reserve 180 PX width; drop the actual ICON design in directly when finished

## Alternatives considered

- Single markdown string — rejected, 老板 拍 3-class
- NSDocument (Apple NSDocumentController) — deferred, not in current scope
- Apple Notes-style link database — deferred until v0.10+