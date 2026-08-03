# WO-001BI-R81: install.sh + install.ps1 + bootstrap-installer 加 AtomGit fallback URL

[装机 user 8/30 拍板真值]
- '我想用 D = AtomGit (国内替代 GitHub)'
- '双代码云仓, 国内用户安装障碍少一些'

[真值 - 装机 user 实测]
- atomgit.com 国内访问 0.6s, raw.githubusercontent.com 国内超时 30s+
- 装包器 driver 拉 GitHub raw 国内可能超时, R57 bundled 已修老路径
- R81 = 双代码云仓 GitHub (origin) + AtomGit (fallback)

[PM-direct 8/30 兜底 R81]
1. scripts/install.sh:
   - REPO_ATOM_RAW="https://atomgit.com/ziyu-fui/wenshu/raw/main"
   - download_with_atomgit_fallback() (try GitHub first 30s timeout, then AtomGit)
   - Windows hint 加 AtomGit ir iex 备选
2. scripts/install.ps1:
   - $RepoAtomRaw const + AtomGit hint
3. apps/bootstrap-installer/src-tauri/src/install_script.rs:
   - ATOMGIT_REPOSITORY + ATOMGIT_RAW_BASE const
   - URL builder format! 加 AtomGit URL fallback (4 args 加)

[装机 user 必走 (镜像仓创建)]
1. 浏览器打开 https://atomgit.com 注册
2. 创建 wenshu 公开仓
3. git remote add atomgit git@atomgit.com:<你的用户名>/wenshu.git
4. git push atomgit main (全 25 commit push)
5. (可选) webhook GitHub push 触发同步到 AtomGit

[白名单保留]
- apps/bootstrap-installer/src/routes/welcome.tsx 致谢语
- hermes-agent.nousresearch.com URL
- 上游仓 fork / node_modules/ / MIT 版权
