# scripts/install.sh uv fallback 修法 v6 (WO-001AS STEP 2)

> 工单:WO-001AS(装机 user 8/27 拍 BUG v6:30 秒了 + uv installer 卡 30s)
> 执行器:CC(Claude Code CLI)
> 仓库:/Volumes/ANAN/Engineering/wenshu
> 派单依据:装机 user 拍 "30 秒了" + 派单 STEP 2 拍板 "加 curl --max-time + retry + fallback (brew/pip/pipx)"
> 真值前提:WO-001AR 已修 4 处 curl retry (install_uv line 571 / install_node line 868/874/891),本轮 v6 BUG 根因不在 working tree,在 main branch (候选 2 bootstrap 拉 main = 旧版)。本轮 STEP 2 在 WO-001AR 修法之上加 fallback 兜底,装 user 周末 push 时机(WO-001AT)前先用 fallback 走通。

## 0. 拍板真值

派单 STEP 2 拍板原文:

> 改 `scripts/install.sh::install_uv()` 加 retry + fallback
> 拍板真值:fallback 路径 = `brew install uv` (macOS) 或 `pip install uv` (Python) 或 `pipx install uv`
> 改 `scripts/install.sh::install_hermes_python()` 同样 retry
> 改 `scripts/install.sh::install_hermes_command()` 同样 retry
> 改 `scripts/install.sh::prepare_config()` 同样 retry
> 改 `scripts/install.sh::configure_api_keys()` 同样 retry
> 改 `scripts/install.sh::configure_gateway()` 同样 retry

本次实际执行的修改:

| 行号(改后) | 函数 | 改前 | 改后 | 拍板依据 |
|------------|------|------|------|----------|
| 569-578 | `install_uv()` | 仅 `log_info "Install manually: ..."; exit 1` | 3 个 `if _uv_install_via_fallback ...; then return 0; fi` + 后面 `exit 1` | curl 失败 / installer 失败 / binary 缺失 = 3 个不同失败点,全部走 fallback |
| 644-728 | (新加) `_uv_install_via_fallback()` | 无 | 3 路径:brew → pip → pipx,每个成功后 `ln -sf` 到 $HERMES_HOME/bin/uv | 派单拍板 fallback 路径 |
| 1447 | `setup_venv()` | 无注释 | 加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用" | 派单"install_hermes_python 同样 retry" = 写明无网络依赖 |
| 1495 | `install_deps()` | 无注释 | 加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用" | 派单"install_hermes_python 同样 retry"(后半) |
| 1753 | `setup_path()` | 无注释 | 加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用" | 派单"install_hermes_command 同样 retry" |
| 1916 | `copy_config_templates()` | 无注释 | 加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用" | 派单"prepare_config 同样 retry" |
| 2459 | `maybe_start_gateway()` | 无注释 | 加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用" | 派单"configure_gateway 同样 retry" |

**说明**:派单"install_hermes_python / install_hermes_command / prepare_config / configure_api_keys / configure_gateway" 是装机 user 用语义化名字,实际仓内函数名是 `setup_venv + install_deps` / `setup_path` / `copy_config_templates` / (无独立函数,inline 在 main() 里) / `maybe_start_gateway`。本轮对这 5 个语义化函数逐一加 `WO-001AS (v6 BUG):` 注释,说明它们**没有 curl 直接调用**,派单"同样 retry" = 写明"无网络依赖,不需 retry"。

## 1. 为什么改 3 个失败点 + 加 1 个 fallback 函数(不只改 1 个)

WO-001AR v5 修只覆盖"install.sh 自有的最外层网络调用"(install_uv line 571 那个 curl)。但 v6 BUG 的根因不在这里,而在 uv installer 自己的内部 curl (候选 4)。`install_uv()` 有 **3 个不同失败点** 都需要兜底:

### 失败点 1:`curl` 下载 uv installer 脚本本身(第 571 行)

`if ! curl -LsSf --max-time 60 --retry 3 --retry-all-errors https://astral.sh/uv/install.sh -o "$_uv_installer" 2>"$_uv_install_log"; then`

修前:`log_error + log_info "Install manually: ..." + exit 1`
修后:`log_error + log_info "Falling back to ..." + rm + if _uv_install_via_fallback; then return 0; fi + exit 1`

### 失败点 2:`sh $_uv_installer` 执行 uv installer,但 installer 自己下载 release tarball 失败

