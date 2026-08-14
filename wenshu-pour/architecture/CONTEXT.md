# CONTEXT.md · Wenshu (v0.00.0 bootstrap)

> Wenshu project core definition + design decision paper trail (`/grill-with-docs` style)
> Bootstrap on 2026-08-14 16:30 (= owner + pocock `/grill-me` 11-round Q&A)
> Source of truth: @/Volumes/ANAN/Engineering/wenshu/CLAUDE.md + @/Volumes/ANAN/Engineering/wenshu/AGENTS.md
> Related: ./DESIGN-V0-fix-*.md (= 5-zone layout grammar detail)

## 0. Project baseline (owner 2026-08-06 decision, 2026-08-14 16:30 bootstrap reconfirmed)

- **Wenshu = AI-driven novel-writing tool, LLM as base capability** (= owner grill Q1)
- **Architecture = Swift/SwiftUI single-process + markdown + YAML frontmatter + iCloud Drive cross-device sync** (= owner grill Q6, no Wenshu self-account)
- **v1 LLM provider = MiniMax M-series** (Anthropic-compatible, CLAUDE.md §9)
- **5-zone layout grammar** (= FCP-style + Apple-feel, AGENTS §8)

## 1. Owner's original vision (= 2026-08-14 grill-me Q8, owner verbatim)

> **Originally it was a combination of Hermes + Obsidian + Scrivener, Hermes's agent capability, Obsidian's knowledge-base capability, Scrivener's novel-editing capability**

**Owner 2026-08-14 17:00 correction = cherry-pick each tool's strongest capability, NOT compatibility** (= a brand-new software, don't clone Obsidian/Scrivener UI, clone capabilities, design Apple-feel UI yourself):

| Tool | Strongest capability | How Wenshu uses it |
|------|---------------------|---------------------|
| **Hermes** | agent orchestration (= multi-agent collaboration, implicit background) | **Wenshu assistant + implicit editorial agents** |
| **Obsidian** | markdown + backlinks + YAML frontmatter + LLM-friendly | **Pure markdown + YAML persistence** (persistence layer uses markdown, UI designed in-house) |
| **Scrivener** | long-form structure (= binder + corkboard + read-write editor) | **5-zone layout + binder + multi-novel + read-write editor** (topCenter = Scrivener/Obsidian-like editor) |

**Hard constraints (= brand-new software ≠ compatible)**:
- Don't clone Obsidian UI
- Don't clone Scrivener UI
- **Only Apple-feel UI** (= Apple HIG + SF Symbols + Apple-provided components HSplitView/VSplitView/NSToolbar/Material)

## 2. 11 core decisions (= 2026-08-14 grill-me owner-confirmed)

| Q# | Decision | Notes |
|----|----------|-------|
| Q1 | **Wenshu = AI-driven novel-writing tool** (= owner 2026-08-14 17:00 correction) | Core loop = create project → chat → Wenshu assistant → implicit editorial → auto research + update archives |
| Q2 | **Editorial = backend agents (research / archive / consistency / style), extensible but only by us, not by user**, extensions map to new features | Wenshu assistant routes by keyword, not visible in chat UI |
| Q3 | **Wenshu assistant = system default agent, UI does not show, code-layer thing** | UI does not specifically display "an assistant named Wenshu" (= user doesn't perceive Wenshu assistant's existence, only chat progressing); user can't see editorial agent switching |
| Q4 | 5-zone layout kept (project-management zone lets user switch books) | FCP-style 5 zones, but **meaning rewritten** |
| Q5 | Click book on binder → 4 zones all switch | One book at a time, synchronized switch |
| Q6 | Use iCloud, single .ws vs multi doesn't matter, FCP "one big library" | iCloud auto-sync, owner **doesn't care single vs multi .ws**, FCP-style one big library |
| Q7 | Pure markdown + YAML frontmatter (no CoreData) | LLM reads markdown most directly (= training data all markdown), YAML gives structured query |
| Q8 | Hermes + Obsidian + Scrivener triangle | Owner verbatim |
| Q9 | AI-backstop = 6-step auto loop (keyword / route / pull context / write archive / reply owner / adopt) | Revision candidates don't directly overwrite, owner one-click accept |
| Q10 | **topCenter reading = Scrivener/Obsidian-like editor, read-write unified** (= owner 2026-08-14 17:00 correction) | **AI output displayed in reading zone, owner directly edits to save = formal library**, reading zone is editor, not read-only display |
| Q11 | Temporary/formal grading + smart context picker (YAML frontmatter index, keyword loads formal library) | **Each document can be long, can't make LLM load all documents, context can't handle it** (owner verbatim) |

## 3. 5-zone layout new meaning (= owner grill Q9+Q10, different from before!)

