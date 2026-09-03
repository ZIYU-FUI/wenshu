# Issue 02 — AI thumbnail generation for reference cards

## What (= scope)

Each reference card gets an AI-generated cover image (= thumbnail). Two providers: DashScope (优先) + OpenAI fallback. Generation runs **asynchronously** during LLM Wiki entity ingestion (= not blocking chat). Thumbnail cached at `<.ws>/reference-library/cache/thumbnails/<uuid>.webp` (= wenshu AGENTS §11.1 already-planned thumbnail cache location).

Reference Card-master `image-generation-protocol.ts` + `dashscope-images-adapter.ts` + `openai-images-adapter.ts` provider abstraction.

## Why (= rationale)

Boss 2026-09-02 OOB verbatim: '我在让卡片缩略图,有内容可以显示,就是复刻卡片大师的 AI 生成动态卡面的能力,只不过我们是生成缩略图'.

## Apple-API-first check

- Custom code: a hand-rolled `ImageGenService` (= URLSession + JSON Codable + provider selection).
- Apple HIG candidate: `URLSession.data(for:)` (= macOS 12+; native async/await API; no third-party HTTP client needed).
- Apple coverage: full (= ImageGenService can use URLSession directly; no need for Alamofire or similar).
- LOC delta: ~400.
- Risk: med (= provider API differences; response parsing for image gen is non-standard; storage quota).

## Provider selection (= boss Q34 grill recommendation)

- DashScope (= 阿里 DashScope image gen API) primary: domestic speed, boss has bilibili background (= natural fit).
- OpenAI fallback: international reliability.
- Provider switching via `ImageGenProtocol` (= Card-master pattern; 1 protocol per provider; registry pattern in `Sources/WenshuApp/AI/ImageGen/`).

## Files touched

- `Sources/WenshuApp/AI/ImageGen/ImageGenProtocol.swift` (NEW): protocol + Provider enum + request/response models.
- `Sources/WenshuApp/AI/ImageGen/DashScopeImageGenAdapter.swift` (NEW): DashScope adapter.
- `Sources/WenshuApp/AI/ImageGen/OpenAIImageGenAdapter.swift` (NEW): OpenAI adapter.
- `Sources/WenshuApp/AI/ImageGen/ImageGenService.swift` (NEW): orchestrator (= pick provider, retry, cache write).
- `Sources/WenshuApp/Domain/Reference.swift`: add `coverImageUrl: URL?` + `coverImageStatus: CoverImageStatus` (= pending / generating / ready / failed / none).
- `Sources/WenshuApp/Storage/FileSystemReferenceStore.swift`: on entity write, enqueue thumbnail generation (= async Task).
- `Sources/WenshuApp/UI/ReferenceCard/ReferenceCardView.swift`: show cover image when `coverImageStatus == .ready`.

## Acceptance criteria

- [ ] 2 adapters (= DashScope + OpenAI) implement the same `ImageGenProtocol` (= testable in isolation).
- [ ] `ImageGenService` picks the configured provider; retries with the other provider on failure.
- [ ] Thumbnail written to `<.ws>/reference-library/cache/thumbnails/<uuid>.webp` (= Apple macOS sandbox-respecting path).
- [ ] LLM Wiki entity write returns immediately (= thumbnail generation is `Task.detached` async).
- [ ] `ReferenceCardView` shows: placeholder (= SF Symbol "photo") when pending; actual cover image when ready; error icon (= SF Symbol "exclamationmark.triangle") when failed.
- [ ] macOS screenshot confirms thumbnail rendering on at least one reference card.
- [ ] Test file: `ImageGenService.test.ts` (mirror of Card-master's `dashscope-images-adapter.test.ts`).

## Implementation ticket chain

1. Build `ImageGenProtocol` + Provider enum + Codable models.
2. Build DashScope adapter + unit test (= uses fixture JSON in `Tests/Fixtures/dashscope-success.json`).
3. Build OpenAI adapter + unit test.
4. Build `ImageGenService` orchestrator + retry logic.
5. Wire into `FileSystemReferenceStore.upsert` (= fire-and-forget Task).
6. Wire into `ReferenceCardView` (= display cover image + placeholder states).
7. Build + screenshot.

## Dependencies

- Issue 01 (= ReferenceCardView must exist before this issue wires cover image into it).

## References

- Boss OOB 2026-09-02: '复刻卡片大师的 AI 生成动态卡面的能力,只不过我们是生成缩略图'
- Source: Card-master `src/ai/infrastructure/dashscope-images-adapter.ts` + `openai-images-adapter.ts` + `image-generation-protocol.ts`
- Spec: `.scratch/2026-09-02-card-master-port/spec.md` §3 item 2

First line: fact. Last line: fact.