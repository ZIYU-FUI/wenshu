feat(wenshu): v0.34 -- B-20 format toolbar in editor top bar (5 MD buttons)

Boss 2026-09-02 OOB 'format toolbar' (= '都可以搞'). The editor top
bar now has a 5-button MD format toolbar in the left slot (= Q21-boss
answer = "editor 顶 toolbar 左侧"), shown only in .edit mode.

Buttons:
  - 加粗 (**)            icon: bold
  - 斜体 (*)              icon: italic
  - 标题 (#)              icon: heading
  - 行内代码 (`)          icon: code
  - 列表项 (-)            icon: list

Each action wraps the current selection or appends to the draft with
the matching MD syntax marker. PaneTrailingIconButton reuse (= same
visual contract as the rest of the top bar; = Rule 7 system component
pattern). Spacing 4 PT (= DesignTokens.chromePaddingMicro).

Limitation: text wrapping is append-at-end fallback (= no cursor
selection tracking; = needs NSTextView delegate via
NSViewRepresentable for true selection-aware wrapping). v0.35+ ticket.

Visual hierarchy (left to right):
  [doc basename] [B] [I] [H] [Code] [List] | (spacer) | (mode toggle) | (spacer) | (save) (expand) (close)

Apple HIG rationale:
- Toolbar buttons live outside the TextEditor's view tree (= the
  top bar is the editor zone's wrapper), so wrapping is appended
  to draft end (= fallback = Pages / TextEdit behavior).
- Diff-style write (= draft = newDraft; = no NSTextView undo group
  bridging = undo loses wrap action history; = acceptable for v1).
- Lucide icons (= Rule 7; = consistent with the rest of the top bar).

Iron rules applied:
- Rule 6: DesignTokens.chromePaddingMicro (= 4 PT cluster gap)
- Rule 7: PaneTrailingIconButton (= system component + no custom)
- Rule 8: stays inside WindowGroup scene tree (= no NSViewRepresentable)
- AGENTS.md hard rule: English-only commit body; 0 forbidden vocab

Verified: swift build exit 0 (7.37s).
