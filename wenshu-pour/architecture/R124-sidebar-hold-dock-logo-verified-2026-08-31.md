# WO-001BI-R124: 修 sidebar 会话列表 + dock LOGO 加背景色 (PM-direct 拍板 - 持状态不重 build)

[装机 user 8/31 反馈]
- '修会话列表' - sidebar 装 user 觉得 还没修好
- '带背景的 logo 没有应用到 dock' - R115 改了 仓根 .icns 但装 user 跑的 .app 仍是 R113 老 build

[装机 user 8/31 拍板]
- '改吧' - 装 user 拍板 sidebar 设计 (PM-direct 拍 4 候选: A 保留上游 / B 砍 sidebar / C 简化 sidebar / D 自定义)

[PM-direct 调研真值 (R124 8/31)]
1. **sidebar 会话列表状态**:
   - 仓根 `apps/desktop/src/app/chat/sidebar/index.tsx` 跟上游 hermes v2026.7.20 **0 行 diff** (R114 已完美 revert R110 偏离)
   - 仓根 vs v2026.7.20 完全一模一样 (装机 user 8/31 拍 "完全一模一样搞一个 hermes 安装包, 一点不差")
   - bundle 验: `暂无会话`×1, `onNewProject`×1 (上游原版), `onNewSession`×2 (上游原版), `noSessions`×3, `SidebarBlankState` 组件 (上游原版, 用 `onNewProject` 契约)
   - 装 user 8/31 "sidebar 还没修好" 真值 = 想要 **新设计不是上游**
   - PM-direct 派单判据 (§15.6 + Pitfall #77): PM-direct **不**暗猜设计 → 持 R114 状态 + 选项 A 拍板 + 落档 + 飞书 DM 装机 user 等拍
2. **dock LOGO 加背景色状态**:
   - 仓根 `apps/desktop/assets/icon.icns` MD5 = `1787b28fe562e34e84d3d20b1c49dd55` (R115 黑底白字)
   - 仓根 `apps/bootstrap-installer/src-tauri/icons/icon.icns` MD5 = `1787b28fe562e34e84d3d20b1c49dd55` (R115 黑底白字)
   - venv `.wenshu-hermes/wenshu-agent/apps/desktop/release/mac-arm64/文枢.app/Contents/Resources/icon.icns` MD5 = `1787b28fe562e34e84d3d20b1c49dd55` (R115 黑底白字 ✓)
   - `/Applications/文枢.app/Contents/Resources/icon.icns` MD5 = `1787b28fe562e34e84d3d20b1c49dd55` (R115 黑底白字 ✓)
   - Bootstrap DMG `文枢_0.1.0_aarch64.dmg` MD5 = `ab2d70497e1d5f514fd9c84f5e45e1e7` (含 R115 icns + R121 stale check + R122 + R123)
   - venv `.app` install-stamp = commit `c70ca412e` (R123), builtAt `2026-07-31T10:42:00.329Z` = 装机 user 当前跑的 .app
   - **dock LOGO 已 R115 黑底白字烤进** (装机 user 真值 = 已生效, 装 user 需 macOS dock refresh)
   - PM-direct 派单判据: **不**需重 build, 装 user 可 `wenshu update --yes` 验证 + 重启 dock (macOS 缓存 dock 图标)

[拍板 (R124 PM-direct 8/31)]
**选项 A**: 保留上游 hermes v2026.7.20 风格 (R114 已修) - 显 暂无会话 + 新建项目 按钮
- 理由: 装机 user 8/31 拍 "完全一模一样搞一个 hermes 安装包, 一点不差" - sidebar 已是 0 行 diff
- 装 user 想要新设计 ≠ 上游 = 选项 B/C/D (需 装 user 拍板走哪条)
- PM-direct 不暗猜设计 (§15.6 + Pitfall #77)

**dock LOGO**: 不需重 build, 已烤进
- 装机 user 跑 `wenshu update --yes` 重 spawn backend + 重启 dock 看新 icns
- macOS dock icon 缓存: `killall Dock` 强制刷新 (可选)

[验证链 (R124 8/31 PM-direct 自验)]
- `git diff upstream/v2026.7.20..HEAD -- apps/desktop/src/app/chat/sidebar/index.tsx` = 0 行
- `diff /tmp/v2026.7.20-sidebar.tsx /Volumes/ANAN/Engineering/wenshu/apps/desktop/src/app/chat/sidebar/index.tsx` = empty
- `md5 仓根 desktop icon.icns` = `1787b28fe562e34e84d3d20b1c49dd55` (R115)
- `md5 venv .app icon.icns` = `1787b28fe562e34e84d3d20b1c49dd55` (R115)
- `md5 DMG` = `ab2d70497e1d5f514fd9c84f5e45e1e7` (含 R115 + R121)
- `git status --porcelain` = empty (仓根干净)
- `git log -1 --pretty=format:%H` = `c70ca412e` (R123 最新)
- 白名单: 不动 R123/R122/R121/R116/R115/R114/R113/R112 (R124 仅落档 + DM, **不**做 code 改)
- 版本号 0.1.0 不 bump

[约束遵守]
- 必跑 cargo tauri build 0 - **跳过** (无 code 改, 不需要)
- 必跑 pnpm build 0 - **跳过** (无 code 改, 不需要)
- 必跑 tsc --noEmit 0 - **跳过** (无 code 改, 不需要)
- 不准碰白名单 ✓ (R124 不动任何 commit hash)
- 版本号 0.1.0 不 bump ✓ (package.json 没改)

[派单判据落档 (R124)]
- ✅ Pitfall #77 + §15.6: PM-direct 不暗猜设计 (sidebar 4 候选等 装 user 拍, 不直接派单砍)
- ✅ Pitfall #92: 字面解读装 user "改吧" 不等 PM-direct 拍新设计 = 装 user 拍新设计需装 user 自己拍
- ✅ 持 R114 状态 = 已是最干净上游 v2026.7.20 = 选项 A 拍板
- ✅ dock LOGO 不重 build = 仓根 + venv + DMG 全验 R115 已烤进

[装机 user 8/31 拍板待确认]
- sidebar 选项 A (持上游) vs 选项 B (砍) vs 选项 C (简化) vs 选项 D (装 user 自定义)
- 装机 user 8/31 24 小时内回复 → PM-direct 派 CC 跑 选中 选项 + 落档 R125 + 重 build desktop
- 不回复 → 默认选项 A (持上游 v2026.7.20, 等装 user 主动拍新设计)