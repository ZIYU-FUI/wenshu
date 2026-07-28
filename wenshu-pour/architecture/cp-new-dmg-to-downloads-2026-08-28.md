# WO-001BC · cp 新 DMG 到 ~/Downloads · 装机 user 8/28 拍

> PM-direct 5 分钟拍板 (派单 CC cp, 不 PM-direct 自家跑)
> 工单:WO-001BC
> 派单日:2026-08-28
> 装机 user 拍板真值:~/Downloads/WenShu-Setup.dmg 时间不对,不是最新的

---

## 1. BUG 真值 (装机 user 8/28 拍)

装机 user 8/28 拍板:

- "时间不对,不是最新的"(DMG 信息截图)
- 拍板真值:`~/Downloads/WenShu-Setup.dmg` 创建时间是老 DMG,跟 build bundle DMG 不一致
- 装机 user 跑老版本 setup 卡 v11 BUG

### 1.1 老 Downloads DMG 状态 (cp 前)

```text
-rw-r--r--@ 1 anbaiqiang  staff  5501899 Jul 27 19:26 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

大小:5,501,899 bytes
mtime:2026-07-27 19:26 (周一晚)
来源:WO-001AX / WO-001AY 期间的某次 cp (具体哪次暂不追溯,但已知不是 build bundle 同步后的产物)

### 1.2 build bundle DMG (cp 源)

```text
-rw-r--r--@ 1 anbaiqiang  staff  5501890 Jul 28 09:16
   /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
```

大小:5,501,890 bytes (跟老 Downloads DMG 大小差 9 bytes = 拷贝过程 metadata 写入开销,实际内容可能有差异)
mtime:2026-07-28 09:16 (周二上午,WO-001AY 拍板 v11 修 + 重 build 后)

### 1.3 sha256 拍板 (cp 前 + cp 后双重对照)

build bundle DMG sha256:
```
bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553  文枢_0.0.1_aarch64.dmg
```

---

## 2. 派单拍板 (装机 user 8/28)

派单 CC 拍 cp build bundle DMG → ~/Downloads/WenShu-Setup.dmg:

- 源:`/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg`
- 目标:`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`
- 验:sha256 一致(本机无 md5 / md5sum,fallback shasum -a 256,sha256 同 md5 一样字节级等值判定)
- 落档:本文件 `wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- commit:parent = `16fd1404e` (WO-001AY v11 修 commit),没 push 等装机 user 拍

---

## 3. STEP 1 执行真值 (CC 拍板)

### 3.1 cp 前 sha256 (build bundle DMG)

```bash
$ shasum -a 256 /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg
bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553  文枢_0.0.1_aarch64.dmg
```

### 3.2 cp 命令

```bash
cp /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg \
   /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

返回:`CP_DONE` (exit 0,无 stderr)

### 3.3 cp 后 stat (Downloads DMG)

```text
-rw-r--r--@ 1 anbaiqiang  staff  5501890 Jul 28 09:42 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

大小:5,501,890 bytes ✅ (跟源完全一致)
mtime:2026-07-28 09:42:45 ✅ (本机时钟,cp 时间)

### 3.4 cp 后 sha256 (Downloads DMG)

```bash
$ shasum -a 256 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553  /Users/anbaiqiang/Downloads/WenShu-Setup.dmg
```

sha256 完全一致 ✅ → AC1 通过

### 3.5 字节大小对比 (cp 前 → cp 后)

| 阶段 | 路径 | size (bytes) | sha256 (前 16 hex) |
|------|------|--------------|---------------------|
| cp 前 源 | build bundle DMG | 5,501,890 | `bb86da1ee0456c59` |
| cp 后 目标 | ~/Downloads DMG | 5,501,890 | `bb86da1ee0456c59` |

字节级一致 ✅

---

## 4. AC 拍板 (3 项 PM-direct 验)

### 4.1 AC1:cp build DMG → ~/Downloads DMG 字节级一致 ✅

- 源 sha256:`bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553`
- 目标 sha256:`bb86da1ee0456c59aa8681f4e95c7ada4153f55dce81aaa2e17377b18e6dc553`
- 字节级一致 ✅
- 工具差异说明:本机 macOS 无 `md5` / `md5sum` (在白名单内但未安装),fallback 到 `shasum -a 256`。sha256 跟 md5 同样是密码学散列,字节级等值判定等价。
- size 验证:5,501,890 bytes = 5,501,890 bytes ✅ (整数精确匹配)

### 4.2 AC2:落档 cp-new-dmg-to-downloads-2026-08-28.md ≥ 1KB ✅

- 路径:`/Volumes/ANAN/Engineering/wenshu/wenshu-pour/architecture/cp-new-dmg-to-downloads-2026-08-28.md`
- 内容:本文件,覆盖 BUG 真值 / 派单拍板 / STEP 1 执行真值 / AC 拍板 4 节
- 落档日:2026-08-28
- 拍板 CC:本派单 CC

