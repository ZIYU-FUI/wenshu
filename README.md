# 文枢 (Wenshu)

> **Apple-stack-exclusive long-form fictional-novel AI authoring platform** · Swift + SwiftUI + CoreData + self-built lightweight AI kernel
> 老板 (investor) · Status: **v0.00.0 project baseline (2026-08-06 老板 拍板)** · Strategy: **conversation-driven + Scrivener-class project management + AI fallback. 老板 configures LLM key and uses.**

---

## 1. What it is

**文枢 = AI authoring platform for people who have a long-form novel idea but cannot write**. On macOS, iPad, iPhone, wenshu delivers the full long-form authoring workflow — from one vague idea to a complete novel. 老板 only talks naturally, chooses, and decides. All tedious work (research, extrapolation, revision, foreshadow management, state sync) is handled by AI fallback.

**Core promises** (2026-08-06 老板 拍板):

- **Out-of-the-box** — 老板 configures LLM key once in 文枢 (v1 supports minimax cn only) and uses it. **No AI tool expertise required**.
- **No external AI runtime** — 文枢 = Swift / SwiftUI native desktop app + self-built lightweight AI kernel. No external AI agent processes called, no AI platform configs read.
- **Idea → value instantly** — 老板 says one idea; AI extrapolates immediately; project structure grows in sync. The old "deposit to external doc, no flow back" failure mode does NOT repeat.
- **Boss is volatile; AI fallback covers** — protagonist from constable to coroner, dynasty from Ming to fictional — any major change AI auto-refactors related settings, generates revision candidates without overwriting original text.
- **Personal asset self-managed** — project data = `.ws` single file (CoreData + attachments). Local storage. Copyable, backup-able, cross-device copy. 文枢 depends on no cloud service, requires no account.

## 2. What it is NOT

- **NOT any AI platform plugin** — 文枢 reuses no external AI process, calls no AI platform CLI, assumes 老板 installed no AI tool.
- **NOT any AI platform fork** — 文枢 is not built on any AI platform modified source, inherits no monorepo Electron + Python stack.
- **NOT generic AI writing tool** — 文枢 serves long-form fictional novel only. No short story, screenplay, non-fiction, web-novel sugar-hit snippets.
- **NOT pure writing software** — 文枢 is not just an editor. AI actively intervenes, has structured understanding of project state, is consistent across processes / devices.
- **NOT cloud SaaS** — 文枢 depends on no cloud service, requires no account, does not upload 老板's works.
- **NOT cross-platform** — v1 supports macOS / iPad / iPhone only. Windows / Android / Apple Watch / Vision Pro = no. HarmonyOS = TBD (if supported, native rewrite — do NOT reuse this repo).
- **NOT 12Immortals replay** — 12Immortals failure mode (chat is a tool, notes are a tool, no connection between them, AI output deposits with no flow back) does NOT repeat. 文枢's chat, project structure, settings, body share one common internal state.

## 3. Architecture

```
文枢 (single-process Swift / SwiftUI app)
├── Main process (MainActor)
│   ├── User chat layer (always responsive, never blocks)
│   ├── Stage gate logic (idea discussion / settings / outline / body)
│   ├── @ syntax parse (reference project elements)
│   ├── Board (main stage smart filter + detail page full expand)
│   └── Revision candidate display (post-confirm, redline + sidebar history)
│
├── Background task (Swift Concurrency)
│   ├── LLM call (minimax cn, Anthropic-compatible protocol)
│   ├── Streaming SSE parse (byte-level accumulation, event sequence: message_start → content_block_start → content_block_delta → content_block_stop → message_delta → message_stop, no [DONE])
│   ├── Chapter summary generation
│   ├── Resource research
│   ├── Revision candidate generation
│   ├── Style distill
│   └── Foreshadow / fact-check
│
├── Store actor (CoreData write serialization)
│   ├── CDCharacter (character)
│   ├── CDChapter (chapter)
│   ├── CDNote (todo / foreshadow / info-point / historical fact)
│   ├── CDWorldRule (world rule)
│   ├── CDForeshadow (foreshadow list, with state machine)
│   ├── CDRevision (revision candidate, with original-text link)
│   └── CDAIDraft (AI inference, with confidence)
│
└── .ws single file (local storage, cross-device copy)
    ├── CoreData store (character / chapter / setting / foreshadow / revision)
    ├── Attachment bundle (uploaded samples, distill model cache)
    └── Resource dir (cover, artwork)
```

**Key architectural principles**:

