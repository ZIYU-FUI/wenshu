# 06 — Chat bottom-bar model + context usage (Hermes appChrome pattern)

> Date: 2026-08-22
> 老板 2026-08-22 拍: "Replace the two placeholder text functions in the chat zone bottom bar — left side shows the currently used model, clickable to switch; right side shows context usage. Reference hermes."

## Business language (老板-facing)

Chat zone bottom bar (below the input box), 2 elements:
- Left: current model label (e.g. "MiniMax-M3"), click → switch model (use the same provider Picker as Settings → Providers + Models tabs, or a popup menu)
- Right: context usage (e.g. "12 / 20" or progress bar)

## Hermes ground truth (ui-tui/src/components/appChrome.tsx)

- `modelText = modelLabel(model, reasoningEffort, fast)` — left segment, clickable
- `ctxLabel = fmtK(usage.context_used) + '/' + fmtK(usage.context_max)` — right segment
- `pct = usage.context_percent` — progress bar fill
- compact mode = narrow terminal → collapsed to "12k tok" bare token count

## Fix approach (5 principles 1 + 4 satisfaction, Hermes pattern)

1. ChatViewModel add `currentModel: String` (= `@AppStorage("wenshu.llm.model")` truth, do not touch existing model Picker)
2. ChatViewModel add `contextUsed: Int` (estimate = `messages.count * ~500 tokens`), `contextMax: Int` (= 20, ticket 05 sliding window threshold)
3. ChatView add an HStack below the input box:
   - Left: Button("currentModel") → Menu listing the current provider's models (fetched from the same provider as settings)
   - Right: Text("\(contextUsed) / \(contextMax)") + progress bar (.progressViewStyle(.linear), green → red ratio)
4. compact mode (window < 600 PT): show only the token count, no progress bar (Hermes truth)
5. 1 ticket 1 commit + dual-axis review

## Acceptance

- [ ] ChatViewModel adds currentModel + contextUsed/Max
- [ ] ChatView bottom-bar HStack (left model, right context)
- [ ] Click left model → Menu switches model (use Settings' same fetch, fallback curated)
- [ ] Right context shows "X / 20" + progress bar
- [ ] Window < 600 PT compact mode = only token count
- [ ] swift build exit 0
- [ ] swift test exit 0
- [ ] 老板 macOS real verification: chat bottom bar shows current model + context usage, click model to switch

## Do not touch (Q20)

- v0.21 ticket 04 MiniMaxModelFetcher (later refactor)
- v0.21 ticket 05 sliding window (do not touch)
- ticket 01 Provider enum (do not touch)
- App.swift Settings (do not touch)

## Apple HIG ground truth references

- https://developer.apple.com/documentation/swiftui/menu (Popup menu truth)
- https://developer.apple.com/documentation/swiftui/progressview (progress bar truth)
- ui-tui/src/components/appChrome.tsx (Hermes truth)

## Related

- Depends on: ticket 04 (MiniMaxModelFetcher) — already committed, reuse loadModelIds
- Depended on by: none
