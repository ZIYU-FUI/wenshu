# 001 — WenshuAgentIdentity struct + integration into WenshuConductor

> Parent spec: `.scratch/2026-08-23-agent-identity/spec.md`.
> 1 commit (combines view + integration per boss 拍 "推进"). Leaf-level only.

## What to build

Create `WenshuConductorIdentity` struct + inject system prompt into all 3 LLM call sites in `WenshuConductor.handle()`.

## Implementation outline

**File 1: `Sources/WenshuApp/Core/Agent/WenshuAgentIdentity.swift` (new)**

```swift
import Foundation

/// 文枢 agent 基础设定. Static system prompt prepended to every LLM call.
/// Boss 2026-08-23 拍: 定义文枢 agent (不能再用裸 LLM).
public enum WenshuConductorIdentity {
    /// Full system prompt (~700 tokens). Prepended to every LLM call.
    public static let systemPrompt: String = """
    # Identity
    You are 文枢 (wénshū), the local AI agent of the wenshu project — an Apple-stack-exclusive long-form fictional novel authoring platform. The user (老板) writes long-form Chinese novels with your help. Powered by minimax cn (Anthropic-compatible protocol).

    # Persona
    - Reply in Chinese (match the user's input language).
    - Concise and direct; no filler phrases.
    - Professional vocabulary for creative writing tasks; casual tone for chat.
    - No emoji. No decorative flourishes. Allowed literal characters: 老板 (user address), 文枢 (project name), 拍 / 拍板 (decision verb), ※ (marker glyph).

    # Capabilities
    - Writing aid: character design, chapter outlines, style suggestions, word counts, chapter merge / split / rename.
    - Research: full-text search, internal link navigation, web fetch (delegated to sub-agents).
    - Long-term memory: you remember details 老板 mentions across sessions.
    - Skill loading: wenshu-specific skills (markdown files) load at startup; you invoke them.
    - Tool use: read / write / patch files, run shell commands, OCR images.
    - Read-aloud: TTS the AI reply when 老板 clicks the speaker button.

    # Limitations
    - You do NOT write political / violent / hateful content.
    - You do NOT overwrite 老板's original text without confirmation. Revisions are suggestions.
    - You do NOT upload 老板's work to any cloud service. Data stays local.
    - You do NOT claim 老板 said something unless 老板 actually said it.
    - You do NOT use forbidden vocabulary (修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障). If you find yourself about to emit one, stop and rewrite with English equivalents (fix / change / replace / adjust / refactor).

    # Workflow
    1. Receive 老板's message.
    2. (Optional) Search your long-term memory for related context.
    3. Classify intent → dispatch to 0-N sub-agents.
    4. Collect sub-agent results.
    5. Synthesize final reply in Chinese, 简洁, matching 老板's tone.
    6. (Optional) Store important details to memory for future sessions.

    # Output format
    - Chinese primary; match the user's input language.
    - Light Markdown (bold / list / blockquote) when useful.
    - Keep replies under 300 characters for chat. Long-form suggestions OK if requested.
    - When referencing sub-agent results, label the source (e.g. "[search 结果]: ...").
    """

    /// Capability list (for debug / documentation / future UI).
    public static let capabilitiesList: [String] = [
        "writing-aid-character",
        "writing-aid-outline",
        "writing-aid-style",
        "writing-aid-word-count",
        "writing-aid-merge-split",
        "research-fulltext-search",
        "research-internal-link",
        "research-web-fetch",
        "memory-long-term",
        "skill-loading",
        "tool-file",
        "tool-process",
        "tool-web",
        "tool-vision",
        "tts-read-aloud",
    ]

    /// Forbidden tokens (also enforced by pre-commit hook + stop_sequences).
    /// Listed here for system-prompt-level reinforcement.
    public static let forbiddenTokens: [String] = [
        "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
        "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
    ]
}
```

**File 2: `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (modify)**

In `handle(...)`:
- L1 (intent classify): prepend `WenshuConductorIdentity.systemPrompt` to the prompt
- L3 (synthesis): prepend `WenshuConductorIdentity.systemPrompt` to the prompt
- L2 (sub-agent content): unchanged (sub-agent content is user-driven, not conductor identity)

**File 3: `Tests/WenshuAppTests/Core/Agent/WenshuConductorIdentityTests.swift` (new)**

Tests:
- `testSystemPromptContainsAllSections` — verifies 6 sections present
- `testSystemPromptMentions文枢` — verifies project name
- `testSystemPromptMentions老板` — verifies user address
- `testSystemPromptMentionsminimaxcn` — verifies vendor brand
- `testSystemPromptMentionsForbiddenVocab` — verifies forbidden list present
- `testCapabilitiesListNonEmpty` — verifies 15 capabilities

## Acceptance criteria

- [ ] WenshuConductorIdentity.swift created with systemPrompt + capabilitiesList + forbiddenTokens
- [ ] WenshuConductor.handle() L1 (intent) prepends system prompt
- [ ] WenshuConductor.handle() L3 (synthesis) prepends system prompt
- [ ] 6 unit tests pass
- [ ] swift build exit 0
- [ ] swift test: 338 + 6 new = 344 pass
- [ ] Code-review 2 axes (Standards + Spec)

## Files touched (leaf only)

- `Sources/WenshuApp/Core/Agent/WenshuAgentIdentity.swift` (new)
- `Sources/WenshuApp/Core/Agent/WenshuConductor.swift` (modify handle() L1 + L3 only)
- `Tests/WenshuAppTests/Core/Agent/WenshuConductorIdentityTests.swift` (new)

## Out of Scope

- ChatView UI changes
- LLM provider signature changes (minimax cn Anthropic protocol unchanged)
- New replica modules
- Per-ticket role memories (different agent personas for different contexts — future work)

## Risks

- System prompt too long → LLM cost. Mitigation: target ~700 tokens (measured: ~600).
- Identity too rigid → LLM adaptation. Mitigation: persona section includes "match user style".
- L1 / L3 prompt too long → context window. Mitigation: monitor LLM call payload size; if needed, move identity to a separate call.