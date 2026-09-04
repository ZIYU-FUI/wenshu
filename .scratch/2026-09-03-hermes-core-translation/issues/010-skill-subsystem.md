# 010: Port skill subsystem (wenshu-side, hermes-style protocol)

**What to build:** Port hermes skill subsystem (`agent/skill_utils.py` ~700 LOC + `skill_preprocessing.py` ~400 LOC + `skill_commands.py` ~500 LOC + `skill_bundles.py` ~300 LOC = ~1,900 LOC). After this ticket, wenshu can load, dispatch, and bundle hermes-style SKILL.md files. Wenshu's skill storage follows wenshu-native layout (per §11 baseline; NOT hermes `~/.hermes/skills/`); the SKILL.md frontmatter protocol is the same as hermes (boss拍 2026-09-03 = "复刻 = same skill format as hermes").

**Blocked by:** 001 (LLMConnector protocol + agent loop must exist so skill commands can run inside the loop)

**Status:** blocked

## Source files surveyed

| Path | LOC | What ports |
|---|---|---|
| `agent/skill_utils.py` | ~700 | Full port = skill load + dispatch |
| `agent/skill_preprocessing.py` | ~400 | Full port = frontmatter parse |
| `agent/skill_commands.py` | ~500 | Full port = slash-command surface |
| `agent/skill_bundles.py` | ~300 | Full port = bundle discovery |

## UI-affordance mapping (per spec §6.4)

This ticket's translated products and their UI landing:

| Translated product | UI landing | Tier | Rationale |
|---|---|---|---|
| Skill subsystem (engine) | (underwater) | 🟦 | skill load + dispatch runs inside ConversationLoop |
| Slash-command (`/<skill>`) | ChatView input intercept | 🟥 | user types `/` in chat, gets command palette |
| Skill management | Settings弹窗 new "Skills" view | 🟥 | user installs / uninstalls skills |

**3-question check** (per spec §6.4):

1. **Who triggers it?** User types `/` in `ChatView` input → slash-command palette appears (= 🟥). User selects `/<skill>` → skill runs. User opens Settings → Skills to manage installed skills (= 🟥).
2. **What signal does the user see?** In ChatView, typing `/` shows a floating palette with skill names + descriptions. Selecting one runs the skill; result appears inline in chat. In Settings → Skills, user sees installed skills list + install button + per-skill enable/disable toggle.
3. **UI affordances added**: ChatView `/` input interceptor + command palette floating panel (= 🟥); Settings弹窗 new "Skills" view (= 🟥).

## Acceptance criteria

- [ ] `Sources/WenshuApp/Core/Agent/Skill/SkillUtils.swift` ports `skill_utils.py` 1:1 with `// SWIFT-PORT:` markers
- [ ] `Sources/WenshuApp/Core/Agent/Skill/SkillPreprocessing.swift` ports `skill_preprocessing.py` 1:1
- [ ] `Sources/WenshuApp/Core/Agent/Skill/SkillCommands.swift` ports `skill_commands.py` 1:1
- [ ] `Sources/WenshuApp/Core/Agent/Skill/SkillBundles.swift` ports `skill_bundles.py` 1:1
- [ ] SKILL.md frontmatter parser: parses `name` + `description` + `version` (= hermes-compatible)
- [ ] Skill discovery: scans wenshu's skill folder (= `Sources/WenshuApp/Core/Agent/Skill/` for built-in; user-installed = wenshu §11 baseline location TBD)
- [ ] Skill slash-commands: user types `/<command>` in chat, wenshu runs the skill
- [ ] `swift build` exit 0; `swift test` exit 0
- [ ] Z contract test: golden files for skill load + dispatch + slash-command
- [ ] Manual e2e: install a test SKILL.md, type `/test-skill` in chat, skill runs

## Iron rules applied

- [ ] Direct port with `// SWIFT-PORT:` markers
- [ ] SKILL.md format = hermes-compatible (boss拍 2026-09-03)
- [ ] wenshu skill storage location: NOT `~/.hermes/skills/`. Wenshu uses its own per-OS location TBD (= wenshu §11 baseline location, parallel to existing `~/.wenshu/skills/` if needed)

## Estimated LOC

~2,000 Swift LOC.

## Commit format

`feat(wenshu): v0.35 -- skill subsystem (= ticket 010 of 11)`