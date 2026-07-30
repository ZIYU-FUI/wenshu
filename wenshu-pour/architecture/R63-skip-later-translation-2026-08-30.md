# WO-001BI-R63: 翻译单 (skip/later/without 词组全中文化) — 已验证无需新增

[装机 user 8/30 拍]
- 'I don't have API key' 选项本来就有, 不叫这个名字, 有一个跳过
- 翻译做
- 这个选项先不用加 (不加新功能, 只翻译)

[真值调研 (PM-direct 8/30)]
- grep en.ts line 500-900 提取 287 个 key
- 全在 zh.ts 找到翻译 (Total missing: 0/287)
- 唯一 zh==en (没真译): cloudTitle / cloudSignInTitle = '文枢 Cloud' (产品名保留)

[之前 翻译已做完]
- R46: 加 9 条 i18n (backToSignIn / otherProviders / chooseLater / haveApiKey / connecting / recommended / featuredPitch / fireworksPitch / minimaxPitch)
- R47a: apiKeyFallback i18n hook
- R47a v2: minimaxPitch + CN wording polish (haveApiKey/chooseLater/fireworksPitch)
- R50: zh.ts zh 字面量已确认存在
- R51: update page stage labels

[R63 不需要新代码]
- CC 调研真值: 'common.close' 等全已译, 不要再加 key
- 装机 user 拍 'I don't have API key' 选项不另加 (原有 'chooseLater' / 'skip' 类按钮已存在)
- R61/R62 子单子会话 (R61 = messaging gateway banner / R62 = API key 'I don't have' 选项) → 装机 user 拍 '选项先不用加' → R62 撤, R61 也撤 (CC 误改 R63 范围, 我已 git checkout reset)

[不需要 commit]
- working tree 干净 (R63 CC 误改后已 reset)
- 不需要 commit (没有新改动)

[装机 user 必走]
- 翻译已做完, 装机后配置页应该全中文
- 不需重 build .app (R46/R47a/R47a v2 已 push, 仓根 i18n 文件就绪)
- 下一个装机包 WenShu-Setup.dmg 含 R57 bundled install.sh 即可

[落档 R63]
- 翻译单真值调研: en/zh 287 key 全部已译
- R61/R62 撤 (R62 选项不加, R61 banner 不加 - 你拍 'I don't have API key' 选项本来就有, 不用加)
