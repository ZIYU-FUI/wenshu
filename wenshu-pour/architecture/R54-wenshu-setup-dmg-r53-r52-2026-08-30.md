# R54: WenShu Setup DMG（R53/R52 验收）

日期：2026-07-30

## 构建

在 `apps/bootstrap-installer` 执行：

```bash
pnpm tauri build
```

构建成功（exit code 0），Tauri 产物：

- `src-tauri/target/release/bundle/macos/文枢.app`
- `src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg`

## 版本核验

`src-tauri/Cargo.toml` 的 package version 实际为 `0.1.0`。

## 交付文件

已复制：

- 来源：`/Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer/src-tauri/target/release/bundle/dmg/文枢_0.1.0_aarch64.dmg`
- 目标：`/Users/anbaiqiang/Downloads/WenShu-Setup.dmg`
- 文件大小：`5,543,773` bytes
- 目标文件 mtime：`2026-07-30 11:23:03 +0800`
- MD5：`0ea017fa03efad995414735ecdec866f`

来源文件大小同为 `5,543,773` bytes；复制后以 `md5` 对目标文件核验。

## R53/R52 关联

本次仅构建并交付 R53/R52 后的安装器，不修改白名单。R53 的用户场景瘦安装逻辑（浅克隆、共享 uv cache、清理 bootstrap cache、更新时浅拉取）随当前代码进入安装器构建；R52 的在线更新阶段标签与中文日志改动同样随当前代码进入构建。

## Git

本次仅新增本落档文件；未修改 whitelist。
