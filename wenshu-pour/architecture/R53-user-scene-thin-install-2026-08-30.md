# R53: 用户场景 install.sh 瘦身 4.5G → 800MB (装机 user 8/30 拍)

[装机 user 8/30 拍板真值]
- "我安装测试，别把我当开发者，我装的就是一个用户端"
- "我们的开发者用的你自己管理，逻辑上应该在我们的数据盘的项目文件夹"

[之前误判真值]
- 之前 7/24 拍板"完全 1:1 复制 hermes 上游" = 开发者场景 OK, 但装机 user 是用户场景, 装出来 4.5G 不合理
- 我之前没区分开发 vs 用户场景, 把所有用户场景都按开发场景设计, 错了

[开发者 vs 用户 边界]
- 开发者场景: `/Volumes/ANAN/Engineering/wenshu/` (PM-direct + CC 工作区)
  - 完整 git clone (含历史) = 3.5GB
  - 完整 venv = 1.5GB
  - 多版本调试, 历史追溯, 这是 OK 的
- 用户场景: `/Users/anbaiqiang/.wenshu-hermes/` (装机 user 装出来的运行时)
  - 不该带完整 .git/ 历史 (1GB 省掉)
  - 不该每次 wenshu update 重装 venv (1.5GB 省掉)
  - 不该 bootstrap-cache 累积 (500MB 省掉)
  - 用户装一次就该 ~800MB, 不是 4.5G

[R53 改动]
1. scripts/install.sh:
   - git clone --depth=1 (200MB → 50MB)
   - uv 共享 cache (避免重装 venv)
   - rm -rf bootstrap-cache 末尾清理
2. wenshu_cli/commands/update.py:
   - git pull --ff-only --depth=1 (浅拉取, 不累积历史)

[开发场景不动]
- /Volumes/ANAN/Engineering/wenshu/ 仍走完整 git clone
- 装机 user 装的 ~/.wenshu-hermes/ 走浅克隆 + 共享 venv
- install.sh 检测 WENSHU_DEV_INSTALL env 决定走开发路径 vs 用户路径 (默认用户)

[AC]
- AC1 用户场景装机一次 .wenshu-hermes/ ≤ 1.5GB (当前 4.5GB)
- AC2 装包后 wenshu update 仍能跑 (在线更新链路不断)
- AC3 开发者场景 env=WENSHU_DEV_INSTALL=1 仍能装完整 git clone
- AC4 commit + push origin