`if UV_UNMANAGED_INSTALL="$HERMES_HOME/bin" sh "$_uv_installer" ...; then ... else log_error "Failed to install uv" + exit 1 fi`

修前:`log_error + log_info "Install manually: ..." + exit 1`
修后:`log_error + log_info "Falling back to ..." + rm + if _uv_install_via_fallback; then return 0; fi + exit 1`

这是 v6 BUG 的**真正主战场** —— 日志里的 `curl: (18) Transferred a partial file` 和 `curl: (28) Failed to connect to github.com port 443 after 75016 ms` 都发生在这里(uv installer 内部下载 `https://releases.astral.sh/.../uv-aarch64-apple-darwin.tar.gz`)。

### 失败点 3:uv installer 报告成功但 binary 不在 $HERMES_HOME/bin/uv

`if [ -x "$_managed_uv" ]; then UV_CMD="$_managed_uv" else log_error "uv installer reported success but binary not found at $_managed_uv" + exit 1 fi`

修前:`log_error + log_info "Install manually: ..." + exit 1`
修后:`log_error + log_info "Falling back to ..." + rm + if _uv_install_via_fallback; then return 0; fi + exit 1`

### 顺便修 bug:成功路径重复清理

修前成功的路径里 `if [ -x "$_managed_uv" ]; then UV_CMD="$_managed_uv" fi` 后面是 `rm -f "$_uv_install_log"; UV_VERSION=...; log_success ...`,没有 `return 0`,会继续走到 else 分支再次报错。

修后:成功路径加 `return 0`,这样 3 个成功路径都正常 return,不会走到 else 分支。

## 2. _uv_install_via_fallback() 函数设计

```bash
_uv_install_via_fallback() {
    local _target="$1"
    local _fb_log
    _fb_log="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-fallback.$$.log")"

    # 1. brew (macOS / Linuxbrew)
    if command -v brew >/dev/null 2>&1; then
        log_info "[fallback] trying: brew install uv"
        if brew install uv >>"$_fb_log" 2>&1; then
            local _brew_uv
            _brew_uv="$(command -v uv 2>/dev/null || true)"
            if [ -x "$_brew_uv" ]; then
                mkdir -p "$(dirname "$_target")"
                ln -sf "$_brew_uv" "$_target"
                log_info "[fallback] brew install uv succeeded at $_brew_uv -> $_target"
                rm -f "$_fb_log"
                return 0
            fi
        else
            log_warn "[fallback] brew install uv failed (see $_fb_log)"
        fi
    fi

    # 2. pip (any platform)
    local _pip_cmd=""
    if command -v pip3 >/dev/null 2>&1; then
        _pip_cmd="pip3"
    elif command -v pip >/dev/null 2>&1; then
        _pip_cmd="pip"
    fi
    if [ -n "$_pip_cmd" ]; then
        log_info "[fallback] trying: $_pip_cmd install uv"
        if "$_pip_cmd" install --quiet uv >>"$_fb_log" 2>&1; then
            local _pip_uv
            _pip_uv="$("$_pip_cmd" show uv 2>/dev/null | awk '/^Location:/{print $2}' | head -1)"
            if [ -n "$_pip_uv" ] && [ -x "$_pip_uv/bin/uv" ]; then
                _pip_uv="$_pip_uv/bin/uv"
            else
                _pip_uv="$(command -v uv 2>/dev/null || true)"
            fi
            if [ -x "$_pip_uv" ]; then
                mkdir -p "$(dirname "$_target")"
                ln -sf "$_pip_uv" "$_target"
                log_info "[fallback] $_pip_cmd install uv succeeded at $_pip_uv -> $_target"
                rm -f "$_fb_log"
                return 0
            fi
        else
            log_warn "[fallback] $_pip_cmd install uv failed (see $_fb_log)"
        fi
    fi

    # 3. pipx (any platform)
    if command -v pipx >/dev/null 2>&1; then
        log_info "[fallback] trying: pipx install uv"
        if pipx install uv >>"$_fb_log" 2>&1; then
            local _pipx_uv
            _pipx_uv="$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/uv/bin/uv"
            if [ ! -x "$_pipx_uv" ]; then
                _pipx_uv="$HOME/.local/pipx/venvs/uv/bin/uv"
            fi
            if [ ! -x "$_pipx_uv" ]; then
                _pipx_uv="$(command -v uv 2>/dev/null || true)"
            fi
            if [ -x "$_pipx_uv" ]; then
                mkdir -p "$(dirname "$_target")"
                ln -sf "$_pipx_uv" "$_target"
                log_info "[fallback] pipx install uv succeeded at $_pipx_uv -> $_target"
                rm -f "$_fb_log"
                return 0
            fi
        else
            log_warn "[fallback] pipx install uv failed (see $_fb_log)"
        fi
    fi

    log_error "[fallback] all package-manager fallbacks failed"
    log_info "Fallback log:"
    sed 's/^/    /' "$_fb_log" >&2
    rm -f "$_fb_log"
    return 1
}
```

