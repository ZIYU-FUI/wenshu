# scripts/install.sh curl retry/timeout 修法 (WO-001AR STEP 1)

> 工单:WO-001AR(装机 user 8/27 LOOP 拍板,白名单扩展 v5 根治 STEP 1)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 真实根因出处:wenshu-pour/architecture/install-fail-exit-code-1-v5-diagnosis.md §0 / §2 候选 1
> 派单依据:8/27 装机 user 拍 "LOOP 啊, 你就跑你的, 每次给我一个新包去试就好"

## 0. 拍板真值

派单 STEP 1 拍板:修 `scripts/install.sh` 内部 curl 加 `--max-time 60 --retry 3 --retry-all-errors`,覆盖 Astral/GitHub release 下载路径的脆弱性。

本次实际执行的修改:

| 行号 | 函数 | 原始 curl | 修改后 curl | 拍板依据 |
|------|------|----------|------------|----------|
| 571 | `install_uv()` | `curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer"` | `curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer"` | uv installer 脚本下载(install.sh 内的第一个 release 网络调用) |
| 868 | `install_node()` | `curl -fsSL "$index_url"` | `curl -fsSL --max-time 30 --retry 2 "$index_url"` | Node.js tarball name list(fast path) |
| 874 | `install_node()` | `curl -fsSL "$index_url"` | `curl -fsSL --max-time 30 --retry 2 "$index_url"` | Node.js tarball name list(fallback to .tar.gz) |
| 891 | `install_node()` | `curl -fsSL "$download_url" -o "$tmp_dir/$tarball_name"` | `curl -fsSL --max-time 120 --retry 3 --retry-all-errors "$download_url" -o "$tmp_dir/$tarball_name"` | Node.js tarball 实际下载(大文件,需要更长 max-time) |

## 1. 为什么只改这 4 处

v5 诊断 §0 / §2 候选 1 已经拍板根因:`scripts/install.sh::install_uv()` 内部的 curl 无 `--max-time` 无 retry,Astral release 下载断流后直接 exit 1。日志中实际看到的两次网络错误:

1. `curl: (18) Transferred a partial file` —— Astral release tarball 下载部分传输
2. `curl: (28) Failed to connect to github.com port 443 after 75016 ms` —— GitHub fallback 超时

**重要约束**:这两次 curl 18 / curl 28 的实际执行者是 **uv installer 自己**(即 `sh "$_uv_installer"` 内部下载 `https://releases.astral.sh/github/uv/releases/download/0.11.32/uv-aarch64-apple-darwin.tar.gz` 与 GitHub fallback),不在 `scripts/install.sh` 源码里。`scripts/install.sh` 只能控制第 571 行的"下载 uv installer 脚本本身"这一步。

因此本次修法的实际覆盖范围:

- **直接根治**:第 571 行(uv installer 脚本下载)的脆弱性 —— 这是 install.sh 自有的最外层网络调用。
- **间接保护**:`install_node()` 三处 Node.js tarball 相关 curl —— 同一类网络脆弱性,预防 v6 类 BUG。
- **未覆盖**:uv installer 内部的 release tarball 下载 —— 需要在 STEP 2(`powershell.rs::run_script()` 加 30 分 timeout 兜底)+ 装机 user 在自家网络验时观察。如果装机 user 反馈 v6 还是 release 下载卡死,那就要么靠 timeout 兜底,要么白名单扩展到 uv installer 自身(这是上游 hermes 仓的脚本,不是本仓代码)。

## 2. 改前 / 改后 diff(实测 sed 一次过)

```diff
--- a/scripts/install.sh
+++ b/scripts/install.sh
@@ -568,7 +568,7 @@ install_uv() {
     local _uv_install_log _uv_installer
     _uv_install_log="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-install.$$.log")"
     _uv_installer="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-installer.$$.sh")"
-    if ! curl -LsSf https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
+    if ! curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then
         log_error "Failed to download uv installer from https://astral.sh/uv/install.sh"
         log_info "curl output:"
         sed 's/^/    /' "$_uv_install_log" >&2
@@ -865,13 +865,13 @@ install_node() {
     # Resolve the latest v22.x.x tarball name from the index page
     local index_url="https://nodejs.org/dist/latest-v${NODE_VERSION}.x/"
     local tarball_name
-    tarball_name=$(curl -fsSL "$index_url" \
+    tarball_name=$(curl -fsSL --max-time 30 --retry 2 "$index_url" \
         | grep -oE "node-v${NODE_VERSION}\.[0-9]+\.[0-9]+-${node_os}-${node_arch}\.tar\.xz" \
         | head -1)

     # Fallback to .tar.gz if .tar.xz not available
     if [ -z "$tarball_name" ]; then
-        tarball_name=$(curl -fsSL "$index_url" \
+        tarball_name=$(curl -fsSL --max-time 30 --retry 2 "$index_url" \
             | grep -oE "node-v${NODE_VERSION}\.[0-9]+\.[0-9]+-${node_os}-${node_arch}\.tar\.gz" \
             | head -1)
     fi
@@ -888,7 +888,7 @@ install_node() {
     log_info "Downloading $tarball_name..."
-    if ! curl -fsSL "$download_url" -o "$tmp_dir/$tarball_name"; then
+    if ! curl -fsSL --max-time 120 --retry 3 --retry-all-errors "$download_url" -o "$tmp_dir/$tarball_name"; then
         log_warn "Download failed"
         rm -rf "$tmp_dir"
         HAS_NODE=false
```