| Zone | Previous understanding (wrong) | Current meaning (owner-decided) |
|------|-------------------------------|-------------------------------|
| **topLeft Project** | Project / Chapter / Setting / Material / Kanban (5 tabs) | **Binder + multi-novel switch** (= Scrivener concept) |
| **topCenter Reading** | Write novel main text (like Pages) | **Scrivener/Obsidian-like editor, read-write unified** (= AI output displayed in reading zone, owner directly edits to save = formal library, owner 17:00 correction) |
| **topRight Inspector** | Foreshadow / Revision | **Consistency check / Foreshadow / Setting** (kept) |
| **bottomLeft Chat** | Chat | **Main interaction zone** (= chat with Wenshu assistant) |
| **bottomRight Status** | TODO + Status change | **AI background TODO + research progress + kanban** (= doesn't disturb main chat) |

**Key (owner 17:00 correction)**: topCenter reading = **Scrivener/Obsidian-like editor, read-write unified**, **AI output directly displayed here + edit-save** (= writing main text also here, consistent with Scrivener/Obsidian = one unified markdown editor, AI drafts and formal docs both here).

## 4. Project core workflow (= owner grill Q1+Q11)

1. **Create project** = basic settings (project name / verbosity level 1-9 / style reference / book idea / tags)
2. **Enter chat** (= like Hermes)
3. **Wenshu assistant implicitly dispatches editorial** (= backend agents)
4. **Keyword recognition** (= protagonist / police / era) → **route** to corresponding agent
5. **Agent auto-pulls relevant context from existing markdown** (= smart context picker by YAML frontmatter)
6. **Agent writes new markdown / updates archive** (= temporary library)
7. **Chat reply owner summary** + revision candidates
8. **AI output displayed in topCenter reading zone (= Scrivener editor)**, owner **directly edits** to modify
9. **Owner clicks save → falls into formal library** (= temp library → formal library, one step, save in editor)
10. **Formal library markdown auto-loaded on-demand into LLM context** (= smart context picker)

## 5. Tech stack (= CLAUDE.md §2 + owner Q7 corrected)

- **Architecture**: Swift/SwiftUI single-process + actor-serialized CoreData + MarkdownKit render markdown + iCloud Drive sync
- **Persistence**: **Pure markdown + YAML frontmatter** (no CoreData schema, owner-decided)
- **LLM provider**: MiniMax M-series (Anthropic-compatible, minimax official recommended)
- **Streaming SSE**: byte-level accumulation, event sequence message_start → content_block_start → ping → content_block_delta → content_block_stop → message_delta → message_stop, no [DONE]
- **Apple HIG**: Apple-feel, SF Symbols 6 + Apple-provided components first (= HSplitView / VSplitView / NSToolbar / Color.accentColor / Material)
- **iCloud**: Wenshu internally **does NOT depend on cloud account**, but **uses iCloud Drive** to auto-sync .md files (= owner-decided go iCloud)
- **Platform**: macOS (Apple ecosystem exclusive, v1 only macOS, iPad/iPhone later)
- **LLM key**: macOS Keychain
- **.md file location**: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/wenshu/` (= same dir as owner's existing 十二地仙)

## 6. v0.08.0 bootstrap strategy (= owner 2026-08-14 16:30 option C, then D correction)

Owner verbatim:
> "I want C, FCP is 5 zones 7 columns. I actually want to copy FCP's framework, make an APPLE-feel software. The previous 6-role collaboration code quality was too poor. You've been tuning for two days, the code volume isn't much, starting over isn't a big loss."

**Option D (pocock self-decision) = preserve base infrastructure, rewrite 5-zone UI layer**:

Owner 2026-08-14 17:00 additional constraints:
- **UI designed from scratch** (= Apple-feel, don't clone Obsidian UI / don't clone Scrivener UI)
- **Editorial agents extensible** (= we develop, user can't extend themselves, extension agent maps to new feature)
- **topCenter is unified markdown editor** (= read-write unified, AI drafts and formal docs both here)

## 7. v0.00.0 bootstrap todo (= incremental push)

- ✅ **Step 1**: revert all 14 commits (= back to base v0.05.0)
- ✅ **Step 2**: drop CONTEXT.md (= this file)
- ✅ **Step 3**: rewrite Package.swift (= single WenshuApp target, minimal, 1077 bytes)
- ✅ **Step 3.5**: write Sources/WenshuApp/App.swift (= minimal SwiftUI app, 1120 bytes, English comments)
- ⏳ **Step 4**: `/code-review` (= Standards + Spec two-axis self-review)
- ⏳ **Step 5**: commit (= v0.00.0 bootstrap)
- ⏳ **Step 6**: `/to-tickets` (= 5-zone layout tickets)
- ⏳ **Step 7**: `/implement` per ticket (= /tdd red-green loop)

## 8. Owner's core pain point (= owner Q11 grill = Wenshu technical core)

> "Each document can be long, can't make LLM load all documents, context can't handle it."

= **Wenshu must do "on-demand load" (= smart context picker)**, not LLM read everything, Wenshu **selects relevant markdown by keyword** to feed LLM. **This is Wenshu's core technology** (= fundamental difference from other AI writing tools).

---

*Wenshu v0.00.0 bootstrap CONTEXT · 2026-08-14 16:30 owner + pocock grill-me confirmed · 17:00 corrections applied*