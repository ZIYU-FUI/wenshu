# WO-001BI-R88: welcome.tsx 智能体后真换行 (<br />, 之前 R83 \n JSX 文本节点不渲染)

[装机 user 8/30 拍板真值]
- 截图装包器 WenShu-Setup 副文案仍是单行, 装机 user 拍'加换行的需求没加'

[R83 误判真值]
- R83 commit 19cb7de7b 把 welcome.tsx 副文案改成两行 (用 \n 在 JSX 文本节点换行)
- 但 JSX 文本节点 \n 被当 whitespace collapse, Vite 编译后渲染仍是单行
- 装机 user 跑的是 R83 之前的 dist build, 没装新换行

[R88 PM-direct 兜底真值]
1. 改 apps/bootstrap-installer/src/routes/welcome.tsx 副文案用 <br /> 强制换行 (不是 \n)
2. rm -rf dist node_modules/.vite (清 Vite cache)
3. npm run build (Vite 重 build 出新 chunk index-AITeA1Ar.js)
4. dist 编译产物含真换行 (基于 Hermes..., </br> <br>, 系统自动...)
5. pnpm tauri build (cargo + rust 烤新 dist 进 bundled DMG)
6. cp /Users/anbaiqiang/Downloads/WenShu-Setup.dmg

[产物]
- /Users/anbaiqiang/Downloads/WenShu-Setup.dmg MD5 de6a54958be9e5d2dc1d4bbc17e0c9bf

[装机 user 必走]
1. 跑 ~/Downloads/WenShu-Setup.dmg (新 MD5 de6a54958...)
2. 双击启动 → 装包器 welcome 屏副文案应该两行

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语 '基于 Hermes 修改而来'
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