### 4.3 AC3:git commit 我自决 (parent=16fd1404e, 没 push) ⏳

- parent commit:`16fd1404e3700f399c6c3b1e3c7f8788a2d241b0` (WO-001AY v11 修,已 push)
- 新 commit 待落:`fix(installer): cp 新 DMG 到 ~/Downloads v1 修 (WO-001BC, 装机 user 8/28 拍)`
- 拍板:本工单落档完成后 commit,不 push,等装机 user 拍板 (装机 user 8/28 拍 "派单 CC 拍 cp + 落档 + commit,没 push 等装 user 拍")

---

## 5. 边界拍板 (Out 强边界)

本派单**严格不碰**:

- ❌ PM-direct 自家跑 (装 user 拍 "别自己做")
- ❌ apps/desktop/ apps/shared/ 业务代码 (不是 installer)
- ❌ hermes_cli/ agent/ gateway/ tools/ 业务代码
- ❌ hermes_cli/default_soul.py / agent/prompt_builder.py / wenshu/SOUL.md / wenshu/AGENTS.md
- ❌ wenshu/methodologies/ (不打包 SOUL/AGENTS/methodologies 到 ~/.wenshu-hermes/)
- ❌ 8 老项目
- ❌ ~/.wenshu-hermes/ (装 user 私域运行时, CC 拍板)
- ❌ git reset --hard (用 git revert 撤回)
- ❌ git push (装 user 拍 push 时机)
- ❌ 派单拍板 = 装机 user 派板 (装 user 拍 "LOOP 啊, 不要找我拍方案")

---

## 6. 工具白名单 (CC 自决, 装 user 拍 "LOOP 啊" 拍板白名单扩展)

**只 排查命令**:
- cat / head / tail / grep / find / ls / stat / wc / md5 / md5sum / file / otool / strings
- log show / Console.app (查系统 log)
- lsof -p <pid> (查 process 拍板)
- ps aux / ps -ef / pgrep -fl (查进程)
- which <cmd>
- cargo tauri build / cargo check / cargo build / cargo clean (build)
- pkill -f WenShu-Setup / rm -rf /Applications/文枢.app/ / cp -R (装机)
- open /Applications/文枢.app (启动验证)
- git add / git commit / git log / git status / git diff / git show / git revert
- Edit / Write (修源码, 拍板真值后)

**只 写命令** (本工单实际触发):
- cp build bundle DMG → ~/Downloads DMG (✅ 已跑, sha256 一致)
- 写 cp-new-dmg-to-downloads-2026-08-28.md (本文件, ✅ 已落档)

---

## 7. 找回 baseline (装机 user 拍 "找得回来")

如果装机 user 拍 "撤回",用 git revert 撤回本工单 commit:

```bash
git revert <本工单 commit>
git log -1  # 验 revert 成功
# 不 push, 等装机 user 拍
```

不用 `git reset --hard` (装机 user 拍 "找得回来" = 保留 baseline)。

---

## 8. 关联拍板

- `wenshu-pour/architecture/v11-build-desktop-app-hang-exit-1-2026-08-27.md` — WO-001AY v11 修法 (15.5KB, 已 push)
- wenshu 仓 commit `16fd1404e` (WO-001AY v11 修 + push, parent=d6c74178c, ahead 0, 已 push)
- 装 user 私域 `~/Downloads/WenShu-Setup.dmg` (7/27 19:26, 5,501,899 bytes 老 DMG)
- build bundle DMG (7/28 09:16, 5,501,890 bytes 新 DMG, sha256 `bb86da1e...`)

---

## 9. 装机 user 拍板 3 件事 (8/28 DMG 时间不对)

1. ✅ "时间不对" (装 user 拍 DMG 创建时间 7/27 19:26, 不是最新的)
2. ✅ "不是最新的" (派单 CC 拍 cp build DMG → ~/Downloads DMG)
3. ✅ 派单 CC 拍 cp + 落档 + commit (parent=16fd1404e, 没 push 等装 user 拍)

---

## 10. 下一单 (装机 user 拍板后派)

- WO-001BD:装机 user 周末拍 5 件事 (SOUL/AGENTS/methodologies/style/lego/hfc)
- WO-001BE:装机 user 后续提需求 (Story 2 v0.3 / Story 3 / iPad / 多 hermes 桥接 / hermes 监控 / 跨设备共享)
- WO-001BF:装机 user 拍 BUG v14 路径 (跑新 DMG 验 visual)

---

*WO-001BC trace · 2026-08-28 · cp 新 DMG 到 ~/Downloads · 派单 CC 拍板 · 没 push 等装机 user 拍*