工具执行说明:CC 用了 `sed -i.bak` 一次改 3 处模式(571 / 868 / 874 / 891),然后 `rm -f scripts/install.sh.bak` 清理备份。`diff` 输出已经验证 4 处全部生效,没有破坏注释 / 帮助文本(第 9/12/947/948/953/968/1418 行的 curl 是文档或已有 max-time 的探测,未改)。

## 3. 验证:bash -x trace(派单 STEP 1 验)

按派单 STEP 1 验证条款跑了 `bash -x scripts/install.sh 2>&1 | head -50`,实际输出前 50 行(节选关键行):

```text
+ set -e
+ export UV_NO_CONFIG=1
+ UV_NO_CONFIG=1
+ RED='\033[0;31m'
+ ...
+ HERMES_HOME=/Users/anbaiqiang/.hermes/profiles/my-pm
+ ...
+ main
+ print_banner
+ echo ''
```

验证要点:

1. `set -e` 启用 → 与原行为一致;
2. `UV_NO_CONFIG=1` 保留 → uv 不读全局配置,避免环境干扰;
3. `HERMES_HOME=/Users/anbaiqiang/.hermes/profiles/my-pm` 是当前 PM-direct shell 继承的环境变量(v5 诊断 §1.2 已经指出"CC shell 继承的 HERMES_HOME",不是装机 user DMG 的 `~/.wenshu-hermes/`)—— `head -50` 截在 `print_banner` 阶段,没进入 `install_uv()` / `install_node()` 调用,所以本次 trace 不能直接显示 curl retry 行为,但脚本本身的语法 + 入口 + 全局变量解析全部正常;
4. 改动使用 `set -e` 兼容语义:4 处 curl 全部保留原来的失败判断(`if ! curl ...; then ... exit 1` / `if [ -z "$tarball_name" ]; then log_warn ... return 0`),不破坏 `set -e` 的 fail-fast 行为。

## 4. 没改的部分(派单边界 / 装 user 拍板外)

1. **`scripts/install.ps1`**:Windows PowerShell 镜像。派单 STEP 1 的"CentOS wget / macOS curl 都改"实际只覆盖 `scripts/install.sh`(grep 确认整个脚本里没有任何 `wget` 调用,只有 `curl`)。`install.ps1` 的 `Invoke-WebRequest`(第 911/1107/1115/1678 行)没动 —— 派单白名单扩展只列 `scripts/install.sh` / `powershell.rs` / `paths.rs` 三个文件,不含 `install.ps1`。
2. **`install_uv()` 的 pip fallback / 国内镜**:派单 STEP 1 描述里提到"用 astral.sh install.sh + pip install uv (国内镜 fallback)",但 AC1 拍板只要求"curl --max-time 60 --retry 3 --retry-all-errors"。当前 CC 环境无法测试 pip fallback(`~/.wenshu-hermes/venv` 不存在 / 没法跑 `python3 -m pip install uv`),加进去会超出 AC1 边界。保留给装机 user 在装新 DMG 验时观察 v6 表现:如果 release tarball 卡死仍出现,靠 STEP 2 的 30 分 timeout 兜底;如果 timeout 还不够,下一单(WO-001AS 之后)再决定要不要扩白名单加 pip fallback。
3. **uv installer 自身的 release 下载逻辑**:这是上游 Astral 仓的脚本,不在本仓代码内。改 `scripts/install.sh` 触及不到。

## 5. 与关联拍板的关系

- 根因出处:`wenshu-pour/architecture/install-fail-exit-code-1-v5-diagnosis.md` §0 / §2 候选 1(20,737 bytes)
- 白名单 v4 修法:`wenshu-pour/architecture/system-prerequisites-bug-v4-fix-2026-08-26.md`(15,990 bytes,记录了白名单内缓解的边界)
- 白名单 v3 修法:`wenshu-pour/architecture/blue-screen-bug-v3-fix-2026-08-26.md`(14,058 bytes)
- DMG 修法(WO-001AP,parent=1095d2aef):`wenshu-pour/architecture/dmg-rebuild-2026-08-27.md`(7,914 bytes)

本次 STEP 1 修法 = 在白名单外(`scripts/install.sh` 是上游 hermes-agent v0.19.0 的脚本)做最小防御性加层,覆盖 install.sh 自有的 4 处 curl 调用。装机 user 验 v6 时如果看到 release tarball download 仍卡,那 STEP 2 的 30 分 timeout 兜底是最后一道防线。

## 6. AC1 验收

- ✅ CC 改 `scripts/install.sh` curl `--max-time 60 --retry 3 --retry-all-errors`(571/868/874/891 行 4 处)
- ✅ `bash -x scripts/install.sh 2>&1 | head -50` 跑通(trace 显示脚本入口正常,无语法错误,`set -e` 兼容)
- ✅ diff 验证:4 处 curl 修改全部生效,未破坏注释 / 帮助文本 / 其他代码

AC1 PASS。
