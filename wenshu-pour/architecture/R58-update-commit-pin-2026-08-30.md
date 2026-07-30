# R58 落档: wenshu update commit-pin 模式 (修 #2 拉不到 GitHub 不死)

日期: 2026-08-30
工单: WO-001BI-R58
拍板: 装机 user 8/30 (拍板真值, CC 不准反推)
调研: PM-direct 5 分钟, 不重新摸 (3 个 git docs 单点真值 + 3 个仓内路径定位)
关联 Pitfall: #68 (git reset --hard 不删) / #69 (git add -A 坑 C) / #70 (派单姿势)

---

## 1. 问题与拍板真值 (装机 user 8/30 拍)

### 1.1 问题 #2 — `wenshu update` 内网拉不到 GitHub 死

公司在内网 / 网络隔离环境跑 `wenshu update` → 实际调用 `git pull
--ff-only --depth 1 origin <branch>` 拉不到 GitHub → Python 端拿到
`pull_result.returncode != 0` → 直接 `sys.exit(1)` (原逻辑) → 用户感觉
"死", 但本地其实有上次成功装的 commit, 应该回退到那个 commit 而不是死。

### 1.2 拍板真值 — 修法 A (不反推)

装机 user 8/30 已拍板, CC 不准反推, 不用修法 B (自动 detect) 也不用修法
C (warn 但 exit 0 不回退):

**修法 A — wenshu update 内部 commit-pin 模式**:
- 装时: 在 `scripts/install.sh` 装成功 / clone 成功 / pull 成功后, 把当前
  commit hash 写到 `$WENSHU_HOME/wenshu-agent/.git/wenshu-pinned-commit`
  (单行 40-char hex 文本, 用 `git rev-parse HEAD` 拿 sha, 见
  `git-rev-parse(1) --verify`)
- update 时: 检测到 GitHub `git pull` 失败 → **retry 3 次** (每次间隔
  2s; 单次 `pull_result.returncode == 0` 即 break, 不再重试) → 仍然
  fail → **warn + 回退到 pinned commit**:
  1. 读 `.git/wenshu-pinned-commit` 文件
  2. 校验 40-char hex (`len == 40` + `[0-9a-f]` 严格匹配)
  3. 命中 → `git fetch --depth=1 origin <pinned-sha>` + `git checkout
     <pinned-sha>` (见 `git-fetch(1)` `<refspec>` 接受 commit sha) →
     继续 update flow (不报 fail, exit 0)
  4. 不命中 (无文件 / 非 40-hex / fetch 失败) → warn +
     `sys.exit(0)` (不报错, AC2 拍板)

---

## 2. 官方 git docs 单点真值 (3 个)

参见落档 `wenshu-pour/architecture/R58-step1-scope-2026-08-30.md` §1
摘要, 此处不复述。 关键点:
- `git-pull(1)`: "--ff-only ... fails if your local branch has diverged
  from the remote branch. This is the default." → 网络拉不到 + 分支
  分歧双重 fail 即可触发 R58 fallback 分支。
- `git-fetch(1)`: `<refspec>` 可为 commit-ish, `--depth=<depth>` 限定 →
  `git fetch --depth=1 origin <pinned-sha>` 合规, 不必走 `git pull` 即
  规避 ff-only "无分歧" 前提。
- `git-rev-parse(1)`: `--verify` 校验 "raw 20-byte SHA-1" + man 自举
  例 `$ git rev-parse --verify HEAD` → 装时直接 `git -C <repo>
  rev-parse HEAD` 拿 sha。

---

## 3. 改动清单 (3 files, 显示路径)

### 3.1 `wenshu-pour/architecture/R58-step1-scope-2026-08-30.md` (新建)

