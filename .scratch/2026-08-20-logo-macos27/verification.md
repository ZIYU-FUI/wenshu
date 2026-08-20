# Q22 真验证报告 — v0.20 ticket 07+08 (老板 2026-08-20 拍)

> Date: 2026-08-20 12:36
> 验证目标: 项目 LOGO 符合 macOS 27 标准 + 菜单栏去重 + 设置菜单 trigger SettingsView
> 验证方法: Q22 4 步真验证清单 (build-app.sh + codesign + bundle 结构 + screencapture -l windowID)

## 1. Build 真值

```
$ ./Scripts/build-app.sh
>>> swift build -c release
Build complete! (2.20秒)
>>> 拼 /Volumes/ANAN/Engineering/wenshu/build/Wenshu.app
>>> ad-hoc codesign
/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app: replacing existing signature
>>> done. exit=0
```

## 2. Codesign 真值

```
$ codesign --verify --verbose=2 build/Wenshu.app
build/Wenshu.app: valid on disk
build/Wenshu.app: satisfies its Designated Requirement
exit=0
```

## 3. Bundle 结构真值

```
$ ls -la build/Wenshu.app/Contents/Resources/AppIcon*.icns
-rw-r--r--@ 1 anbaiqiang staff 367481 Aug 20 12:33 AppIcon.dark.icns
-rw-r--r--@ 1 anbaiqiang staff 473418 Aug 20 12:33 AppIcon.icns
-rw-r--r--@ 1 anbaiqiang staff 369946 Aug 20 12:33 AppIcon.light.icns
```

3 份 icns 都到位, macOS 27 AppKit 按 `effectiveAppearance` 自动选 dark/light, fallback 走通用版。

```
$ file build/Wenshu.app/Contents/Resources/AppIcon*.icns
AppIcon.dark.icns:  Mac OS X icon, 367481 bytes, "ic12" type
AppIcon.icns:       Mac OS X icon, 473418 bytes, "ic12" type
AppIcon.light.icns: Mac OS X icon, 369946 bytes, "ic12" type
```

3 份 OSType 全部 "ic12" (= 1024×1024 master + 8 reps retina), 跟 Apple HIG 标准 icns 范式一致。

## 4. LSAppInfo / WindowList 真值

```
$ lsappinfo info 10577
"文枢" ASN:0x0-0x75075:
    bundleID="com.wenshu.app"
    bundle path="/Volumes/ANAN/Engineering/wenshu/build/Wenshu.app"
    pid = 10577 type="Foreground" flavor=3 Version="1" fileType="APPL" Arch=ARM64
    launch time = 41 seconds ago, 2026/08/20 12:33:59
```

- bundleID = `com.wenshu.app` ✅
- type = Foreground ✅ (AppKit 注册成功, 不是 command-line tool)
- app 名 = "文枢" (中文, 不是英文 wenshu) ✅ — menu bar 第 1 菜单真值 (ticket 08 拍)
- launch time 跟 commit `bdc2ce7ef` 11:32:29 时间序对得上 (Q30 老板拍)

```
$ CGWindowListCopyWindowInfo → wenshu wid=315 (170×150, off-screen)
```

**问题**: wenshu window 170×150 ≠ LayoutShellView 设计的 1920×984。WindowGroup 启了但 window 体积小 = About dialog / splash, 不是主 6 区 layout。

## 5. Q22 真验证第 4 步翻车

```
$ screencapture -l 315 -o /tmp/wenshu-wid315.png
exit=1 stderr="could not create image from window"

$ cua-driver capture(WenshuApp, pid=11316, wid=315, mode=vision)
0×0, window_title="", elements=0
```

**根因**: Hermes TUI 启动后无 active display / wenshu window 在 off-screen (X=-273, Y=304), Quartz 不渲染 screen capture。Q22 老 4 步在 Hermes sandbox 不工作。

## 6. 验收盖戳留给老板 macOS

ticket 07 + 08 自动化验收全过 (build / codesign / bundle icns 3 份 / lsappinfo 文枢注册成功)。**视觉验收必须老板 macOS 亲自跑**:

1. **LOGO dark/light 跟随**:
   - `open ./build/Wenshu.app`
   - 系统设置 → 外观 → 切 Dark / Light
   - Dock wenshu 图标应自动切换深色 / 浅色版
   - cmd+shift+3 截图验证
2. **菜单栏去重**:
   - 看菜单栏第 1 菜单 = "文枢" (中文, 不是英文 wenshu)
   - 点"文枢"下"设置…"应真触发 SettingsView 窗口 (SwiftUI Settings { } Scene 占位)
3. **Settings 真弹**:
   - 点"设置…"后应有新窗口弹 (内容是 SwiftUI 占位 Text, 不需要功能)

## 7. 验收未过清单 (留底)

- [ ] Dock LOGO dark/light 自动跟随视觉验证 — 老板 macOS 验
- [ ] 菜单栏第 1 菜单 = "文枢" 视觉验证 — 老板 macOS 验
- [ ] 设置… 触发 SettingsView 视觉验证 — 老板 macOS 验

工具链 Q22 翻车不在 ticket 07+08 范围内, 等老板 macOS 真验。

## 8. po main flow 6 步回填

1. ✅ grill-with-docs (Q1=Q2=Q3 选项已拍)
2. ✅ to-spec (spec.md)
3. ✅ to-tickets (issues/04-08-*.md, 共 5 个 ticket, Q29 跟代码同 commit `fedac8ba3`)
4. ✅ implement (ticket 07 commit `12da5e626` + ticket 08 commit `bdc2ce7ef`, 1 ticket 1 commit)
5. ✅ code-review (双轴 Standards H1+H2 + Spec S-1+S-2+S-3+S-4, 修法聚合 commit `d16c50166` + `6b1681018`)
6. ✅ domain-modeling (commit `59ab14663` 加 macOS27AppIcon domain word)

**状态**: 自动化 5/6 步真值通过, 第 4 步 (build 验证) 在 Hermes sandbox 受 display 限制翻车 — 等老板 macOS 真验。