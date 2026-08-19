# 004 真验证: swift run + screencapture -l + vision_analyze

> Q22 audit gate (老板 2026-08-19 拍板): 任何 wenshu 视觉 commit 必跑
> 依赖: 001-003

## 步骤

```bash
# 1. pkill 旧
pkill -9 -f WenshuApp; sleep 1

# 2. build + 后台跑
cd /Volumes/ANAN/Engineering/wenshu
swift build 2>&1 | tail -5
swift run WenshuApp &
APP_PID=$!; sleep 5

# 3. Quartz windowID
WIN_ID=$(swift /tmp/winlist.swift 2>&1 | grep -oE 'winID=[0-9]+' | head -1 | grep -oE '[0-9]+')

# 4. screencapture -l
screencapture -l $WIN_ID -o -x /tmp/wenshu-v0.15.png

# 5. vision_analyze
#   看: macOS titleBar 单层(不是双层)+ 6 区 + 6 拖拽线 + 顶栏 3 SF Symbol + 底栏占位文字 + 编辑器 4 PT inset
```

## 视觉 checklist (老板 2026-08-19 拍)

1. macOS titleBar 单层 (不是 Canvas 自画 + macOS chrome 双层)
2. 上 band 4 区 = 项目侧栏 + 项目预览 + 编辑器 + 专用工具(从左到右)
3. 下 band 2 区 = AI 聊天 + AI 动态
4. 顶栏每区 3 SF Symbol (book.closed / magnifyingglass / slider.horizontal.3) 替代原蓝矩形
5. 底栏每区 占位文字(.body) + 占位 SF Symbol
6. 编辑器 4 PT inset 双层
7. 6 拖拽线 静态 2 PT 黑 capsule
8. hover 拖拽线 = 4 PT accent 蓝光晕 + cursor 切换
9. drag 拖拽线 = zone 宽度跟手不抖动

## 失败处理

- 任一视觉点不对 → 回去修 ticket, 不 commit
- 双层标题栏出现 → 删 TitleBarZone 或 Canvas 标题栏矩形
- 拖拽线 hover 无效 → 检查 NativeSplitter view tree 是不是被 .drawingGroup 或 .background 隔断
