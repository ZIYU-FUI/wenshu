# WO-001BI-R128: 修 pnpm not found on PATH (装包器 spawn 子进程 PATH 不带 pnpm)

[装机 user 8/3 反馈]
- 装 user 8/3 03:47 跑 wenshu update / 装包器 DMG 跑 wenshu-setup
- bootstrap-installer.log 末: "✗ macOS release rebuild failed: pnpm was not found on PATH"
- 装包器 binary 跑 11 步 bootstrap -> spawn 子进程调 wenshu update -> 子进程 PATH 继承自装包器父进程
- 装包器父进程 (launchd/手启动) PATH 不含 ~/.local/bin 或 /opt/homebrew/bin
- 装 user PATH (env) = ...hermes-agent/venv/bin:.../usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin - 没 pnpm 路径
- 装 user 实际 pnpm 位置: /Users/anbaiqiang/.local/share/pnpm/pnpm v11.8.0 (7/15 装的)

[真根因]
- wenshu_cli/subcommands/update.py:29 pnpm = shutil.which("pnpm")
- shutil.which() 用当前进程 PATH 查找 - 装包器 binary spawn 子进程的 PATH 不含 pnpm 目录
- 装 user 实际有 pnpm (v11.8.0) 装在 /Users/anbaiqiang/.local/share/pnpm/pnpm
- 装 user 还 brew 装了 pnpm v11.18.0 在 /opt/homebrew/bin/pnpm
- 两条都跑得通，但 shutil.which() 都不找

[修法 - PM-direct 自家改]
- wenshu_cli/subcommands/update.py:
  - 加 _R128_FALLBACK_PATHS tuple:
    - /Users/anbaiqiang/.local/bin (npm/pnpm)
    - /Users/anbaiqiang/.local/share/pnpm (pnpm 二进制)
    - /opt/homebrew/bin (brew)
    - /usr/local/bin
    - ~/.cargo/bin (cargo)
  - 加 _resolve_executable(name) helper: shutil.which() 优先, fallback 到已知 paths
  - _run_update_build_step 加 env= 参数,显式 inject PATH to child subprocess
  - pnpm/cargo 都用 _resolve_executable() 查

[验证]
- python3 -m py_compile wenshu_cli/subcommands/update.py exit 0
- diff stat: 1 file, 48 insertions, 5 deletions

[装 user 必走]
- 跑 wenshu update --yes (会触发 R127 + R128 修)
- 重启 文枢 desktop
- 验: 发消息看 session.create 不再 timeout + 更新流程不再 fail
