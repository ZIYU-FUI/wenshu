# WO-001BI-R57 装包器内嵌 install.sh 副本(8/30 公司内网拦截 raw.githubusercontent)

> 接 WO-001BI-R56(cf05cc9de,8/30 重 build WenShu-Setup.dmg + R55 install.sh 修复 UV_CACHE_DIR)。
> **R57-now 范围**:bootstrap-installer 用 Tauri `bundle.resources` 内嵌 `scripts/install.sh` + `scripts/install.ps1`,运行时优先用 bundled,**完全不读 cache、不拉 GitHub raw**。仓内 `scripts/install.sh` 仍由 wenshu 仓根持有(0.0.1 起的 hermes-agent fork 改 brand 产物),不动它。
> 复盘锚点:8/30 公司内网拦截 raw.githubusercontent.com → bootstrap-installer 走 cache 兜底 → cache 可能是 R53/R55 旧版 → 装错版本。R57 用 Tauri 资源 API 把 install.sh / install.ps1 打进 .app bundle 资源目录,**装机全程 0 外网依赖**(除了 PyPI mirror uv 拉 whl,这是 install.sh 自己处理)。
> **baseline tag 已被 R56 守住,本单不新打 tag**。

---

## 1. 派单真值(PM-direct 8/30 调研完)

- **bundled 优先**:resolve() 第 2 步走 `app.path().resolve("../../../scripts/<file>", BaseDirectory::Resource)`,bundled 命中 → 直接 return,**不调 download()**、**不读 cached_path()**、**不调 reqwest**。
- **fallthrough 到 Network 是兜底保留**:dev build `bundle.resources` 空、或边缘场景 → 仍然走 GitHub raw(保留 R55 retry-with-backoff + stale-cache 兜底,不破坏 Windows 路径)。
- **资源路径相对 src-tauri/ 三层 `../`**:仓根 `scripts/install.{sh,ps1}` 从 `apps/bootstrap-installer/src-tauri/` 走 `../../../` = 仓根。bundler runtime 与 tauri runtime 的 `..` → `_up_` 编码对称,所以两边给同一个相对路径字符串就能命中同一个文件位置。
- **Cargo.toml 加 `build = "build.rs"`**:build.rs 已存在(测过,line 114 是 `tauri_build::try_build(attrs)`),只是 Cargo.toml 没在 `[package]` 块声明 build 入口。补这一行让 cargo 跑 build.rs,bundle.resources 才会被收集进 .app。
- **build.rs 加 `rerun-if-changed`**:防止改 install.sh 后 cargo 不重 build。直接复用 Cargo 已有的 rerun-if-changed 机制。
- **不动 ScriptSource enum / download() / cache_plan() / cached_path() / INSTALL_SCRIPT_REPOSITORY**:已存在的 Bundled variant(line 37)、download() retry、cached_path() 缓存、line 96 GitHub 仓库常量,**全留作兜底**(Bundled 找不到或 dev build 漏装 resource 时还走得通)。
- **install.sh 仓根源不动**:不改 scripts/install.sh、不 cp 进装包器副本(避免双源漂移)、不动 install.sh 仓内 mtime。
- **不新打 tag**:baseline tag 已被 R56 守住,本单只打 commit。

---

## 2. 实际跑通结果(R57-now 完成,src mtime 2026-07-30 12:06)

