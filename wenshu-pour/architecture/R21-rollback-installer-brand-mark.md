# WO-001BI-R21：回滚 Bootstrap Installer BrandMark 为书法 LOGO

> 日期：2026-07-28  
> 来源：装机 user 8/28 拍“红框里的 LOGO，用文枢毛笔字 / 这个没有换”。

## 1. 问题与范围

R14 将 `apps/bootstrap-installer/src/components/brand-mark.tsx` 从 `nous-girl.jpg` 书法 LOGO 改成了 `WENSHU` 文字标识。上一张 R17 错误修改了 Desktop 启动后的 BrandMark；用户本次指出的是 Bootstrap installer 安装界面。

本单只回滚 Bootstrap installer 的 BrandMark：

- 恢复 `assetPath()` 静态资源路径处理。
- 恢复渲染 `public/nous-girl.jpg` 书法 LOGO。
- 不修改 R14 的 i18n 翻译文件。
- 不修改 R14 的 `progress.tsx` 中文步骤。
- 不修改 Desktop BrandMark。

## 2. 实际改动

| 文件 | 结果 |
|---|---|
| `apps/bootstrap-installer/src/components/brand-mark.tsx` | 移除 `WENSHU` 文字，恢复 `<img ... src={assetPath('nous-girl.jpg')} />` |
| `wenshu-pour/architecture/R21-rollback-installer-brand-mark.md` | 记录 R21 范围、复盘锚点与验收结果 |

## 3. AC 自验

| AC | 验证 | 结果 |
|---|---|---|
| AC1 | BrandMark 引用 `assetPath('nous-girl.jpg')`，资源文件存在，且源码无 `WENSHU` 字面量 | ✅ |
| AC2 | 本单未编辑 `apps/bootstrap-installer/src/i18n/`，保留 R14 翻译 | ✅ |
| AC3 | 本单未编辑 `apps/bootstrap-installer/src/routes/progress.tsx`，保留 R14 中文步骤 | ✅ |
| AC4 | `pnpm exec prettier --check src/components/brand-mark.tsx` | ✅ `All matched files use Prettier code style!` |
| AC5 | 本文件落档 | ✅ |

## 4. 验证命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/bootstrap-installer
pnpm exec prettier --check src/components/brand-mark.tsx

ROOT=/Volumes/ANAN/Engineering/wenshu
FILE="$ROOT/apps/bootstrap-installer/src/components/brand-mark.tsx"
test -f "$ROOT/apps/bootstrap-installer/public/nous-girl.jpg"
grep -F "assetPath('nous-girl.jpg')" "$FILE"
! grep -Fq 'WENSHU' "$FILE"

git -C "$ROOT" diff --name-only -- \
  apps/bootstrap-installer/src/components/brand-mark.tsx \
  apps/bootstrap-installer/src/i18n \
  apps/bootstrap-installer/src/routes/progress.tsx
```

最终结果：BrandMark 格式及图片引用检查通过。`i18n/` 与 `progress.tsx` 在开工前已有 R14 工作区改动，本单未触碰；没有执行 commit 或 push。工作区中的其他既有或并发改动不属于本单，均未触碰。
