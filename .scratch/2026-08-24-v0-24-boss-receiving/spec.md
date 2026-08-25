# Boss 2026-08-25 OOB context window spec

Boss拍: 'minimax m3 不是 1mb 的上下文吗, 你现在设定的才是 131k'.
Boss拍: '没有接口获取的到吗' (boss checking if API exists to query context length).

## 现状 (pre-fix)
- `Sources/WenshuApp/Views/Chat/ChatView.swift:79`: `contextMax: Int = 131072`
- Boss image shows: '0 /131.1k' (= 131,100 tokens)
- 131,072 = 128 KB = **MiniMax-M2 series value**, not M3
- Per boss 拍: 不对 = MiniMax M3 实际 context window 更大

## 真值 (per official + hermes upstream research)
1. **Official MiniMax model page** (https://www.minimax.io/models/text/m3):
   '1M Context' / '1,000,000 token context window with a guaranteed minimum of 512K tokens'.
2. **Anthropic-compatible API docs** (https://platform.minimax.io/docs/api-reference/text-anthropic-api):
   M3 = 1_000_000 tokens (max output 512_000).
3. **Empirical test** (hermes-agent issue #37289, public anthropic-compatible endpoint):
   input cap at ~512K tokens. API rejects >512K with 'invalid params, context
   window exceeds limit'.
4. **Live API `/v1/models`**: does NOT return `context_length` field. **No API to query dynamically** (boss 8/25 OOB confirmed).
5. **HERMES-agent strategy** (agent/model_metadata.py:1456-1487):
   hybrid = `models.dev` registry first → fallback hardcoded catalog.
   But `models.dev` reports 512K for M3 (= vendor publishes there) → runtime
   short-circuits at 512K, hardcoded 1M never reached.

## Spec 决定
- **Use official value** = `1_000_000` tokens (= source of truth per Apple HIG /
  anthropic API contract principle). UI shows '1.0M'.
- **Vendor reality** (~512K empirical cap) = separate vendor API issue.
  Boss should complain to MiniMax if >512K input rejected (= not wenshu fix).
- **No dynamic API query** = live MiniMax cn `/v1/models` doesn't expose
  context_length. Future enhancement: parse `models.dev` registry (hermes
  strategy).

## Tickets
- ticket 015.006 (chatview context window fix): `contextMax 131072 → 1_000_000`.
- ticket 015.007 (contextMax display format): 'k → M' conversion (e.g. 131.1k →
  1.0M). UI label display.
- ticket 015.008 (future: models.dev lookup): optional enhancement to match
  hermes strategy. Defer until boss拍 (not blocking v0.24).

## Done criterion
- swift build: clean.
- App: bottom-right context display shows '0 /1.0M' (= 1M tokens cap).
- Tests: 574/80 unit pass + 10 e2e flakes pre-existing (no new).
- Code-review axes (Standards + Spec): both PASS.
- Domain-modeling: CONTEXT.md add entry for 'MiniMax-M3 context window = 1M tokens'.
- Confirm: boss 拍 '通过验收'.

---

# Boss 2026-08-25 second OOB spec (post contextMax fix)

Boss follow-up拍:
1. '你的会话记录是存在 .ws 文件里吗' (= chat.sqlite 应 在 user-chosen 仓库 anbaiqiang.ws/ 内, 不是 legacy ~/Library/Application Support/wenshu/).
2. '重启 APP 都是新开一个会话吗, 我需要让用户视觉上看到, 一直只有一个会话. 但真实过程中的上下文压缩, 等用户无感知' (= single session visible + auto context compression invisible to user).
3. '查一下 hermes 也可以一直在一个会话里持续聊天. 看看是怎么实现的'.
4. '用户的聊天数据, 也应该是库文件的一部分, 这样客户在打包库文件到另一台电脑后, 就可以直接接续. 上下文内容是否也可以持久化. 我看现在 hermes. 我重新打开 APP, 上下文内容也还在'.

## 现状 (post contextMax fix)
- chat.sqlite location: `~/Library/Application Support/wenshu/chat.sqlite` (= legacy, not in anbaiqiang.ws/).
- kanban.db location: `~/Library/Application Support/wenshu/kanban.db` (= same legacy issue).
- todo.db location: `~/Library/Application Support/wenshu/todo.db` (= same).
- anbaiqiang.ws/ contents: `Icon`, `Info.plist` only (= empty warehouse, no chat/kanban/todo data).
- vm.contextUsed accumulates unbounded (= no compression).
- User perception: 每重启 = empty session visible (= 看起来 'new session') — 实际上 history is loaded via .task 但 显示 在 chat UI = 先 show placeholder, 之后 load history fill back.

## Hermes pattern (research)
1. **Single session persistence**:
   - Hermes Desktop (Electron) = LevelDB at `~/Library/Application Support/Hermes/Local Storage/leveldb/` (auto-load on launch).
   - Hermes CLI/gateway = SQLite via SessionStore (`session_state.db` + SessionEntry load).
   - ConversationState dataclass: 'survives turns, not boundaries' (= state persists across all turns of one conversation).
   - On app launch, session loads automatically (= user sees continuous history).
2. **Auto context compression** (from `agent/context_compressor.py`):
   - Self-contained class with OpenAI client for summarization.
   - Auto-summarize middle turns when context > limit (using auxiliary cheap model).
   - Protect head + tail context (= recent N turns + system prompt + recent user input).
   - Token-budget tail protection (dynamic, not fixed message count).
   - Tool output pruning before LLM summarization (cheap pre-pass).
   - Iterative summary updates (= preserves info across multiple compactions).
   - User sees only summary card 'Compressed: 30 → 12 messages' (= invisible compression).
3. **Portable library** (= user-chosen location):
   - Hermes doesn't have user-chosen warehouse (= data in app sandbox).
   - wenshu needs different approach: data INSIDE .ws file (= portable).

## Spec真值
- Single user-visible session: ✓ already done (= sessionId='default' + .task load history).
- Chat data in .ws: ❌ need ticket 015.005 (= move chat.sqlite to anbaiqiang.ws/chat.sqlite).
- kanban/todo in .ws: ❌ need ticket 015.011 (= same pattern).
- Auto context compression: ❌ need ticket 015.010.

## Tickets
- ticket 015.005: Move chat.sqlite from `~/Library/Application Support/wenshu/chat.sqlite` to `<wenshu.libraryPath>/chat.sqlite`.
  - UserDefaults 'wenshu.libraryPath' = boss's selected .ws path (= anbaiqiang.ws).
  - ChatSessionStore.init(path: ??) accepts custom path (= use UserDefaults value).
  - On warehouse change (= user picks new .ws folder), copy existing chat.sqlite to new location OR start fresh (= UX choice).
- ticket 015.010: Auto context compression when contextUsed > 80% of contextMax.
  - Per hermes pattern: summary middle turns using auxiliary model (= cheap, fast).
  - Insert summary card into messages array (= user sees 'Earlier conversation summarized' marker).
  - Context budget tail protection (= keep recent N turns + system prompt + recent user input).
- ticket 015.011: Move kanban.db + todo.db to anbaiqiang.ws/ (= same pattern as 015.005).

## Done criterion
- App restart shows same chat history (= ticket 015.005 wiring).
- Context auto-compresses when >80% (= ticket 015.010).
- All 3 db files (chat/kanban/todo) inside anbaiqiang.ws/ (= tickets 015.005+015.011).
- User perception: 一直只有一个会话 + 上下文自动管理 (= invisible to user).


---

# Boss 2026-08-25 third OOB spec (zone bottom toolbar)

Boss 拍: '六个区现在只有聊天区有底栏了. 其它五区的底栏不知道什么时候都丢了'.

Boss ask A (clarify): 恢复所有 5 zones 用 ZoneBottomToolbar, 每 zone 自己
的 status info (= projectSidebar = 书架数, editor = 字数, preview = 章节数
etc).

## 现状 (post v0.24)
- chat zone: 内嵌 ChatBottomToolbar (= model picker + context usage)
- dynamic zone: internal tab bar (看板 / 待办) — but NO outer bottom toolbar
- 其他 4 zones (projectSidebar, projectPreview, editor, specializedTools):
  只有 content, no bottom toolbar at all (= v0.24 boss拍 removed
  outer ZoneTopToolbar/ZoneBottomToolbar)

Code state:
- ZoneBottomToolbar struct exists at App.swift:1184 (defined, never
  instantiated = dead code).
- ZoneModule body comment at App.swift:1242: 'v0.24 boss验收fix:
  6-zone unified pattern — no outer ZoneTopToolbar / ZoneBottomToolbar'
- Per boss 8/25 OOB: re-add ZoneBottomToolbar for 5 non-chat zones.

## Per-zone status info design (= boss 拍 'A')
- projectSidebar: 书架数 (= count of WenshuLibrary shelves)
- projectPreview: 章节数 (= count of chapters in selected book) + 当前章节号
- editor: 字数 (= wordCount of current chapter) + 进度 %
- specializedTools: 工具状态 (= placeholder "工具就绪")
- dynamic zone: 子 agent 进度 (= already in Kanban view) — keep inner tab
  only
- chat zone: model picker + context usage (existing, no change)

## Fix
- Modify ZoneModule.body to include ZoneBottomToolbar for all slots
  EXCEPT .aiChat (= chat keeps its own internal ChatBottomToolbar).
- Pass per-slot status content via new ViewModifier or per-slot computed
  property.

## Tickets
- ticket 015.012 (this): Re-add ZoneBottomToolbar for all 6 zones with
  per-zone status content (= A plan).
- ticket 015.013 (next): Per-zone status content (word count, chapter count,
  etc.) wired to actual data sources.

## Done criterion
- All 6 zones display ZoneBottomToolbar at bottom (visible per ZoneModule
  parent component, not inner).
- Chat zone retains its custom in-child ChatBottomToolbar (= no duplicate).
- Other 5 zones show per-zone status info (= word count, chapter count,
  shelf count, etc.).
- Status updates on app state changes (= reactive via @Observable /
  @AppStorage / @State).