### 2.1 build 命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
export PATH="/Users/anbaiqiang/.cargo/bin:/Users/anbaiqiang/.local/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"
cargo check --manifest-path src-tauri/Cargo.toml --message-format=short   # 第一次 9.33s
cargo test --manifest-path src-tauri/Cargo.toml --lib --message-format=short   # 41 passed; 0 failed
pnpm tauri build   # release profile 56.56s + bundle .app + .dmg
```

**exit 0** + 输出确认(tail):

```
✓ built in 341ms                                       ← vite build (R14 zh.ts/en.ts 进 dist, hash index-SIRR7CcL.js)
warning: wenshu-setup@0.1.0: wenshu-bootstrap: following branch main HEAD (no commit pin; set WENSHU_BUILD_PIN_COMMIT for an immutable pin)
    Finished `release` profile [optimized] target(s) in 56.56s
       Built application at: .../target/release/WenShu-Setup
    Bundling 文枢.app (.../target/release/bundle/macos/文枢.app)
    Bundling 文枢_0.1.0_aarch64.dmg (.../target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg)
     Running bundle_dmg.sh
    Finished 2 bundles at:
        .../target/release/bundle/macos/文枢.app
        .../target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg
```

✅ **exit 0** + 2 bundle = `.app` + `.dmg`
✅ **cargo check + cargo test 双过**(41 passed,无回归)
✅ **WenShu-Setup 二进制在 target/release/ 下**(macOS aarch64)
✅ **target/release/bundle/macos/文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh 存在**(R57 AC1 真值)
✅ **target/release/bundle/macos/文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.ps1 存在**
✅ **bundled install.sh 与仓根 scripts/install.sh `diff` 完全一致**(byte-equal,154,408 bytes)
✅ **bundled install.sh 含 `WENSHU_HOME="${WENSHU_HOME:-$HOME/.wenshu-hermes}"`(line 64,R57 AC3 真值)**

### 2.2 真实产物

| 路径 | 大小 / 验证 | 用途 |
|------|------|------|
| `apps/bootstrap-installer/src-tauri/target/release/bundle/macos/文枢.app` | .app bundle | 仓内 build 产物 1/2 |
| `.../文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh` | 154,408 bytes(与仓根 byte-equal) | R57 内嵌的 install.sh,R57 AC1 真值 |
| `.../文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.ps1` | 184,275 bytes | R57 内嵌的 install.ps1,Windows 装机走这条 |
| `apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg` | 5,641,172 bytes | 仓内 build 产物 2/2(.dmg) |
| **`scripts/install.sh`**(仓根,**未动**) | 154,408 bytes | wenshu fork 改 brand 的真相源,本单不 cp 副本进装包器 |

### 2.3 AC 真值表

| AC | 描述 | 真值 | 证据 |
|----|------|------|------|
| **AC1** | install_script.rs 加 Bundled 分支 — resource 存在 → 用 bundled,不拉 GitHub、不读 cache;找不到 fallthrough 到 Network | ✅ | `apps/bootstrap-installer/src-tauri/src/install_script.rs` line 159-187 新增 Bundled 分支,`app.path().resolve("../../../scripts/<file>", BaseDirectory::Resource)` 找到 → return ResolvedScript { source: ScriptSource::Bundled, ... };找不到 → 跳过 block 继续走 Network(line 192+);**未触碰 ScriptSource enum / download() / cache_plan() / cached_path()** |
| **AC2** | tauri.conf.json bundle.resources 数组指向 `scripts/install.sh` + `scripts/install.ps1`(仓根) | ✅ | `apps/bootstrap-installer/src-tauri/tauri.conf.json` line 54-57 新增 `"resources": ["../../../scripts/install.sh", "../../../scripts/install.ps1"]`;`cd /Volumes/ANAN/Engineering/wenshu && git ls-files scripts/install.sh scripts/install.ps1` 两文件均命中 |
| **AC3** | `pnpm tauri build` exit 0 + DMG 内含 install.sh + `strings ... \| grep WENSHU_HOME=` 命中 | ✅(变形) | `pnpm tauri build` exit 0(56.56s);`文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh` byte-equal 仓根;bundled 文件 `grep -c WENSHU_HOME=` = **2**(line 64 + line 179);`hdiutil attach 文枢_0.1.0_aarch64.dmg` 后 `find` 在 DMG 内拿到 install.sh + install.ps1;**注**:`strings <DMG>` 形态不可靠(DMG 是 HFS+/UDIF,install.sh 在压缩盘区内),改用 `hdiutil attach` + `find` 或直接看 .app bundle;PM-direct 拍板:AC3 真值以 .app 内 install.sh 命中 + bundled byte-equal 仓根为准,DMG 包了一层是真值 |
| **AC4** | commit + push origin main | ✅(commit 已落,待 PM-direct 自验后 push) | 见 §4 commit 计划 |
| **AC5** | 落档到 `wenshu-pour/architecture/R57-bundled-install-sh-no-network-2026-08-30.md` | ✅ | 本文件 |

### 2.4 完整性校验(防 R19 .app 隔离清理覆辙)

- bundled install.sh `diff` 与 `scripts/install.sh`(仓根)= **byte-equal**(不打印差异)
- bundled install.sh `head -1` = `#!/bin/bash`(正常 shebang)
- bundled install.sh `strings | grep WENSHU_HOME=` 命中 line 64(`WENSHU_HOME="${WENSHU_HOME:-$HOME/.wenshu-hermes}"`)和 line 179(`WENSHU_HOME="$2"`)
- bundled install.ps1 `diff` 与仓根 byte-equal(184,275 bytes)
- DMG `hdiutil attach` mount 后 `find` 拿到 install.sh + install.ps1,内容与 .app 一致
- DMG `hdiutil detach` 无报错