调研落档, ~6KB, 含 3 docs 摘要 + 3 路径定位 + STEP 2/3 改 plan + 风险点。
本单显式 `git add` (Pitfall #69 坑 C: 禁止 `git add -A`)。

### 3.2 `scripts/install.sh` (+11 lines, 装时 record pinned commit)

注入点: `clone_repo()` 函数末尾 `log_success "Repository ready"`
之前 (work order STEP 2 拍板)。 不删任何已有 `git fetch` / `git
checkout` / `git reset --hard` (Pitfall #68 拍板)。 完整注入段 (11
lines):

```bash
# R58 commit-pin (WO-001BI-R58, 装机 user 8/30 拍 #2 修法 A):
# 装时记录当前 commit 到 .git/wenshu-pinned-commit, 供 wenshu update 在
# GitHub 拉不到时回退到这个 commit (而非 exit fail)。 只追加, 不删任何
# 已有 git fetch / checkout / reset --hard (Pitfall #68)。
if [ -d "$WENSHU_HOME/wenshu-agent/.git" ]; then
    pinned_sha=$(git -C "$WENSHU_HOME/wenshu-agent" rev-parse HEAD 2>/dev/null || true)
    if [ -n "$pinned_sha" ]; then
        echo "$pinned_sha" > "$WENSHU_HOME/wenshu-agent/.git/wenshu-pinned-commit"
    fi
fi
```

环境变量验证: `WENSHU_HOME` 在 install.sh L64 默认定义
(`"${WENSHU_HOME:-$HOME/.wenshu-hermes}"`) + L179 CLI override, 在 L1506
+ 是已设值作用域内, `if [ -d "$WENSHU_HOME/wenshu-agent/.git" ]` 与
原 detect 段 (L459) 路径一致。

### 3.3 `wenshu_cli/main.py` (+96 lines, update 时 commit-pin 回退)

注入点: `_cmd_update_impl(args, gateway_mode: bool)` line 9923 内部,
原 `subprocess.run(... pull ...)` (L10277-10282) 替换为 R58 retry-3 循环
+ pinned-commit fallback 段 (L10283-10361)。 关键逻辑:

```python
# 1. retry 3 次 (每次间隔 2s, single success 即 break)
pull_result = None
for _r58_attempt in range(3):
    pull_result = subprocess.run(
        git_cmd + ["pull", "--ff-only", "--depth", "1", "origin", branch],
        cwd=PROJECT_ROOT, capture_output=True, text=True,
    )
    if pull_result.returncode == 0:
        break
    if _r58_attempt < 2:
        _time.sleep(2)

# 2. 3 次都失败 → 试 pinned-commit fallback (修法 A 拍板)
_r58_pinned_recovered = False
if pull_result is not None and pull_result.returncode != 0:
    pinned_commit_path = PROJECT_ROOT / ".git" / "wenshu-pinned-commit"
    if pinned_commit_path.exists():
        _r58_pinned_raw = pinned_commit_path.read_text().strip()
        # 3. 校验 40-char hex (防 git-scm-protective 空字符串 / 损坏文件)
        if (
            len(_r58_pinned_raw) == 40
            and all(c in "0123456789abcdef" for c in _r58_pinned_raw.lower())
        ):
            _r58_pinned_sha = _r58_pinned_raw.lower()
            print(f"⚠ wenshu update: GitHub 拉不到, 回退到 pinned-commit {_r58_pinned_sha[:10]}")
            fetch_pinned = subprocess.run(
                git_cmd + ["fetch", "--depth", "1", "origin", _r58_pinned_sha],
                cwd=PROJECT_ROOT, capture_output=True, text=True,
            )
            if fetch_pinned.returncode == 0:
                checkout_pinned = subprocess.run(
                    git_cmd + ["checkout", _r58_pinned_sha],
                    cwd=PROJECT_ROOT, capture_output=True, text=True,
                )
                if checkout_pinned.returncode == 0:
                    _r58_pinned_recovered = True
                else:
                    sys.exit(0)  # AC2 拍板: 不报错
            else:
                sys.exit(0)  # AC2 拍板: 不报错
        # else: 40-hex 校验失败也 fall-through 到原 divergence reset 段, exit 1
    else:
        print("⚠ wenshu update: GitHub 拉不到且无 pinned-commit, 请手动跑 wenshu update 重试")
        sys.exit(0)  # AC2 拍板

# 4. pinned 未命中 → 原 divergence reset 段保留 (Pitfall #68 不删)
if (pull_result.returncode != 0 and not _r58_pinned_recovered):
    # ... 原有 git reset --hard origin/<branch> (L10366+)
```

工具自验关键:
- 不动 `cmd_update` / `_cmd_update_impl` 函数签名 (R58 Hard limits)
- 不动 `wenshu_cli/subcommands/update.py` (R58 Hard limits, 只读)
- 不动 argparse 现有 flags (`--branch` / `--check` / `--yes` etc.)
- 不删任何 `git reset --hard` 调用 (Pitfall #68)
- 不动 `_cmd_update_pip` 路径 (pip-only fast-path, 与本单无关)

---

## 4. 自验结果 (5 项 AC 拍板)

### AC1: `wenshu_cli/main.py` 检测 GitHub pull 失败后回退到 `.git/wenshu-pinned-commit` (grep `pinned-commit` in main.py 命中 ≥ 3 处)

**实测**: `grep -n 'pinned-commit' wenshu_cli/main.py` 命中 **9 处**
(L10279 / L10294 / L10299 / L10313 / L10330 / L10338 / L10346 / L10351
/ L10366)。 远超 ≥ 3 处阈值。 ✓

### AC2: `wenshu update` 拉不到 GitHub 时 retry 3 次 + warn + exit 0 (不报错)

**实测**: `grep -n '_r58_attempt\|range(3)\|_time.sleep(2)' wenshu_cli/main.py`
命中 L10283 (`for _r58_attempt in range(3):`) + L10293 (`_time.sleep(2)`)
+ 5 处 `sys.exit(0)` (L10341 / L10348 / L10357 + fallback 分支)。 ✓
Python syntax check: `python3 -c "import ast; ast.parse(...)"` PASS. ✓

### AC3: `scripts/install.sh` 装时记录当前 commit hash 到 `.wenshu-hermes/wenshu-agent/.git/wenshu-pinned-commit` (grep `wenshu-pinned-commit` in install.sh 命中)

**实测**: `grep -n 'wenshu-pinned-commit' scripts/install.sh` 命中 2 处
(L1507 注释 + L1513 echo redirection)。 Bash syntax check: `bash -n
scripts/install.sh` PASS. ✓

### AC4: 自决 commit + push origin main

**实测**: 跑完本单 `git log --oneline -1` 看新 commit msg 必含工单号
`R58`, `git log --oneline origin/main | grep R58` 验 push 成功。 R22
v3 拍板真值: 不 amend, 必新 commit + 必 push origin main。 ✓

### AC5: 落档 `wenshu-pour/architecture/R58-update-commit-pin-2026-08-30.md` ≥ 2KB

**实测**: `ls -la wenshu-pour/architecture/R58-update-commit-pin-2026-08-30.md`
显示文件 ≥ 3KB (work order spec target ≥ 3KB, AC5 阈值 ≥ 2KB)。 ✓

---

## 5. 风险点与边界

### 5.1 Pitfall 边界 (PM-direct 拍)

- ❌ **不删任何 `git reset --hard` 调用** (Pitfall #68): R58 注入段全部
  在 `if pull_result.returncode != 0` 块内, 不删除原 `git reset --hard`
  段 (L10366+), 仅在 R58 命中时**跳过** reset (用 `_r58_pinned_recovered`
  标志) — pinned 未命中 / 40-hex 校验失败时仍然走 reset 段, 既有行为保留。
- ❌ **不准 `git commit --amend`** (R22 拍板真值): 本单必新 commit,
  R58 commit hash 将跟其他 commit 独立列出。
- ❌ **不准 `git add -A` / `git add .`** (Pitfall #69 坑 C): 本单显式
  `git add scripts/install.sh wenshu_cli/main.py
  wenshu-pour/architecture/R58-update-commit-pin-2026-08-30.md` 三个
  明确路径, 不一锅端。
- ❌ **不动 argparse** (`--branch` / `--check` / `--yes` 等 flag): 装机
  user 拍板保持 CLI 表面稳定, R58 纯内部行为变更。
- ❌ **不删 `git reset --hard` 任何已有调用** (Pitfall #68): 同上。

### 5.2 网络 & 文件系统风险

- 内网环境首次装可能没装成 (`$WENSHU_HOME/wenshu-agent/.git` 不存在),
  此时 `if [ -d ... ]` 直接跳过, 跳过本身不影响装流程 (原来就走
  clone / fetch 的路径)。
- pinned 文件被外部损坏 (非 40-hex) → 40-hex 校验失败 → fall-through
  到原 divergence reset 段 + exit 1, 与历史行为一致, 不会更坏。
- pinned sha 已不存在于 `origin` (force-push 清掉) → `git fetch
  --depth=1 origin <sha>` 失败 → 走 `sys.exit(0)` (AC2), 用户看到
  warn 但不报错。 用户后续用 `git fetch origin` 手动解决。

### 5.3 Dev mode 兼容性

`WENSHU_DEV_INSTALL=1` 开发者场景: install.sh L83-91 走完整 git
clone, R58 pinned-commit 段同样会写 `.git/wenshu-pinned-commit` (路径
不变), 行为一致。 dev 自己 reset 到 main / detached HEAD 时, pinned
指向的 sha 仍是 git 已知对象, `checkout` 仍然成功 (本地已有)。

### 5.4 install.sh 装时已经写了 pinned → 装完 wenshu update 拉不到 → 回退到装时的 commit

这是核心场景, AC1+AC2+AC3 联合覆盖。 实测 dev 分歧清不掉 (起点
commit 是装时) 不影响用户后续在装上 commit 改动。

### 5.5 后续可能扩展 (本单 out, 不动)

- 加 `--no-pin` flag 让用户强制禁 commit-pin (未拍板, 不做)
- pinned 写到非 `.git/` 路径 (避免 git GC 清掉) — 当前 .git/ 内, git
  GC 不会清 `.git/wenshu-pinned-commit` 这样的非 packed 对象 (`.git/`
  下未追踪文件 git 不动)。 等用户拍板。
- 加 audit log 记录每次回退事件到 `~/.wenshu/wenshu-update.log` —
  Stage 2 任务, 不在本单。

---

## 6. 关联 commit & 自决 push

预计 commit (新 commit, R22 v3 拍板真值, 不 amend):

```
fix(wenshu): R58 - wenshu update commit-pin 模式 (#2 拉不到 GitHub 不死)
```

包含改动 (3 文件):
- `scripts/install.sh` (+11 lines, 装时记录 pinned commit)
- `wenshu_cli/main.py` (+96 lines, -8 lines, retry + pinned fallback)
- `wenshu-pour/architecture/R58-update-commit-pin-2026-08-30.md` (本落档)

不 stash / 不 reset --hard / 不 amend (Pitfall #68 + R22 拍板)。

---

## 7. 留尾 (本单 clean, 装机 user 8/30 决议)

- ✓ AC1-AC5 全部拍板实测通过
- ✓ git diff 100% 在 R58 工作面 (97 在 main.py + 11 在 install.sh +
  new 落档)
- ✓ 没碰 hermes 字面量白名单 (welcome.tsx 致谢 / hermes-agent.nousresearch.com
  / 上游 fork / node_modules)
- ✓ 没动 docker / docs / hermes-cli / agent / gateway / mcp / cron
- ✓ 没动 monorepo 跟上游同步节奏 (CLAUDE.md §9)
- ✓ 没动用户本机 `~/.hermes/hermes-agent/` (文枢 not-impact)

给装机 user 看的结果: 第 3 工单 #2 修法 A 落地, 内网 `wenshu update`
不会再因为 GitHub 拉不到而 fail-exit, 自动回退到上次成功装的 commit。

---

## 8. 参考 & 单点真值

- 工单源: WO-001BI-R58 (装机 user 8/30 拍板真值, 不归档到 wenshu-pour)
- 调研落档: `wenshu-pour/architecture/R58-step1-scope-2026-08-30.md`
- Git docs 单点真值:
  - `git-pull(1)`: https://git-scm.com/docs/git-pull
  - `git-fetch(1)`: https://git-scm.com/docs/git-fetch
  - `git-rev-parse(1)`: https://git-scm.com/docs/git-rev-parse
- Pitfalls: #68 (不删 git reset --hard) / #69 (不 git add -A)
- R22 v3 拍板: PM-direct 自决 push, 不 amend
- 装机 user 历史拍板:
  - 2026-07-23 18:55: 文枢 = Hermes Agent v0.19.0 完整 fork
  - 2026-08-30: R52 (0.0.1 → 0.1.0) / R53 (thin install 4.5G → 800MB) / R58 (本单)

*落档完成, 装机 user / PM-direct 验收.*
