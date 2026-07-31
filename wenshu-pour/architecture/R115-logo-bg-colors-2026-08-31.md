# R115 — 文枢 LOGO 背景色（2026-08-31）

## 拍板

文枢毛笔字抠图保持不变，新增两套不透明背景：

- Light：黑色毛笔字 + warm cream `RGB(250, 240, 220)`。
- Dark / app icon：白色毛笔字 + 纯黑 `RGB(0, 0, 0)`。

`brand-mark.tsx` 继续沿用既有 light/dark 图片切换契约，不修改组件代码。

## 实现

使用 Pillow 将 256px 透明源图以 LANCZOS 放大至 1024px，再通过 `Image.alpha_composite` 与目标背景真合成。ICNS 由 Python `struct` 写入 `icns` header，并包含 7 个 PNG chunk：`icp4/icp5/icp6/ic07/ic08/ic09/ic10`（16/32/64/128/256/512/1024）。ICO 由同一黑底源生成。

替换范围：

- `apps/desktop/assets/icon.png`
- `apps/desktop/assets/icon.icns`
- `apps/desktop/assets/icon.ico`
- `apps/bootstrap-installer/src-tauri/icons/icon.png`
- `apps/bootstrap-installer/src-tauri/icons/icon.icns`
- `apps/desktop/public/wenshu-logo-256.png`
- `apps/desktop/public/wenshu-logo-256-dark.png`

## 验证

- PIL：四个仓内 PNG 均为 1024×1024、alpha extrema `(255,255)`；cream corner `(250,240,220,255)`；black corner `(0,0,0,255)`。
- PIL ICNS：可读取 1024×1024 frame；视觉验证为白色“文枢”毛笔字 + 黑底。
- `pnpm build`：通过（exit 0）。
- `pnpm exec tsc --noEmit`：通过（exit 0）。
- `cargo tauri build`：Rust release binary 构建通过，但 macOS bundle icon 阶段两次均被主机权限阻塞：`Failed to create app icon: Operation not permitted (os error 1)`。这是 bundle 写入权限问题，不是 Rust/TS/图标格式编译错误。

版本号保持 `0.1.0`，未 bump；白名单文件未改。
