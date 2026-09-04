# 05: Preview mode = swift-markdown + InternalLinkParser + wikilink rendering

**What to build:** Replace editor placeholder with preview Text(AttributedString(markdown: rawBody)) (= use AGENTS.md §11.1 pinned swift-markdown 0.4.0). Pipe through InternalLinkParser (= Core/LinkGraph/InternalLinkParser.swift = 1:1 Obsidian wikilink syntax) to make [[wikilink]] clickable links (= navigation to referenced note). Verify markdown headers/bold/italic/lists/code render + wikilinks resolve.

**Blocked by:** 04

**Status:** ready-for-agent

## Acceptance criteria

- [ ] import Markdown (= swift-markdown library from AGENTS.md §11.1)
- [ ] Editor placeholder replaced by preview mode UI (= preview case in mode switch)
- [ ] Text(AttributedString(markdown: rawBody)) renders markdown (= headers, bold, italic, lists, code, links)
- [ ] InternalLinkParser used to parse [[wikilink]] to clickable NavigationLink/Button (= 1:1 Obsidian wikilink syntax)
- [ ] swift build exit 0 + manual verify with sample .md containing headers, bold, lists, [[wikilink]]
- [ ] git commit: feat(wenshu): v0.34 -- preview mode = swift-markdown + InternalLinkParser (= ticket 05 of 11)

## Iron rules applied (= check before commit)

- [ ] Rule 6: layout/spacing uses DesignTokens (= no magic numbers)
- [ ] Rule 7: Button + system buttonStyle (= no custom-drawn icons, Lucide only)
- [ ] Rule 8: stays inside WindowGroup scene tree (= no new NSWindow)
- [ ] Rule 11: state persistence via @AppStorage / @SceneStorage (= Rule 11 + Apple HIG standard)
- [ ] wenshu-apple-api-first: grep Apple HIG first, write ZERO custom code if built-in covers it
- [ ] AGENTS.md §11.1: use pinned deps (swift-markdown 0.4.0) — NO add new deps
- [ ] AGENTS.md hard rule: English-only commit body + new comments; "老板" sole address

## Double-axis review (= per Q37 streak rule)

- [ ] Standards axis = sub-agent reviews AGENTS.md hard rules + 11 iron rules + ComponentIndex consistency
- [ ] Spec axis = sub-agent reviews spec user stories + implementation decisions vs actual code