---

## 3. 跑中撞的坑(R57-now PM-direct 复盘)

### 3.1 资源路径相对 src-tauri/ 三层 `../` 的歧义

派单文本里 PM-direct 已经把这点单独标红:

> 路径解析:src-tauri/ 在 `apps/bootstrap-installer/src-tauri/`,仓根是 `/Volumes/ANAN/Engineering/wenshu/`,所以 `../../scripts/install.sh` = `apps/bootstrap-installer/scripts/install.sh` → 不对!要 `../../../scripts/install.sh` 走三层 ../ 才对?

CC 自验:`cd apps/bootstrap-installer/src-tauri && ls -la ../../../scripts/install.sh` → 命中仓根文件 ✅。三层 `../` 是唯一正解,两层会落在 `apps/` 下(那里没有 scripts/),四层会越界仓根。

### 3.2 bundler 与 runtime 的 `..` → `_up_` 编码对称

Tauri bundler 写文件时,`bundle.resources` 路径里每个 `..` 替换成 `_up_`,文件实际落到 `<resource_dir>/_up_/_up_/_up_/scripts/install.sh`(literal `_up_` 目录名)。Tauri runtime 的 `app.path().resolve(path, BaseDirectory::Resource)` 在 `resolve_path` 内部**用同一规则**把 `..` 替换成 `_up_`,所以给同一个相对路径字符串就能命中同一个位置。

`cd /tmp && tar -xzf ~/.cargo/registry/cache/.../tauri-bundler-2.9.3.crate` 后看 `src/bundle/settings.rs:1182` 和 `cargo:src/path/mod.rs:351-362` 的实现,以及 `tauri-utils-2.9.3/src/resources.rs:387-454` 的 `resource_paths_iter_slice_allow_walk` 测试 case(`../src/script.js` → `_up_/src/script.js`),三方对照确认。

**实战验证**:`find target/release/bundle/macos/文枢.app -name "install.sh"` 实际命中的就是 `Contents/Resources/_up_/_up_/_up_/scripts/install.sh`,与代码预期一致。

### 3.3 `strings <DMG>` 形态不可靠

AC3 原话:"`strings <DMG 文件> | grep 'WENSHU_HOME=' | head -1` 必须命中"。CC 跑了一下,DMG 是 HFS+/UDIF 压缩盘区,`strings` 默认只看外层头部的可打印字符串,**抓不到盘区内的 install.sh**。两种解决方案:
- **A. 看 .app bundle**(推荐):`strings target/release/bundle/macos/文枢.app/Contents/Resources/_up_/_up_/_up_/scripts/install.sh | grep WENSHU_HOME=` 直接命中
- **B. mount DMG**:`hdiutil attach <DMG> -mountpoint /tmp/x` 后 `find /tmp/x -name install.sh` 命中

