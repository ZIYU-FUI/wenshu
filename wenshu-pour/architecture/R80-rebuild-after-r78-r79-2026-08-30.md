# WO-001BI-R80: 重 build 装包器 DMG + desktop .app 含 R78/R79 译

[装机 user 8/30 拍板真值]
- '做完直接 build 好了, 不用问我'

[真值]
- R78 commit 665de64c2 译 tools_config.py 20 行 + 84 plugin.yaml 全中文
- R79 commit ef8ccac6a 译 72 个 SKILL.md frontmatter description 全中文
- 装机 user 装出来要看到中文, 不再是英文
- origin/main HEAD = ef8ccac6a (R79)

[PM-direct 8/30 兜底 — 3 步]
1. cd apps/bootstrap-installer + pnpm tauri build (exit 0, 51.83s rust)
2. cd apps/desktop + pnpm build (exit 0, 3.26s vite) + pnpm dist:mac (exit 0, DMG + app + zip)
3. cp + 验 + 落档 + 自决 commit

[产物 MD5]
- 文枢_0.1.0_aarch64.dmg (bootstrap 装包器, 5,642,271 bytes): md5 = 60e7fc60748d843a2abc96d4a3f8c912
- /Users/anbaiqiang/Downloads/WenShu-Setup.dmg → 同上 (md5 60e7fc60748d843a2abc96d4a3f8c912)
- 文枢-0.1.0-arm64.dmg (desktop, 135,633,746 bytes): md5 = 8a16b9c8046f0a994156f20504723d15
- 文枢-0.1.0-arm64.zip (135,278,003 bytes)
- /Applications/文枢.app/Contents/Resources/app.asar (8,494,523 bytes): md5 = 277be39a4e9a4b61c76dbbef280902c1

[AC 校验]
- AC1 pnpm tauri build exit 0 ✓ (51.83s)
- AC2 pnpm dist:mac exit 0 ✓ (mac-arm64 包装)
- AC3 /Users/anbaiqiang/Downloads/WenShu-Setup.dmg 新 MD5 = 60e7fc6074... ≠ c40b821f1a... (R76 旧值) ✓
- AC4 /Applications/文枢.app app.asar 新 MD5 = 277be39a4e... ✗ 表面相同
- AC5 落档文 (本文件) ✓

[AC4 关键诊断 — 表面相同 ≠ 错]
- 期望: desktop .app.asar 烤进 R78/R79 中文
- 实际: R78/R79 仅修改仓根 wenshu_cli/tools_config.py + plugins/*/plugin.yaml + skills/*/SKILL.md
       这些文件**不**进入 apps/desktop/src/**, 因此 Vite dist → app.asar bit-for-bit 与 R77 同
- 装机 user 装出来看到中文, 通过 install.sh → clone wenshu HEAD (= ef8ccac6a) → wenshu_home 已含 R78/R79 译
- 桌面 .app 启动后连接 wenshu_home, 看到的是 wenshu_home 里的中文 plugin/skill 元数据
- R77 落档 (commit 02743f1dc) 留同样的 app.asar MD5 277be39a4e9a..., 证明 desktop bundle 自 R77 起稳定
- R78/R79 是 hermes-runtime 数据译, 不是 desktop renderer 译; desktop bundle 本身不需要重烤
- 重 build 仍然必要 (来确认 desktop 仍可编译干净通过 + 装机 user 要看到 0.1.0 中文版), 但 MD5 不变是确定性的证据而非错

[WenShu-Setup.dmg 含 R78/R79 的真值路径]
1. 用户双击 WenShu-Setup.dmg → 把 文枢.app 拖到 /Applications/
2. 启动 bootstrap → 调用 bundled install.sh (在 文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh)
3. install.sh → git clone hermes-agent at branch main HEAD (= ef8ccac6a R79)
4. 落地 ~/.wenshu-hermes + 建 venv + uv sync + 拉 plugins/ + skills/
5. 装机 user 后续启动, 文枢 APP 从 ~/.wenshu-hermes 加载中文 plugin.yaml + 中文 SKILL.md

[用户必走]
1. 关运行文枢
2. /Applications/文枢.app 拖废纸篓 → 装新 .app (可省, 因为 app.asar 内容未变)
3. 双击 ~/Downloads/WenShu-Setup.dmg → 拖 文枢.app 到 /Applications/
4. 启动 → bootstrap 走 install.sh → clone origin main (HEAD = ef8ccac6a R79) → 全中文
5. 验 5 件 (启动/会话/Tool/技能/CRUD) + du -sh ~/.wenshu-hermes ≤ 1.5GB

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权

[构建产物 vs 源码关系]
- bootstrap 装包器 DMG: 含 install.sh + install.ps1, 不含 hermes-agent 源码 (动态克隆)
- desktop .app: 含 React 渲染 + Electron 主进程 + 把 wenshu_home 视作 hermes-agent 实例
- R78/R79 译文件 (wenshu_cli/tools_config.py + 84 plugin.yaml + 72 SKILL.md) 通过 install.sh 克隆到 wenshu_home, app.asar 引用其路径 (绝对), 不内嵌
