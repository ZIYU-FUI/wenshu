# 004 Truth verification: swift run + screencapture -l + vision_analyze

> Q22 audit gate (老板 2026-08-19 拍板): any wenshu visual commit must run
> Dependency: 001-003

## Steps

```bash
# 1. pkill old
pkill -9 -f WenshuApp; sleep 1

# 2. build + run background
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -5
swift run WenshuApp &
APP_PID=$!; sleep 5

# 3. Quartz windowID
WIN_ID=$(swift /tmp/winlist.swift 2>&1 | grep -oE 'winID=[0-9]+' | head -1 | grep -oE '[0-9]+')

# 4. screencapture -l
screencapture -l $WIN_ID -o -x /tmp/wenshu-v0.15.png

# 5. vision_analyze
#   See: macOS titleBar single layer (not double layer) + 6 zones + 6 splitters + top bar 3 SF Symbol + bottom bar placeholder text + editor 4 PT inset
```

## Visual checklist (老板 2026-08-19 拍)

1. macOS titleBar single layer (not Canvas self-drawn + macOS chrome double layer)
2. Upper band 4 zones = project sidebar + project preview + editor + dedicated tools (left to right)
3. Lower band 2 zones = AI chat + AI dynamic
4. Top bar each zone 3 SF Symbol (`book.closed` / `magnifyingglass` / `slider.horizontal.3`) replace original blue rectangle
5. Bottom bar each zone placeholder text (`.body`) + placeholder SF Symbol
6. Editor 4 PT inset double layer
7. 6 splitters static 2 PT black capsule
8. Hover splitter = 4 PT accent blue glow + cursor switch
9. Drag splitter = zone width follows hand without jitter

## Failure handling

- Any visual point wrong → go back to fix ticket, do not commit
- Double-layer title bar appears → delete TitleBarZone or Canvas title-bar rectangle
- Splitter hover invalid → check whether NativeSplitter view tree is broken by `.drawingGroup` or `.background`