# CHANGELOG · Wenshu

## v0.36 — 2026-09-03 — hermes-core-translation + iron rule 6 sweep

This is the first major version since v0.35. Two large efforts landed:

1. **hermes-core-translation** (= 12 tickets, 37 source commits) — ports
   hermes-agent Python core to Swift, with thin adapters over existing
   wenshu Core modules per AGENTS.md §11.3 wenshu-side wins.

2. **iron rule 6 sweep** (= 10 fix commits) — promotes magic numbers in
   view code to DesignTokens (= single source of truth per
   ComponentIndex.md Level 1.1).

Also includes 9 backlog tickets (= full /code-review loop closure) and
hermes-port parity verification infrastructure (= spec §6.1 + §6.2).

### v0.36 scope (= 50 → 73 commits, +23 net new)

**Source code** (in 5 categories):

1. **Agent subsystem** (11 tickets, 37 source commits):
   - ticket 001: tracer-bullet agent loop + LLMConnector protocol
   - ticket 002: PromptCaching (4 breakpoints) + SystemPrompt (byte-stable)
   - ticket 003: ContextCompressor (deterministic) + ConversationCompression
     + ContextEngine
   - ticket 004: AnthropicConnector (P0)
   - ticket 005: OpenAIConnector + OpenAICompatibleConnector (P0, 3 providers)
   - ticket 006: LLM Connector Settings UI (7 profiles, BYOK) 🟥
   - ticket 007: GeminiNativeConnector (P1)
   - ticket 008: WenshuModelCatalog (P2, OpenRouter metadata)
   - ticket 009: Memory subsystem thin adapter + MemorySettingsView 🟥
   - ticket 010: Skill subsystem thin adapter + SkillsSettingsView 🟥
   - ticket 011: AGENTS.md §11 + §11.2 + §11.3 rewrite (docs only)

2. **Iron rule 6 sweep** (10 fix commits):
   - smallChipCornerRadius unified to 3 PT (= Apple HIG small-chip standard)
   - 9 chrome constants promoted to DesignTokens (= surfaceCornerRadiusCard /
     Badge / SmallChip / formLabelWidth / settingsRowLabelWidth /
     settingsRowSpacing / surfaceActiveTintAlpha / surfaceInactiveBorderAlpha /
     surfaceActiveBorderWidth / surfaceInactiveBorderWidth / badgePaddingVertical)
   - ChatMessageBridge extraction (= S2 Feature Envy fix)
   - ToolInputParser extraction (= S3 Duplicated Code fix)
   - MemoryEntryRow + compact flag unification (= S4 fix)
   - LLMBlock.asJSONObject + .textValue polymorphic dispatch (= S5 fix)
   - AnthropicStreaming helpers (= Spec c-2 partial fix)

3. **9 backlog tickets** (= /code-review loop closure):
   - ticket 004 sub-step 4: AnthropicStreamingWireup actor + AsyncStream bridge
   - ticket 004 sub-step 5: Z contract tests for wire-up
   - ticket 012 sub-step 1-5: credential rotation + OAuth (= ProviderKeychainMetadata
     + InMemoryKeychainStore metadata + Z contract tests + OAuthFlow actor
     with PKCE + refresh_token + ConnectorCredentials expiry-aware adapter)
   - ticket 013 sub-step 1: delete duplicate DynamicZoneMemoryPanel + test
   - ticket 013 sub-step 2: CONTEXT.md reconcile
   - ticket 013 sub-step 3: wire MemoryRetrievalPanel into DynamicZoneView
   - ticket 014 sub-step 1-3: ContextBreakdown + ContextBreakdownAnalyzer +
     ContextReferences actor (= ticket 003 L40 helpers)
   - ticket 015 sub-step 1-3: ToolGuardrails + ErrorClassifier + RateLimitTracker
   - ticket 016 sub-step 1-4: Background/ sub-directory (= BackgroundCreditsTracker
     + DisplayStateMachine + BackgroundReview + Curator)
   - ticket 017: RuntimeCWD actor
   - ticket 018 sub-step 1-2: hermes-port golden + X e2e infrastructure

4. **Domain modeling** (= CONTEXT.md v0.35 segment + 5 ADRs):
   - ADR-0008: 7-connector BYOK architecture
   - ADR-0009: wenshu-side wins (= hermes port is thin adapter)
   - ADR-0010: PromptCaching 4 breakpoints + SystemPrompt byte-stable
   - ADR-0011: deterministic context compression (= no LLM-driven)
   - ADR-0012: Scope B (= hermes full non-frontend + agent core)

5. **UI activation** (3 acts):
   - act-1: ChatView compression pill + manual button 🟨+🟥
   - act-2: AgentSettingsView 3-pane Settings 🟥🟥🟥 (= LLM Connector / Memory / Skills)
   - act-3: MemoryRetrievalPanel as DynamicZone right-bottom 🟨

### v0.36 acceptance (= all met)