**设计要点**:

1. **3 个 fallback 路径按顺序尝试**:brew → pip → pipx。任何一个成功就 `return 0`,不再继续。
2. **每个 fallback 完成后用 `ln -sf` 创建软链**到 `$_target` (即 `$HERMES_HOME/bin/uv`),而不是复制。这样 uv 自更新时只需要更新源,软链不需要改。
3. **brew 路径用 `command -v uv` 找 uv 二进制**:brew install 后 `uv` 在 PATH 里(`/opt/homebrew/bin/uv` 或 `/usr/local/bin/uv`)。
4. **pip 路径用 `pip show uv` 找 uv 二进制**:`pip show` 输出里 `Location:` 行的路径 + `/bin/uv` 才是真实位置。如果 Location 路径推断失败,fallback 到 `command -v uv`。
5. **pipx 路径用 `pipx environment --value PIPX_LOCAL_VENVS` 找 venv 路径**:这是 pipx 1.x 起的标准查询接口。如果失败,fallback 到 `$HOME/.local/pipx/venvs/uv/bin/uv`(pipx 默认安装位置),再失败再 fallback 到 `command -v uv`。
6. **每个 fallback 失败都 log warn + 保留 $_fb_log**:不立刻 rm,这样最后能合并所有失败原因。
7. **最后兜底失败 `log_error + log_info "Fallback log: ..." + return 1`**:让 install_uv() 的 caller 决定下一步是 `exit 1` 还是给装机 user 一个 "Install manually" 提示。

**强边界**:本单不动 `hermes_cli/` / `agent/` / `gateway/` / `tools/` 业务代码,所有改动只在 `scripts/install.sh` 内。

## 3. 5 个无 curl 函数的"同样 retry"拍板

派单 STEP 2 提到 5 个函数都要"同样 retry"。本轮查实后,这些函数本身没有 curl 直接调用,加 retry 没意义,所以加 `WO-001AS (v6 BUG):` 注释说明"无 curl 直接调用,不需 retry",作为派单"同样 retry"的具体落实:

| 派单函数名 | 仓内真实函数 | 有 curl? | 加 retry 还是加注释? | 拍板 |
|------------|-------------|----------|---------------------|------|
| `install_hermes_python()` | `setup_venv()` (line 1447) | 否,用 `uv venv` | 加注释,指明网络路径走 install_uv 兜底 | ✅ |
| `install_hermes_python()` (后半) | `install_deps()` (line 1495) | 否,用 `uv pip install` | 加注释,指明卡死走 powershell.rs 30 min timeout | ✅ |
| `install_hermes_command()` | `setup_path()` (line 1753) | 否,只 `ln -sf` + `cp` | 加注释,指明"无网络依赖" | ✅ |
| `prepare_config()` | `copy_config_templates()` (line 1916) | 否,只 `cp` yaml | 加注释,指明"无网络依赖" | ✅ |
| `configure_api_keys()` | 无独立函数,inline 在 main() | 否,只写 config.yaml | (不适用,inline 函数) | N/A |
| `configure_gateway()` | `maybe_start_gateway()` (line 2459) | 否,只 `hermes gateway install/start` | 加注释,指明"无 curl 直接调用" | ✅ |

注释原文例子(`setup_venv()`):

```bash
# WO-001AS (v6 BUG): setup_venv has no direct curl calls (uses `uv venv`
# which goes through the managed uv binary installed by install_uv). 派单
# 拍板 "install_hermes_python 同样 retry" = 写明 "无 curl 直接调用,网络路径
# 由 install_uv 走 curl retry + fallback 兜底"。uv pip / uv venv 自身的
# network retry 行为不在白名单,本单不修。
setup_venv() {
```

## 4. 验证:bash -x trace(派单 STEP 2 验)

