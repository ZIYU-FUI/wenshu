AGENTS.md

# Hard rule (project-wide, non-negotiable)

- This file is English only. No Chinese characters. No CJK punctuation. No mixed CJK + Latin characters.
- All commit messages, comments, prompts, `.scratch/spec.md`, `.scratch/issues/`, `.scratch/backlog` files, `CONTEXT.md`, `README.md`, `CLAUDE.md`, and every doc in this repo follow the same English-only rule.
- Sole address for the user = "老板" (the literal characters). No earlier honorific forms.
- Forbidden neutral words: 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. Replace with: 是 / 否 / 行 / 不行 / 可以 / 不可以 / 不变 / 变.
- Forbidden Chinese vocabulary: 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. Historical note: 修真 = an earlier agent's typo for 修正. Use 修 / 改 / fix / 替换 / 调整 in commit body / comment / doc / prompt / card body.
- First line of every doc = fact. Last line of every doc = fact.

This file = wenshu project baseline + cross-role address hard constraint. Single agent (pocock profile) direct dialog with 老板. No dispatch, no board, no 6-role flow. Version 8/18拍 v0.07 (pocock single agent purified version).

# §11 Project baseline

- Stack = Swift / SwiftUI + Swift Observation (@Observable) + filesystem JSON + Markdown (per-book private content) + Apple HIG (.fcpbundle-style directory, single-process). NO CoreData. NO external AI platform calls (any code file).
- v0.27 boss OOB: "从今天开始，任何功能，先查有没有三方库可以用。不重复造轮子是对的。我之前说不引入三方给自己挖坑了" = wenshu stack baseline 修正 — 第三方库允许（前提 = 见 §11.1 UI 控件例外清单）。
- v1 LLM provider supports minimax cn only (Anthropic-compatible protocol).
- `.ws` directory (= macOS package, NSOpenPanel-selected at onboarding) = per-library container. Holds: Info.plist (= Apple HIG bundle metadata; CFBundlePackageType=WSPC + WSSchemaVersion) + chat.sqlite (= global LLM chat history; 45 KB at v0.24 ship) + Icon (= Finder icon) + shelves/ (= user-created bookshelves; multiple) + reference-library/ (= library's default bookshelf; system-managed, ONE instance, user CANNOT delete or rename; holds LLM Wiki 4 layers: raw/ + entities/ + abstracts/ + indexes/) + cache/ (= thumbnails + search index + export temp). Per-book structure = `shelves/<shelf-uuid>/books/<book-uuid>/` with 8 standard folders (world/ characters/ outlines/ chapters/ drafts/ sessions/ foreshadowing/ placeholders/) + 8 JSON sidecars + 2 per-book JSON data files (kanban.json, todo.json). Per-book private world + characters + foreshadowing + placeholders; reference-library is library-public (= cross-book reusable raw materials).
- Apple stack exclusive (macOS / iPad / iPhone). Current target = macOS-only single platform (老板 8/18 拍).
- Project root = `/Volumes/ANAN/Engineering/wenshu/`.
- Apple Developer Program paid on release (individual $99 / year).
- Version format = three digits (Hermes style): middle digit = phase, third digit = hotfix.
- 3 docs = this file + `README.md` + `CLAUDE.md`. `CONTEXT.md` = domain glossary (see `docs/agents/domain.md`).
- No hermes monorepo trace (no longer fork).
- No Tauri / Rust / SQLite / Vue 3 trace.
- No sparse-clone assumption.
- No novel-platform / novel-craft / Hermes-Slate-Desk legacy V0.5.x protocol.
- Do not decide LLM key config for 老板.
- Do not create project dir outside `~/wenshu-plugin/` (legacy plugin era, retired).
- Do not write any file to `~/.wenshu/` (dir retired).
- Do not self-write wenshu CLI (文枢 = Swift desktop app, not CLI).
- Do not touch any hermes self-owned file under `~/.hermes/`.
- Do not touch any file under `.archive/wenshu-monorepo-fork/`.
- Single-shelf model (= boss 2026-08-26 OOB): user has exactly one `.ws` library; onboarding is one-time; switching `.ws` paths requires Library Properties panel "Reset Library" (= clears UserDefaults.wenshu.libraryPath + returns to onboarding).

# §11.1 Third-party library policy (boss 8/27 OOB)

- Default = Apple stack exclusive (= Apple官方 SwiftUI / AppKit only).
- Exception: Apple官方 SwiftUI 不支持 / 实现困难的功能 = 允许第三方库。
- Acceptance criteria (= 4 conditions ALL must hold):
  1. GitHub stars >= 100 (community认可; = 项目级别信誉).
  2. Last commit within 12 months (= active maintenance; macOS 27 兼容保证).
  3. License = MIT / Apache / BSD / public domain (= commercial 兼容).
  4. macOS-first OR macOS-supported (= iOS-only 库不接受).
- Approved third-party exceptions (as of 2026-08-27):
  - `stevengharris/SplitView` — 216 stars, MIT, macOS-first, v3.5 (= wenshu splitter 控件).
  - `Sameesunkaria/OutlineView` — 78 stars (BELOW 100 — provisional; revisit when >= 100) — wenshu tree view candidate.
- Pending evaluation (= not yet adopted; needs demo + boss拍):
  - `nodes-app/swift-markdown-engine` — AppKit TextKit 2 + SwiftUI bridge (= future wenshu markdown editor).
  - `gonzalezreal/Textual` — markdown render successor (= future wenshu editor render).

# §12 Cross-role expression hard constraint

- Sole address for 老板 = 老板. Every dialog / doc / commit message / comment / prompt uses 老板.
- No earlier honorific forms allowed.

---

*AGENTS.md v0.07.4 · 2026-08-27 pocock single agent · FCP library replica + new .ws layout (shelves/ + reference-library/) + per-book 8 folders + 2 JSON data files + Apple @Observable (no CoreData) + §11.1 third-party library policy + stevengharris/SplitView approved exception · English-only · project root = /Volumes/ANAN/Engineering/wenshu/*