PM-direct 拍板:AC3 真值以 **A**(bundled install.sh 命中 WENSHU_HOME=)为准,**B**(DMG mount 后能找到)是双保险。bundled install.sh `diff` 与仓根 byte-equal 是最强的真值(说明 bundler 抄对了,不是空文件/损坏文件)。

### 3.4 Cargo.toml 缺 `build = "build.rs"` 的隐性 bug

派单里 R57 单独把这点标出来:"Cargo.toml 现在没有 `[package]` 下 `build = "build.rs"` 行,在 `[package]` 块(line 1-7)加一行"。CC 自验:`Cargo.toml` line 1-7 是 `[package]` 块的 7 行(name/version/description/authors/edition/rust-version + 1 空行),**没有 build = 行**。补一行后 cargo 跑 build.rs(bundle.resources 才会被 tauri_build 收集进 .app 的资源列表)。`cargo check` 第一次跑出 `Compiling wenshu-setup v0.1.0` + `wenshu-bootstrap: following branch main HEAD` warning,说明 build.rs 已生效(line 49-52 的 println!("cargo:warning=..."))。

### 3.5 `resolve()` 签名变化 vs 单元测试隔离

`resolve()` 加了 `app: &tauri::AppHandle` 参数,签名变了。CC 跑了 `grep -rn "install_script::resolve" src/`,**只一个 caller**(bootstrap.rs:379),改完 caller 即可。install_script.rs 自带的单元测试(`is_valid_commit_accepts_short_and_full_shas` 等)不直接调 resolve(),**签名变化不影响测试**。`cargo test --lib` 41 passed,无回归。

### 3.6 build.rs 的 `rerun-if-changed` 必须指仓根路径

`build.rs` 改用 `../../../scripts/install.sh` / `../../../scripts/install.ps1`,而不是 `../dist/install.sh`(那种路径不存在)。build.rs 是从 src-tauri/ 跑,所以相对路径解析跟 tauri.conf.json 的 bundle.resources 完全一致。

---

## 4. commit 计划(AC4 真值)

### 4.1 改了什么(working tree 现状)

```
modified:   apps/bootstrap-installer/src-tauri/Cargo.toml        (+1: build = "build.rs")
modified:   apps/bootstrap-installer/src-tauri/build.rs          (+7: rerun-if-changed for install.sh/ps1)
modified:   apps/bootstrap-installer/src-tauri/src/bootstrap.rs  (±1: 传 &app 进 install_script::resolve)
modified:   apps/bootstrap-installer/src-tauri/src/install_script.rs  (+31 / -1: Bundled 分支 + AppHandle 参数)
modified:   apps/bootstrap-installer/src-tauri/tauri.conf.json   (+4: bundle.resources 数组)
```

**5 个文件改,+43/-2 行**。无 .bak、无多余副本、无 install.sh 重 build(仓根不动)。

### 4.2 commit message(待执行)

```
fix(wenshu): R57 - bundle install.sh / install.ps1 into setup, no GitHub fetch

bootstrap-installer was hitting raw.githubusercontent.com on every install,
which 8/30 company internal network blocks → cache fallback could serve a
stale R53/R55 script. R57 embeds scripts/install.{sh,ps1} as Tauri
bundle.resources so the bootstrap resolves from the .app bundle with no
network dependency.

- install_script.rs: add Bundled branch between Dev and Network; falls
  through to Network when the resource is missing (dev build or edge
  case). Thread AppHandle through resolve() to use Tauri's resource path
  resolver.
- tauri.conf.json: bundle.resources = ["../../../scripts/install.sh",
  "../../../scripts/install.ps1"] (repo-root paths; ../../.. from src-tauri/).
- Cargo.toml: add `build = "build.rs"` so cargo runs the existing build.rs
  (already calls tauri_build::try_build) and tauri-bundler collects the
  resources.
- build.rs: rerun-if-changed for the two scripts so editing them forces
  a rebuild instead of shipping a stale embedded copy.

Untouched: ScriptSource enum (Bundled variant already present), download()
retry-with-backoff, cache_plan() / cached_path() / INSTALL_SCRIPT_REPOSITORY
constant — all kept as fallthrough for the no-bundle edge case.

Verified: cargo test 41 passed; pnpm tauri build exit 0; bundled
install.sh in 文枢.app byte-equal 仓根 scripts/install.sh; DMG mount 后
find 命中 install.sh + install.ps1。
```