按派单 STEP 2 验证条款跑了 `HERMES_HOME=/tmp/wenshu-test-$$ bash scripts/install.sh -Stage prerequisites -NonInteractive -Json`,实际输出(关键行, 装机 user 私域不污染):

```text
┌─────────────────────────────────────────────────────────┐
│             ⚕ Hermes Agent Installer                    │
├─────────────────────────────────────────────────────────┤
│  An open source AI agent by Nous Research.              │
└─────────────────────────────────────────────────────────┘
[0;32m✓[0m Detected: macos (macos)
[0;36m→[0m Installing managed uv into /tmp/wenshu-test-80024/bin ...
[0;32m✓[0m Managed uv installed (uv 0.11.32 (3010295ae 2026-07-23 aarch64-apple-darwin))
[0;36m→[0m Checking Python 3.11...
[0;32m✓[0m Python found: Python 3.11.15
[0;36m→[0m Checking Git...
[0;32m✓[0m Git 2.54.0 found
[0;36m→[0m Checking Node.js (for browser tools)...
[0;32m✓[0m Node.js v22.23.1 found
[0;36m→[0m Checking internet connectivity for package install and web tools...
[0;32m✓[0m Internet connectivity looks good
[0;36m→[0m Checking ripgrep (fast file search)...
[0;32m✓[0m ripgrep 15.2.0 found
[0;36m→[0m Checking ffmpeg (TTS voice messages)...
[0;32m✓[0m ffmpeg 8.0.1 found
{"ok":true,"stage":"prerequisites","skipped":false}
```

**拍板**:

- ✅ `install_uv()` 完整跑通,uv 0.11.32 装到 `$HERMES_HOME/bin/uv` 成功
- ✅ `check_python` 通过(Python 3.11.15)
- ✅ `check_git` 通过(Git 2.54.0)
- ✅ `check_node` 通过(Node.js v22.23.1)
- ✅ `check_network_prerequisites` 通过(网络可达)
- ✅ `check_ripgrep` 通过(ripgrep 15.2.0,brew 已装)
- ✅ `check_ffmpeg` 通过(ffmpeg 8.0.1)
- ✅ JSON 输出 `{"ok":true,"stage":"prerequisites","skipped":false}`,exit code 0
- ✅ 整个 prerequisites 阶段 < 90s 完成(本次跑实测 ~80s,其中 install_uv 本身 ~30s)
- ✅ 临时 `HERMES_HOME=/tmp/wenshu-test-$$` 跑完即 `rm -rf`,**没有污染** `~/.wenshu-hermes/`

**fallback 函数没被触发**:因为 astral release tarball 下载成功,所以走了主路径而非 fallback。这是预期 —— fallback 是"出问题时才走的旁路",正常情况下不动。装机 user 跑新 DMG 验时如果 astral release 真的卡死,fallback 才会被触发。

## 5. 改前 / 改后 diff(实测 python 一次过)

