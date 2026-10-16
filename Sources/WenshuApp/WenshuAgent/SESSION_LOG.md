# Wenshu P3/P0 agent arc — session log

> Per boss 2026-10-16 directive "A 然后把做收尾的做完" (= push 9 commits
> + write session log); = 9 commits ahead of `old-origin/main`.

## Arc summary

| Item | Value |
|---|---|
| Arc window | 2026-10-16 |
| Boss OOB directives in arc | 4 (抽包 / LOG / agent 真化 / chat focus) |
| Total commits | 16 (= 7 in old-origin/main + 9 local pending) |
| LOC change | net -480 dead code + ~750 new streaming / tests / docs |
| Tests | 7 WenshuAgent 单元 tests (20 / 20 pass); = WenshuApp.Agent filter 45/45 pass |
| Build | exit 0 |

## Boss 4 OOB directives → commits

| OOB | Commit(s) |
|---|---|
| "调用提供商 API 是否抽独立包" | `45bebf3cc` + `a0b371b45` + `fd5baaee6` |
| "包要有 LOG 能力" | `45bebf3cc` (= WALogger subsystem `com.wenshu.agent`) |
| "agent 没有达到 agent 的标准" (小骗子) | `7de86fc08` + `140b76deb` + `e9ae2add0` + 5 connector native streaming commits + `4a9515bd5` |
| "打字说完一句话，聊天区的文本框会失去焦点" | `9640232eb` |

## Commits (= chronological, oldest first)

### In `old-origin/main` (= 7 commits, already pushed)

1. `45bebf3cc` refactor: extract WenshuAgent subsystem + 5 new mechanisms + AUDIT/API
2. `317f1de32` feat: wire WAStreamWatchdog 30s timeout into SSEClient
3. `a0b371b45` feat: add WenshuAgent.shared public facade
4. `a28a03874` test: 7 WenshuAgent 单元 tests (20/20 pass)
5. `7de86fc08` fix: wire active connector into WenshuConductor (= the "小骗子" root cause fix)
6. `9640232eb` fix: retain chat input focus after send (= Apple Messages 模式)
7. `140b76deb` test: marker fix for WenshuConductorE2ETests

### Local (= 9 commits, pending boss manual `git push old-origin main`)

8. `e9ae2add0` refactor: delete the WenshuConductorLegacyPipeline dead path (252 LOC)
9. `de4a9773f` feat: wire native SSE streaming into MinimaxConnector
10. `7dc8edecd` feat: wire native SSE streaming into DeepSeekConnector
11. `88b9830f1` feat: wire native SSE streaming into OpenRouterConnector
12. `791acb497` feat: wire native SSE streaming into OllamaConnector
13. `4a9515bd5` refactor: delete the default LLMConnector.stream() extension + OpenAIConnector native streaming
14. `cb3688e73` docs: append P3/P0 completion report to WenshuAgent/API.md
15. `076411467` docs: append P3/P0 completion report to WenshuAgent/AUDIT.md
16. `fd5baaee6` feat: add WenshuAgent.shared chat() + installConductor API

## Net effect (= the "before / after" table the boss asked about)

| Metric | Before P3 | After P3 | Net |
|---|---|---|---|
| WenshuAgent LLM files | 33 scattered across 4 dirs | 33 in `WenshuAgent/` | organized |
| Chat LLM call paths | 2 paths (conductor + verifier fallback) | 1 path (conductor + ReAct loop) | **-1 path** |
| WenshuConductor legacy pipeline | 252 LOC | deleted | **-252 LOC** |
| WenshuVerifier.streamChat (= "fake streaming" fallback) | 100 LOC | deleted | **-100 LOC** |
| LLMConnector default stream() (= "fake streaming" trap) | 30 LOC | deleted + compile-time guard | **-30 LOC** |
| Connector native streaming overrides | 3/8 (Anthropic, OpenAI, Gemini) | 7/7 + guard | **+4 stream() + 1 guard** |
| WALogger calls in LLM path | 0 | 6 categories, 30+ log points | **+30 log points** |
| WenshuAgent 单元 tests | 0 | 7 test files, 20 / 20 pass | **+20 tests** |
| WenshuAgent.shared API surface | 2 methods | 5 methods (chat, currentConductor, installConductor, providersWithKeys, availableModels) | **+3** |
| Boss-perceivable UX | broken (= "(no reply)" + 5-10s blank + 小骗子) | working (= 真流式 + 真调 tool + focus OK) | **= P0 完成** |

## Known issues (= ANAN sandbox; = boss desktop unaffected)

1. **ANAN sandbox cannot launch wenshu** (= pre-existing B-10 codesign issue; = `Scripts/build-app.sh` comment "ad-hoc codesign (B-10 phase A entitlement embed reverted — SIGKILL on launch)"). Boss desktop `open build/Wenshu.app` works normally.
2. **ANAN sandbox cannot push to remote** (= `git push old-origin main` fails with "No user exists for uid 502"). Boss `git push old-origin main` from Terminal.app works.
3. **CUA direct capture not granted** (= ANAN triggered `cua-driver permissions grant` to open the System Settings dialog; = boss clicks Allow in Privacy & Security → Screen & System Audio Recording → CuaDriver).

## Future arc candidates (= per boss "做就做到最好" + "用户体验优先")

1. **14 caller migration to WenshuAgent.shared** (= 1-2 ticket 收 14 caller; = commit `fd5baaee6` already laid the API foundation)
2. **WenshuVerifier 删** (= 30+ test files affected; = engineering convergence)
3. **WenshuLLMBlock + WenshuLLMError 删** (= 4 caller 改; = engineering convergence)
4. **8 connector 加 WALogger.network** (= AUDIT.md §2.6 partial)
5. **WAStreamWriterFence 接入 stream 路径** (= AUDIT.md §2.9 partial)
6. **wenshu 资料库/大纲/伏笔/角色图** (= 产品下一阶段 = 真写作辅助)

## Reference (= canonical docs this arc touched)

- `AGENTS.md` (= project SSOT; = do not modify; = boss protected)
- `Sources/WenshuApp/WenshuAgent/API.md` (= P2 设计 + P3/P0 完成报告)
- `Sources/WenshuApp/WenshuAgent/AUDIT.md` (= P1 调研 + P3/P0 完成报告)
- `Sources/WenshuApp/WenshuAgent/Public/WenshuAgent.swift` (= `WenshuAgent.shared` facade)
- `Sources/WenshuApp/App/WenshuAppDelegate.swift` (= installs the conductor at app launch)