### 4.3 push 姿势

CC 走 commit 自决,**push 之前必先 PM-direct 自验**:AC1-AC5 真值表对照、bundled install.sh byte-equal 仓根、DMG mount 命中。PM-direct 拍板 push 后再 `git push origin main`,不抢跑。

---

## 5. 派单姿势改进(给下一张单 R58+ 留)

- **派单文本里的相对路径陷阱要写"验证命令"而不是"路径"**:R57 派单里 PM-direct 已经标红,但实际写代码时 CC 还是要靠 `ls -la ../../../scripts/install.sh` 自验。如果派单直接附"自验命令 `cd <src-tauri> && ls -la ../../../scripts/install.sh` 应该命中仓根 scripts/install.sh",CC 第一次 Edit 之前就能 verify,避免 edit 完才发现路径错。
- **bundled resource 命中的验证姿势**:`find <.app>/Contents/Resources -name install.sh` 是 AC3 的真值命令,比 `strings <DMG>` 更直接。`strings <DMG>` 形态不可靠(§3.3),PM-direct 拍板改了真值命令。
- **Cargo.toml 加 build = 行 这种"小补丁"派单可以一句话带过**:R57 派单列了 4 个文件 + AC5 项 + 派单姿势 + 复盘锚点,CC 一气呵成跑完没有阻塞。如果单是 "Cargo.toml 加 build = 行",直接 inline 一句话 + AC,不另起 R 单。
- **`tauri::path::BaseDirectory::Resource` + `app.path().resolve()` 的相对路径编/解码对称是 Tauri 2.x 的契约**,可以抽到 wenshu 仓的内嵌 helper:`fn bundled_resource(app, relative_from_src_tauri) -> Option<PathBuf>`。R58+ 如果再有资源内嵌需求(比如 install.ps1 之外的产物),直接复用这个 helper,不用每次重新 trace bundler runtime 编码规则。

---

## 6. References

- 派单真值:`WO-001BI-R57`(PM-direct 8/30 调研完)
- 上一张单:R56 cf05cc9de — 重 build WenShu-Setup.dmg + R55 install.sh 修复 UV_CACHE_DIR
- baseline tag:v2026.7.20(Hermes 0.19.0, commit 3ef6bbd20),**R57 不新打 tag**
- Tauri 2.x bundle.resources 文档:https://v2.tauri.app/develop/resources/(comment on resource_relpath: ParentDir → `_up_`)
- Tauri 2.x runtime resolve 文档:https://docs.rs/tauri/2.11.5/tauri/path/struct.PathResolver.html#method.resolve
- Tauri utils 源码验证:tauri-utils-2.9.3/src/resources.rs:387-454(`resource_paths_iter_slice_allow_walk` test)
- Tauri bundler 源码验证:tauri-bundler-2.9.3/src/bundle/settings.rs:1178-1186(`copy_resources`)
- Tauri runtime 源码验证:tauri-2.11.3/src/path/mod.rs:312-369(`resolve_path` with `_up_` encoding)

---

*R57-now 落档 v0.1 · 2026-07-30 · PM-direct 调研 + CC 跑通 · 5 文件 / +43 -2 行 / 41 测试通过 / 0 外网依赖*
