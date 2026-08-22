# 01 — Chat bottom-bar model + context (Hermes appChrome pattern)

**Blocked by:** None (reuses ticket 04 MiniMaxModelFetcher).

**Status:** ready-for-agent

## Fix approach (3 steps)

1. ChatViewModel add `currentModel: String` (= `@AppStorage("wenshu.llm.model")`), `contextUsed: Int` (`messages.count * 500`), `contextMax: Int = 20`
2. ChatView add HStack below the input box: left Button Menu (switch model), right progress + Text("\(X) / 20")
3. compact mode (width < 600): show only token count, no progress bar

## Acceptance

- [ ] ChatViewModel currentModel/context fields
- [ ] ChatView bottom-bar HStack
- [ ] Left model Menu switches model (reuses ticket 04 fetch)
- [ ] Right context "X / 20" + progress bar
- [ ] compact mode (width < 600)
- [ ] swift build / test exit 0
- [ ] 老板 macOS real verification

## Do not touch (Q20)

- v0.21 ticket 04 (reuse)
- Settings (do not touch)
