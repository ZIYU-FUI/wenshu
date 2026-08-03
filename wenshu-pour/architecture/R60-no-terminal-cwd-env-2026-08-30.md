# R60 — installer 不再生成 `TERMINAL_CWD` 环境项

- 工单：WO-001BI-R60
- 落档日期：2026-08-30
- 修法：A

## 背景与决策

`.env` 中的 `TERMINAL_CWD` 已废弃；工作目录应由用户在 `config.yaml` 的 `terminal.cwd` 配置。仓根示例 `cli-config.yaml.example` 的 `terminal` 段已经给出 `cwd: "."`，并说明 gateway/messaging/cron 使用该配置、旧式 `.env` cwd 值已废弃。

bootstrap-installer 不直接生成配置，而是解析并执行随包、开发仓或网络取得的 `scripts/install.sh` / `scripts/install.ps1`。因此在两套安装脚本创建新 `.env` 时统一过滤模板中的 `TERMINAL_CWD` 行，覆盖 GUI bootstrap-installer 与命令行安装入口；已有 `.env` 继续原样保留，不删除用户配置。

## 修改

- `scripts/install.sh`：从 `.env.example` 创建新 `.env` 时，用 `awk` 跳过注释或启用状态的 `TERMINAL_CWD=` 行；注释指向 `config.yaml` 的 `terminal.cwd`。
- `scripts/install.ps1`：采用等价正则过滤后，以无 BOM UTF-8 写入新 `.env`；注释指向 `config.yaml` 的 `terminal.cwd`。
- `tests/test_install_no_terminal_cwd_env.py`：验证两种过滤规则作用于真实 `.env.example` 后，生成内容均不含 `TERMINAL_CWD`，并锁定两套脚本的配置指引和过滤逻辑。

## 官方资料核查

工单指定的 `https://www.electron.build/configuration/configuration` 在核查时返回 HTTP 404；官方 sitemap 给出的当前配置文档地址是 `https://www.electron.build/docs/configuration`。该资料用于确认 electron-builder 的应用打包配置范围；本修复不新增或臆造 electron-builder 配置项，而是在 bootstrap-installer 实际调用的安装脚本中处理 `.env` 模板。

## 验证计划与结果

- `pytest -q tests/test_install_no_terminal_cwd_env.py`
- `bash -n scripts/install.sh`
- PowerShell parser syntax检查（环境存在 `pwsh` 时执行）。
- 静态检查 bootstrap-installer 的脚本解析/执行链仍指向 `scripts/install.sh` / `scripts/install.ps1`。
- 检查本次 diff 未包含既有的 `apps/desktop/package.json` 修改。

新装生成的 `.env` 不含 `TERMINAL_CWD`，所以 desktop 不会再因安装器生成该 deprecated key 而记录对应 warning。已有用户 `.env` 不在本工单迁移范围内。