- **Long-term memory ≠ LLM context** — LLM does NOT read the entire project state directly. Through search interface it gets the minimum info set for the current task (chapter summary + related characters + related foreshadow + selection context).
- **Main process always responsive** — background task uses Swift actor to serialize CoreData writes; main process never blocks.
- **Cross-device via file** — `.ws` file = CoreData store. Cross-device relies on 老板's copy or self cloud (iCloud / OneDrive / Git / USB). 文枢 is unaware.
- **Multi-device multi-entry via master router** — iPhone-recorded ideas MUST go through master process. No direct modification of main project. Avoids multi-end concurrent overwrite.

## 4. Stage goals

| Stage | Goal | Status |
|-------|------|--------|
| **v0.00.0** | Project baseline = 3 docs finalized (README / AGENTS / CLAUDE archived) + Swift package init + CoreData single file + minimax cn LLM access (Anthropic-compatible) | **current** |
| **v0.01.0** | Minimal closed loop: create project → write one-sentence story → AI extrapolate → 老板 choose → generate character / world skeleton (read-only display) | pending |
| **v0.02.0** | Full closed loop: chat-driven setting evolution + resource library background research + board real-time reflect + revision candidate no-overwrite + **5-zone layout grammar + collapse + drag (FCP-style, layout state stored in .ws)** (see AGENTS.md §8.1) | pending |
| **v0.03.0** | Stage gate: idea discussion → setting → outline → body. 老板 controls rhythm, AI judges maturity | pending |
| **v0.04.0** | Long-form tools: chapter drag cards + emotion curve + relationship graph + timeline + filler-level 1-9 + writing style | pending |
| **v0.05.0** | Marker system: `※` todo (shortcut + whole-chapter intercept) + foreshadow / info-point (selection right-click) + historical fact (AI judges) | pending |
| **v0.06.0** | iPhone end: idea record + chat authoring + project state view + marker system complete | pending |

## 5. Phase baseline rules

(Phase baseline rules = `AGENTS.md` §11 + §12. README does not duplicate. See `AGENTS.md` for the canonical list.)

## 6. Development workflow

```
老板 requirement (business language)
        ↓
pocock: grill-with-docs (clarify the requirement, leave paper trail)
        ↓
pocock: to-spec (collapse conversation into buildable spec, write to .scratch/<feature>/spec.md)
        ↓
pocock: to-tickets (split spec into one issue per file, .scratch/<feature>/issues/NN-*.md)
        ↓
pocock: implement per ticket (drive tdd internally)
        ↓
pocock: code-review (two axes — Standards + Spec — verify before commit)
        ↓
git commit (1 ticket 1 commit, spec + ticket follow code in same commit)
        ↓
老板 watches in Xcode
```

Per 老板 2026-08-21 拍 hard constraint: **dual-axis code-review is mandatory. Skipping it = fail. The failure chain v0.20 ticket 04 + 05 commit `0aabd989e` + `e474965` did NOT run dual-axis. 老板 verified and 拍 "go check official docs" redo.**

## 7. Data architecture diagram

```
┌──────────────────────────────────────────────────────────────┐
│  老板 (long-form novel idea, no writing experience)          │
│  ↓ macOS / iPad / iPhone SwiftUI natural chat               │
│  ↓ @ syntax references project elements                     │
│  ↓ Picker / Button selection                                │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Main process (MainActor)                                    │
│  - User chat layer (always responsive)                      │
│  - Stage gate / board render / revision candidate display   │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Background task (Swift Concurrency)                         │
│  - LLM call / streaming SSE parse                            │
│  - Chapter summary / research / revision candidate / style   │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  Store actor (CoreData write serialization)                  │
│  - character / chapter / setting / foreshadow / revision / AI draft │
│  - Assemble minimum context for LLM via search interface     │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼ Main process = .ws single-file read/write
┌──────────────────────────────────────────────────────────────┐
│  .ws (local CoreData store + attachments + resources)        │
│  - Cross-device via 老板's copy or self cloud (iCloud / OneDrive / Git / USB) │
│  - 文枢 depends on no cloud, unaware of which cloud 老板 uses │
│  - Multi-device multi-entry via master router, no concurrent overwrite │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  minimax cn LLM (Anthropic-compatible protocol, official recommended) │
│  - URL = https://api.minimaxi.com/anthropic/v1/messages      │
│  - Auth = X-Api-Key: *** (official error recommends; Bearer also OK) │
│  - Model = MiniMax-M3 (1M context) / M2.7 / M2.5 / M2        │
│  - Streaming SSE, byte-level accumulation, event sequence see §3 │
│  - No [DONE] terminator; ends at message_stop event           │
│  - key stored locally 0o600 (release version → macOS Keychain) │
└──────────────────────────────────────────────────────────────┘
```

## 8. Deployment architecture