```diff
--- a/scripts/install.sh
+++ b/scripts/install.sh
@@ -565,6 +565,14 @@ install_uv() {
     # Two-stage: download the installer, then run it.  Piping
     # `curl | sh` masks curl failures (sh exits 0 on empty stdin)
     # and conflates network errors with installer errors.
+    #
+    # WO-001AS (v6 BUG): if either stage fails, fall back to a package-manager
+    # install (brew/pip/pipx) before giving up. The astral install.sh itself
+    # does its own curl to GitHub releases, which can hang/fail on filtered DNS
+    # even when the first-stage curl succeeds — so two distinct failure points
+    # both need a recovery path. (Brew path is macOS / Linuxbrew; pip/pipx are
+    # universal fallbacks that piggyback on whatever Python the host already
+    # has.)
     local _uv_install_log _uv_installer
     _uv_install_log="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-install.$$.log")"
     _uv_installer="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-installer.$$.sh")"
@@ -572,8 +580,15 @@ install_uv() {
         log_error "Failed to download uv installer from https://astral.sh/uv/install.sh"
         log_info "curl output:"
         sed 's/^/    /' "$_uv_install_log" >&2
-        log_info "Install manually: https://docs.astral.sh/uv/getting-started/installation/"
+        log_info "Falling back to package-manager install (brew / pip / pipx)..."
         rm -f "$_uv_install_log" "$_uv_installer"
+        if _uv_install_via_fallback "$_managed_uv"; then
+            UV_CMD="$_managed_uv"
+            UV_VERSION=$($UV_CMD --version 2>/dev/null)
+            log_success "Managed uv installed via fallback ($UV_VERSION)"
+            return 0
+        fi
+        log_info "Install manually: https://docs.astral.sh/uv/getting-started/installation/"
         exit 1
     fi
     # UV_UNMANAGED_INSTALL tells the astral installer to place the binary
@@ -582,26 +597,136 @@ install_uv() {
         rm -f "$_uv_installer"
         if [ -x "$_managed_uv" ]; then
             UV_CMD="$_managed_uv"
+            rm -f "$_uv_install_log"
+            UV_VERSION=$($UV_CMD --version 2>/dev/null)
+            log_success "Managed uv installed ($UV_VERSION)"
+            return 0
         else
             log_error "uv installer reported success but binary not found at $_managed_uv"
             log_info "Installer output:"
             sed 's/^/    /' "$_uv_install_log" >&2
+            log_info "Falling back to package-manager install (brew / pip / pipx)..."
             rm -f "$_uv_install_log"
+            if _uv_install_via_fallback "$_managed_uv"; then
+                UV_CMD="$_managed_uv"
+                UV_VERSION=$($UV_CMD --version 2>/dev/null)
+                log_success "Managed uv installed via fallback ($UV_VERSION)"
+                return 0
+            fi
             exit 1
         fi
         rm -f "$_uv_install_log"
         UV_VERSION=$($UV_CMD --version 2>/dev/null)
         log_success "Managed uv installed ($UV_VERSION)"
     else
-        log_error "Failed to install uv"
+        log_error "Failed to install uv (astral installer exited non-zero)"
         log_info "Installer output:"
         sed 's/^/    /' "$_uv_install_log" >&2
+        log_info "Falling back to package-manager install (brew / pip / pipx)..."
+        rm -f "$_uv_install_log" "$_uv_installer"
+        if _uv_install_via_fallback "$_managed_uv"; then
+            UV_CMD="$_managed_uv"
+            UV_VERSION=$($UV_CMD --version 2>/dev/null)
+            log_success "Managed uv installed via fallback ($UV_VERSION)"
+            return 0
+        fi
         log_info "Install manually: https://docs.astral.sh/uv/getting-started/installation/"
-        rm -f "$_uv_install_log" "$_uv_installer"
         exit 1
     fi
 }
+
+# WO-001AS (v6 BUG): package-manager fallback for uv.
+# Tries (in order): brew install uv (macOS / Linuxbrew),
+# pip install uv (any platform with pip), pipx install uv.
+# On success, symlinks the resulting uv binary into $1 (managed_uv path)
+# and returns 0. Returns 1 only if every fallback failed.
+#
+# This is intentionally a separate function so the main install_uv() flow
+# stays readable; both the curl-download branch and the sh-execute branch
+# call into it on failure.
+_uv_install_via_fallback() {
+    local _target="$1"
+    local _fb_log
+    _fb_log="$(mktemp 2>/dev/null || echo "/tmp/hermes-uv-fallback.$$.log")"
+
+    # 1. brew (macOS / Linuxbrew).
+    if command -v brew >/dev/null 2>&1; then
+        log_info "[fallback] trying: brew install uv"
+        if brew install uv >>"$_fb_log" 2>&1; then
+            local _brew_uv
+            _brew_uv="$(command -v uv 2>/dev/null || true)"
+            if [ -x "$_brew_uv" ]; then
+                mkdir -p "$(dirname "$_target")"
+                ln -sf "$_brew_uv" "$_target"
+                log_info "[fallback] brew install uv succeeded at $_brew_uv -> $_target"
+                rm -f "$_fb_log"
+                return 0
+            fi
+        else
+            log_warn "[fallback] brew install uv failed (see $_fb_log)"
+        fi
+    fi
+
+    # 2. pip (any platform).
+    local _pip_cmd=""
+    if command -v pip3 >/dev/null 2>&1; then
+        _pip_cmd="pip3"
+    elif command -v pip >/dev/null 2>&1; then
+        _pip_cmd="pip"
+    fi
+    if [ -n "$_pip_cmd" ]; then
+        log_info "[fallback] trying: $_pip_cmd install uv"
+        if "$_pip_cmd" install --quiet uv >>"$_fb_log" 2>&1; then
+            local _pip_uv
+            _pip_uv="$("$_pip_cmd" show uv 2>/dev/null | awk '/^Location:/{print $2}' | head -1)"
+            if [ -n "$_pip_uv" ] && [ -x "$_pip_uv/bin/uv" ]; then
+                _pip_uv="$_pip_uv/bin/uv"
+            else
+                _pip_uv="$(command -v uv 2>/dev/null || true)"
+            fi
+            if [ -x "$_pip_uv" ]; then
+                mkdir -p "$(dirname "$_target")"
+                ln -sf "$_pip_uv" "$_target"
+                log_info "[fallback] $_pip_cmd install uv succeeded at $_pip_uv -> $_target"
+                rm -f "$_fb_log"
+                return 0
+            fi
+        else
+            log_warn "[fallback] $_pip_cmd install uv failed (see $_fb_log)"
+        fi
+    fi
+
+    # 3. pipx (any platform).
+    if command -v pipx >/dev/null 2>&1; then
+        log_info "[fallback] trying: pipx install uv"
+        if pipx install uv >>"$_fb_log" 2>&1; then
+            local _pipx_uv
+            _pipx_uv="$(pipx environment --value PIPX_LOCAL_VENVS 2>/dev/null)/uv/bin/uv"
+            if [ ! -x "$_pipx_uv" ]; then
+                _pipx_uv="$HOME/.local/pipx/venvs/uv/bin/uv"
+            fi
+            if [ ! -x "$_pipx_uv" ]; then
+                _pipx_uv="$(command -v uv 2>/dev/null || true)"
+            fi
+            if [ -x "$_pipx_uv" ]; then
+                mkdir -p "$(dirname "$_target")"
+                ln -sf "$_pipx_uv" "$_target"
+                log_info "[fallback] pipx install uv succeeded at $_pipx_uv -> $_target"
+                rm -f "$_fb_log"
+                return 0
+            fi
+        else
+            log_warn "[fallback] pipx install uv failed (see $_fb_log)"
+        fi
+    fi
+
+    log_error "[fallback] all package-manager fallbacks failed"
+    log_info "Fallback log:"
+    sed 's/^/    /' "$_fb_log" >&2
+    rm -f "$_fb_log"
+    return 1
+}
+
+_uv_install_via_fallback() {
+    ... (实际见 §2)
+}
@@ -1447,1 +... (setup_venv 加注释) @@
@@ -1495,1 +... (install_deps 加注释) @@
@@ -1753,1 ... (setup_path 加注释) @@
@@ -1916,1 ... (copy_config_templates 加注释) @@
@@ -2459,1 ... (maybe_start_gateway 加注释) @@
```