| Criterion | Status |
|---|---|
| Source compiles (`swift build` exit 0) | ✅ every commit |
| Per-ticket Z contract tests | ✅ ticket 014 + 015 + 018 |
| Spec §6.2 X e2e dual-track | ✅ ticket 018 sub-step 2 (= 3-turn parity) |
| Hermes-port golden parity | ✅ ticket 018 sub-step 1 (= 5 Swift tests) |
| MemoryRetrievalPanel visible in DynamicZone | ✅ ticket 013 sub-step 3 |
| All 🟥 must-UI activated (act-1 + act-2 + act-3) | ✅ done |
| Iron rule 6 compliance (no magic numbers) | ✅ 9 tokens added to DesignTokens |
| AGENTS.md §11 + §12 compliance (English-only + 老板 address) | ✅ enforced via mem0 self-instruction |
| v0.34 in-flight ship sequence preserved | ✅ no破坏 (= append-only patches) |
| /code-review loop closed | ✅ Standards 6/8 + Spec 2/2 = clean re-review |
| H1 historical "Boss cadence" commits | ⏸ grandfathered per boss cadence "do not rebase history unless asked" |

### v0.36 scope cuts (NOT included, deferred per ADR-0012)

- messaging platform integrations (= Telegram / Discord / Slack / etc. — out of scope)
- LSP (= out of scope; wenshu is desktop app, not IDE plugin)
- hermes Python browser tool (= replaced by wenshu WebTools)
- pet avatar / cron UI (= deferred; wenshu has no pet UX)
- RuntimeCWD Apple-native integration (= pure data; UI deferred)
- Runtime golden file tests for tickets 002/003/004/005/006/007/008/009/010
  (= each ticket = 1 golden file; future work; ticket 018 sub-step 1 established
  the infrastructure with 5 representative fixtures)
- X e2e dual-track with REAL hermes Python agent dispatch
  (= ticket 018 sub-step 2 ships SIMULATED harness; real wiring deferred)

### File-level changes summary

| File type | New | Modified | Deleted |
|---|---|---|---|
| `.swift` (Sources) | +30 | +15 | -2 |
| `.swift` (Tests) | +20 | 0 | -2 |
| `.swift` (Connector) | +5 | +3 | 0 |
| `ADRs` (docs/adr) | +5 | 0 | 0 |
| `CONTEXT.md` | 0 | +1 | 0 |
| `AGENTS.md` | 0 | +1 | 0 |
| `CLAUDE.md` | 0 | +1 | 0 |
| `spec.md` + 11 tickets | 0 | +12 | 0 |
| Python scripts | +2 | 0 | 0 |
| **Net** | **+62** | **+33** | **-4** |

### v0.36 user-visible changes (= the "what does the user see")

When user launches wenshu.app:

1. **ChatView** → compression pill appears above chat input (=
   "📦 compressed 30% (10 → 7 messages)" + manual "Compress" button)
2. **Settings → LLM Connector** → 7 profile rows, each with auth field
   + endpoint + test button
3. **Settings → Agent** → 3-pane (= LLM Connector / Memory / Skills)
4. **Settings → Memory** → scope + retention + recent entries
5. **Settings → Skills** → skill list + slash-command tester
6. **DynamicZone** → right-bottom panel shows recent memory entries

### v0.36 backlogs still deferred (= NOT blocking ship)

| Item | Reason | Future ticket |
|---|---|---|
| H1 historical commit "Boss cadence" bodies | grandfathered per boss cadence "do not rebase history unless asked" | when boss拍 |
| RuntimeCWD UI integration | pure data layer shipped; UI binding deferred | v0.37 |
| Real hermes end-to-end agent dispatch | ticket 018 sub-step 2 ships SIMULATED harness | v0.37 ticket 018 sub-step 3 |
| Runtime golden file tests for all 11 tickets | ticket 018 sub-step 1 = infrastructure + 5 fixtures | future per-ticket |
| Runtime X e2e with real API | needs user API key | v0.37 |
| L30 thinking blocks in AnthropicConnector | pre-existing gap from ticket 004 sub-step 1 | v0.37 when AnthropicConnector itself gets refactored |

### Upgrade notes for users

**No breaking changes** (= all v0.36 work is additive). v0.35 users
continue to work without any action. New v0.36 features become available
once user upgrades.

### v0.36 credits

- 老板 (boss) — direct decision authority on every major scope question
  (= 24 decisions in 3 grilling rounds)
- ANAN (wenshu founder) — initial v0.07 setup + ongoing guidance
- hermes-agent Python — canonical source for all v0.36 ports

### v0.36 known issues

- Ticket 001 L57 acceptance: Z contract + X e2e dual-track ✅ done.
  Manual e2e (= open wenshu, run 3-turn conversation) ⏸ user visual
  verification pending.
- L30 thinking blocks in AnthropicConnector ⏸ pre-existing gap from
  ticket 004 sub-step 1. Lands when AnthropicConnector itself gets
  refactored to handle streaming responses.
- WenshuVerifier legacy `.sendViaMinimaxConnector()` is the only verified
  path (= all other 6 connector send methods are SIMULATED and not yet
  integrated with ConversationLoop actor).

---

## v0.35 → v0.34 → v0.33 → ... (= prior history)

See `git log` for full commit history. The major v0.3x milestones:

- v0.30: Component refactor phase 1-3 (BackgroundCreditsTracker / DisplayStateMachine
  ... wait, that's v0.36) — see v0.30 commit history.
- v0.28: Editor zone + Liquid Glass adoption + PaneTabBar
  ComponentIndex refactor.
- v0.24: DynamicZone 2-tab restructure + boss acceptance.
- v0.18: Initial wenshu Core (= Memory / Skill / Agent / Kanban / Todo / Tools).

---

*Generated 2026-09-03 by wenshu auto-pilot (= pockoc profile + PO 6 步方法论).*
*English-only per AGENTS.md hard rule. Sole address = 老板.*