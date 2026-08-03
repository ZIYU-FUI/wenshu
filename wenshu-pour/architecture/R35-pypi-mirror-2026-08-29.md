# R35 · Python 包国内镜像（2026-08-29 装机拍板）

> 拍板锚点：先解决镜像问题，排除网络问题，再只看代码本身问题。

## 1. 根因与范围

装包器此前让 uv / pip 使用 `https://pypi.org/simple`；`uv.lock` 还记录了
`files.pythonhosted.org` artifact URL。国内网络即使开代理也可能在这些官方站点
超时，导致“网络失败”和“文枢代码失败”混在一起。

仓内只有 `scripts/install.sh`，没有第二份根级 `install.sh`。GUI 装包器通过
`apps/bootstrap-installer/src-tauri/src/install_script.rs` 下载/缓存该脚本并启动，
因此 R35 同时改脚本默认环境和 Rust resolver 的子进程继承环境。

## 2. 落地方案

### 2.1 清华主源 + 阿里 fallback

默认强制：

```bash
export UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
export UV_CONCURRENT_DOWNLOADS=100
```

- uv/pip 主源：清华 TUNA。
- 清华安装完整依赖集失败：切到
  `https://mirrors.aliyun.com/pypi/simple/`，重新安装完整依赖集，再沿用原有降级层。
- `pip install uv` fallback 同样先清华、失败后阿里。
- `UV_CONCURRENT_DOWNLOADS=100` 是 uv 实际支持的最大并发下载环境变量；仓内不存在
  `upload.max_pypi_connections` 配置项，因此没有编造该键，而是使用 uv 官方变量实现
  “加快装包”的拍板意图。

### 2.2 PyTorch 等包不再绕回官方专用源

uv 的 `UV_TORCH_BACKEND` 一旦从用户环境继承，会忽略普通 index 并访问
`download.pytorch.org`。shell 和 Rust resolver 都清除该变量，让通用 torch wheel
与其他 Python 包一起从国内 PyPI 镜像解析。

### 2.3 GUI 环境透传

`install_script.rs::resolve()` 在解析脚本前写入：

- `UV_INDEX_URL`
- `UV_DEFAULT_INDEX`
- `PIP_INDEX_URL`
- `UV_CONCURRENT_DOWNLOADS`

并移除 `UV_TORCH_BACKEND`。这样即使用户机器命中 R35 之前缓存的 install.sh，
GUI 启动的 bash/PowerShell 子进程仍继承国内镜像环境。

### 2.4 uv.lock 官方 artifact 处理

实测 `UV_INDEX_URL=清华 uv lock --check` 返回“lockfile needs to be updated”；现有
`uv.lock` 的 source/artifact 又固定为 pypi.org/files.pythonhosted.org。R35 强制镜像模式
因此跳过 `uv sync --locked`，改走 `uv pip install` 镜像解析，避免表面设置镜像、实际仍
下载官方 artifact。代价是该路径不再使用 lockfile hash 校验；这是本次“先彻底排除官方
网络”拍板的明确取舍，README 已同步说明。

## 3. 实测验证

### 3.1 静态与测试

- `bash -n scripts/install.sh`：exit 0。
- `bash scripts/install.sh --manifest`：JSON 可解析，protocol=1，10 stages。
- `cargo test --manifest-path apps/bootstrap-installer/src-tauri/Cargo.toml`：
  **41 passed, 0 failed**。
- `pnpm run typecheck`：exit 0。
- `pnpm run lint`：exit 0，保留 `progress.tsx` 2 条既有 warning，0 error。
- `pnpm run build`：exit 0；Vite 1888 modules，保留既有 CSS/sourcemap warning。
- `git diff --check`：exit 0。

### 3.2 国内源真实下载

使用临时 venv（跑完删除，不污染装机目录）：

- 清华：uv 0.11.32 从
  `https://pypi.tuna.tsinghua.edu.cn/simple/idna/` 解析并安装 `idna==3.11`，通过。
- 阿里：`--no-cache` 从
  `https://mirrors.aliyun.com/pypi/simple/idna/` 解析并安装 `idna==3.11`，通过。
- 清华与阿里 `/simple/torch/` HTTP 探测均返回 200。
- prerequisites 临时目录实跑 exit 0，日志显示：

```text
Managed uv found (uv 0.11.32 (...); default source: https://pypi.tuna.tsinghua.edu.cn/simple)
{"ok":true,"stage":"prerequisites","skipped":false}
```

## 4. R35 build 与交付

命令：

```bash
cd apps/bootstrap-installer
pnpm exec tauri build
```

结果：exit 0，release 编译 50.99s，Tauri 输出 2 bundles：

1. `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app`
2. `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.0.1_aarch64.dmg`

DMG 真值：

- size：5,544,989 bytes
- build mtime：2026-07-29 12:18:50 +0800（本机系统日期）
- SHA-256：`8e3aafb49336724ae8b62e99d3cd8561c851aa3fc5babadb586d58b7fb59eb50`
- MD5：`05f4b71287fdedfd6e96c33b8e37db42`
- 已复制到：`~/Downloads/WenShu-Setup.dmg`
- src/dst `cmp` = 0，SHA-256 完全一致。

二进制 `strings` 实测命中清华 URL、`UV_INDEX_URL`、`PIP_INDEX_URL`、
`UV_CONCURRENT_DOWNLOADS=100` 和 `UV_TORCH_BACKEND` 清理逻辑，证明 Rust 环境透传
已烤进新 `.app`。

## 5. 已知非 R35 阻断项

`codesign --verify --deep --strict` 对本地 bundle 返回 exit 1：当前构建仅有 linker ad-hoc
签名，未形成完整 sealed resources。R35 没有重生成签名密钥、没有改签名配置（项目红线），
Tauri build 与 DMG 生成均成功；正式签名/公证仍沿用后续发布流程处理。

## 6. 回滚

提交后可用 `git revert <R35 commit>` 回滚源代码与本文；`~/Downloads/WenShu-Setup.dmg`
是仓外交付物，回滚时需重新复制上一版 DMG。