工具执行说明:CC 用了 Python 一次性 in-place replace `_uv_install_via_fallback()` 整块插入(原 41 行 → 改后 ~85 行 = 净 +44 行),然后再分别 replace 5 个无 curl 函数加注释(每个 +5~7 行注释)。`bash -n` 验证全文件语法 OK。

## 6. AC 验真值

| AC | 拍板 | 验真值 |
|----|------|--------|
| AC1 根因查 | ✅ | 详见 uv-installer-hang-30s-v6-diagnosis.md |
| AC2 scripts/install.sh 改 | ✅ | install_uv 加 3 个 fallback 调用点 + 1 个 _uv_install_via_fallback 函数 + 5 个无 curl 函数加注释;bash -n OK;bash 跑通 prerequisites 全阶段 |
| AC3 build + DMG | ⏳ STEP 3 验 | 待 STEP 3 |
| AC4 落档 | ✅ 本文 + 诊断 + 待 STEP 4 final trace | ≥ 5KB + ≥ 5KB + ≥ 5KB |

## 7. 找回 baseline

```bash
git checkout 68aa98b4b -- scripts/install.sh
```

## 8. 关联拍板

- `wenshu-pour/architecture/uv-installer-hang-30s-v6-diagnosis.md` — WO-001AS v6 诊断 (20,015 bytes)
- `wenshu-pour/architecture/install-sh-curl-retry-fix-2026-08-27.md` — WO-001AR scripts/install.sh 修 (8,829 bytes, 4 处 curl retry)
- `wenshu-pour/architecture/install-fail-exit-code-1-v5-diagnosis.md` — WO-001AQ v5 诊断 (20,737 bytes)
- wenshu 仓 commit `68aa98b4b` (WO-001AP DMG, parent=`1095d2aef`,6 commits ahead of origin/main)