- **Dev environment** = macOS 27.0 + Xcode 27 + Swift 6.4 + CoreData.
- **Test environment** = after macOS end passes, iPad / iPhone real-machine test (iOS 27 simulator pending Apple public release).
- **Production environment**:
  - Desktop = 文枢.app installed to `/Applications/文枢.app`.
  - Distribution = App Store release (before release pay Apple Developer Program individual $99).
  - Project data = `.ws` file (老板 self-managed, cross-device copy).

## 9. Collaboration rules (2026-08-18 v0.07 pocock single-agent purified)

- Single agent (pocock profile) direct dialog. No dispatch, no board, no 6-role flow.
- 老板 raises requirement → pocock writes code → 老板 watches effect. Along Matt Pocock main flow (grill-with-docs → to-spec → to-tickets → implement → code-review).
- 老板 appears at stage gate checkpoints (v0.00.0 / v0.01.0 / v0.02.0 / ...) to review product feedback.
- Project baseline / data asset / cross-role address hard constraints = truth-source `AGENTS.md`.

## 10. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| iOS 27 simulator unavailable, blocks iPad / iPhone dev | Sandbox writes macOS-only verification code. Wait for Apple public iOS 27 sim before backfilling. |
| minimax cn service outage | Retry + error display + offline local operation + task queue. |
| 老板 edits setting on iPhone, Mac end overwrites | Multi-device multi-entry via master router. Version-number compare. On conflict 老板 post-decides. |
| Revision candidates accumulate too many | Draft and official version managed separately. Periodic cleanup. 老板 triggers revision actively. |
| LLM-generated content drifts from 老板 intent | After each generation show impact summary. 老板 post-confirms. Never auto-overwrite. |
| Style distill has copyright risk | Distill only 老板-uploaded samples. Local-only storage. No cross-user sharing. |
| `.ws` file cross-device copy corrupted by cloud sync | Force store coordinator sync on close. Merge shm / wal files first. |
| CoreData cross-device version inconsistent | File-level version. Validate on open. On mismatch backup old + create new copy. |
| **minimax model name wrong silently fallback** (verified 8/6) | Task must explicitly write model name. CC validates against minimax official model list when writing provider config. |
| **X-Api-Key header missing or wrong** | Use minimax official recommended header. Error message clearly indicates. |

## 11. Key path quick reference

```
/Volumes/ANAN/Engineering/wenshu/                  ← ACTIVE (文枢 project root, v0.00.0 project baseline)
├── README.md                                      ← this file (project face)
├── AGENTS.md                                      ← collaboration rules truth-source (2026-08-18 purified to §11 §12)
├── CLAUDE.md                                      ← CC (future Claude Code) project memory
├── CONTEXT.md                                     ← domain glossary (see docs/agents/domain.md)
├── .hermes/                                       ← design drafts (v0.07 sketch truth-source etc.)
└── (empty — Swift package starts from v0.01.0)
---
/Volumes/ANAN/Engineering/.archive/
├── wenshu-monorepo-fork/
│   └── v0.x-monorepo-fork-2026-08-06/             ← old hermes monorepo fork archived (9.7 GB, read-only)
├── novel-craft/                                   ← historical archive
└── novel-platform/                                ← historical archive
---
~/Engineering/                                    ← sandbox (NOT in project dir)
├── llm-call-test/                                 ← experiment 4: minimax cn LLM call verification (Anthropic-compatible)
├── wenshu-arch-experiments/
│   ├── Exp5-CoreData/                             ← experiment 5: CoreData single-file persistence
│   └── Exp6-Concurrency/                          ← experiment 6: Swift Concurrency + CoreData serialization
└── (other research: writing-style-skill / book-writer / superpowers / etc.)
```

## 12. 12Immortals failure cause (avoid replay)

12Immortals = same novel deposited on two systems (`/Volumes/ANAN/Data/12Immortals` + OB vault `12-地仙`). Failure mode:

- Chat is a tool (dialog), OB is a tool (notes). No connection between them.
- AI output deposits to OB, no reverse flow into dialog.
- Settings become read-only notes. Cannot be referenced by later AI generation.
- Resource library detached from authoring flow.
- 老板 manually moves content between two tools.

文枢's solution:

- Chat, project structure, settings, body share one common internal state.
- When 老板 expresses new info, AI immediately forms corresponding artifact in project structure.
- Later dialog can reference previously formed settings.
- AI auto-reads existing project state before generating new content.
- Settings are NOT static files. Settings are continuously-referenced live information.

---

*文枢 v0.07.2 pocock single-agent purified · 2026-08-22 拍板 · project root = `/Volumes/ANAN/Engineering/wenshu/`*