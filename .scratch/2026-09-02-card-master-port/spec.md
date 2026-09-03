# Card-master port — wenshu 借鉴 11 项工程机制

## Status

- Author: pocock single-agent
- Branch: wt/multi-agent-dispatch
- Date: 2026-09-02
- Spec status: spec accepted by boss 2026-09-02 OOB 'A 全做, 走八步研发方法论'
- Implementation status: not started (this is the spec commit only)

## Hard rule (project-wide, non-negotiable)

- English only. No CJK characters or punctuation.

## §0. Why this spec exists

Boss 2026-09-02 OOB chain:

1. Boss asked me to inspect the [Card-master-browser-extension-public](https://github.com/LYiHub/Card-master-browser-extension-public) project and report how it generates dynamic cards (= AI script workshop → userscript card with cover image + animation).
2. Boss拍 3 specific items to port:
   - **A. Reference card fixed format**: every wenshu reference (= `.scratch/reference-library/entities/<uuid>.md`) has a single canonical title + 1-sentence summary, displayed uniformly across the app. Reference Card-master `cards.ts` `cardTitle()` + `cardDescription()` 4-derive pattern.
   - **B. AI thumbnail generation**: every reference card has an AI-generated cover image (= DashScope or OpenAI image gen). Reference Card-master `image-generation-protocol.ts` + `dashscope-images-adapter.ts` + `openai-images-adapter.ts`.
   - **C. Boss asks me to enumerate other Card-master mechanisms worth porting** (agent free to suggest).
3. I enumerated 8 additional items (C1-C8) from the Card-master source tree:
   - C1: `preflight.ts` = write-then-validate pattern
   - C2: `script-repository` `replaceAll()` atomic write
   - C3: `assistant-presentation.ts` user-facing error translation
   - C4: `assistant-readiness.ts` system capability check
   - C5: `AiConversationSnapshot` immutable model + transact
   - C6: SSE streaming for Responses API
   - C7: capability registry pattern
   - C8: `upstreams.json` + `THIRD_PARTY_NOTICES.md` transparency

Boss拍 'A 全做' = all 11 items in scope. This spec covers the design; each ticket in `issues/` covers 1 item.

## §2. The 11 items, ranked by impact × risk

| # | Item | LOC | Apple coverage | Risk | ROI |
|---|---|---|---|---|---|
| 1 | A. Reference card format | ~250 | partial (SwiftUI Label + .regionContentBackground) | low | 1st |
| 2 | B. AI thumbnail generation | ~400 | full (URLSession async) | med | 2nd |
| 3 | C8. upstreams.json + THIRD_PARTY_NOTICES.md | ~100 | n/a (data file) | low | 3rd |
| 4 | C1. WikiEntityPreflight | ~200 | partial (Codable validate) | low | 4th |
| 5 | C4. WenshuReadinessCheck | ~150 | partial (StatusBarController) | low | 5th |
| 6 | C3. UserFacingError | ~120 | n/a (string mapping) | low | 6th |
| 7 | C6. SSE streaming for chat | ~350 | full (URLSession.bytes) | med | 7th |
| 8 | C5. ChatSnapshot + ChatStore.transact | ~250 | partial (@Observable) | med | 8th |
| 9 | C2. WorkspaceStore.replaceAll | ~150 | n/a (atomic write) | low | 9th |
| 10 | C7. Capability registry | ~180 | partial (factory) | med | 10th |
| 11 | C8a. Third-party notices automation | ~80 | n/a (build script) | low | 11th |

## §3. Apple-API-first gate (= per `wenshu-apple-api-first` skill)

For every change that writes `.swift` code in `Sources/WenshuApp/`:

1. State the Apple-API-first check explicitly in each issue.
2. Run grep before writing (= `web_extract developer.apple.com/documentation/swiftui` per candidate).
3. If a self-built helper already exists for this use case, REUSE it (= check `Sources/WenshuApp/UI/ComponentIndex.md`).
4. Document gaps where Apple has no API.

## §4. Out of scope (= don't port)

- Browser extension runtime (= Card-master's userscript engine = out of scope; wenshu is macOS desktop, not browser).
- Card game chrome (= GWENT-inspired card spread / deck grid / shadow motion = out of scope; wenshu is a writing workspace, not a card game).
- Cross-platform build (= Card-master builds Chromium / Firefox / Safari from one codebase via vendor/ src/ split; wenshu is macOS-only per AGENTS §11 hard rule).

## §5. Acceptance criteria

For each of the 11 items:

- [ ] Apple-API-first check documented in the issue body.
- [ ] `git grep` confirms zero callers outside the changed files (= new helpers are self-contained).
- [ ] `bash Scripts/build-app.sh` exits 0.
- [ ] macOS UI screenshot per visual change (= boss rule '不要只看代码, 对比截图实测').
- [ ] If the commit retired a self-built helper: confirm zero remaining callers BEFORE committing.
- [ ] If the commit kept a self-built helper with a documented gap: confirm the gap note appears in the file's header doc-comment.
- [ ] Commit body in `chore(wenshu): ... -- <verb> <object>` format. English-only per AGENTS §11.

## §6. Commit chain (= 1 issue = 1 commit)

Q29 hard constraint: 1 ticket = 1 commit. Issues land in numerical order; boss拍 each before moving to the next.

| Order | Issue | Title | Commit prefix |
|---|---|---|---|
| 1 | 01-reference-card-format.md | Reference card fixed format | `chore(wenshu):` |
| 2 | 02-ai-thumbnail-generation.md | AI thumbnail generation | `feat(wenshu):` |
| 3 | 03-upstreams-json.md | upstreams.json + THIRD_PARTY_NOTICES.md | `docs(wenshu):` |
| 4 | 04-wiki-entity-preflight.md | WikiEntityPreflight | `fix(wenshu):` |
| 5 | 05-wenshu-readiness-check.md | WenshuReadinessCheck | `feat(wenshu):` |
| 6 | 06-user-facing-error.md | UserFacingError | `fix(wenshu):` |
| 7 | 07-sse-streaming-chat.md | SSE streaming for chat | `feat(wenshu):` |
| 8 | 08-chat-snapshot-transact.md | ChatSnapshot + ChatStore.transact | `fix(wenshu):` |
| 9 | 09-workspace-store-replace-all.md | WorkspaceStore.replaceAll | `fix(wenshu):` |
| 10 | 10-capability-registry.md | Capability registry | `fix(wenshu):` |
| 11 | 11-third-party-notices-automation.md | Third-party notices automation | `chore(wenshu):` |

## §7. Per-issue dual-axis review (= per wenshu Q37 hard constraint)

Each ticket triggers a dual-axis sub-agent review after the patch is in (= no boss confirmation between implement and dual-axis per boss 8/25 OOB protocol):

- **Standards axis** (deleg_0ce6ad1a style): checks wenshu hard rules (= AGENTS.md §11 English-only, Q49 single-subject commit, Q35 verbatim reference of boss OOB).
- **Spec axis** (deleg_546dc1bd style): checks the issue acceptance criteria are met.

Dual-axis reports verbatim-quoted into the fix commit body when fix is needed.

## §8. References

- Boss OOB 2026-09-02 verbatim: '我想在聊天触发调研的时候,或者写MD文件的时候,除了 LLM WIKI 机制,还有一套生成固定卡片格式的机制,这样可以让卡片的样式同意...有标题,有 一句话说明这个文件写了什么,很简洁的一句话,卡片只显示这句概论,引用MD的正式段落'
- Boss OOB 2026-09-02 verbatim: '我在让卡片缩略图,有内容可以显示,就是复刻卡片大师的 AI 生成动态卡面的能力,只不过我们是生成缩略图'
- Boss OOB 2026-09-02 verbatim: '其它工程上的机制我不太懂,你看着定,觉的有什么好的思路可以复刻的也列出来'
- Boss OOB 2026-09-02 verbatim: 'A,全做,走八步研发方法论'
- Source repo: `github.com/LYiHub/Card-master-browser-extension-public` (browsed via GitHub API on 2026-09-02)

First line: fact. Last line: fact.