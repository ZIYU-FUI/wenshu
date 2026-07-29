# WO-001BI-R17：回滚 Desktop BrandMark 为书法 LOGO

> 日期：2026-07-28  
> 来源：装机 user 8/28 拍“正在设置页，LOGO 用书法 LOGO，步骤没有翻译”。

## 1. 问题与范围

R14 将 `apps/desktop/src/components/brand-mark.tsx` 一并改成了 `WENSHU` 文字标识，超出了 Bootstrap installer 的修改范围。Desktop 启动后的初次配置页与 `apps/bootstrap-installer` 是两个不同界面，本单只撤销 Desktop BrandMark 的这项误改。

本单范围：

- 恢复 `assetPath()` 静态资源路径处理。
- BrandMark 恢复渲染 `public/nous-girl.jpg` 书法 LOGO。
- 保留白底、圆角及 `object-contain` 图片样式。
- 不修改 `apps/desktop` 的 i18n、进度页或 10 个英文步骤名。

## 2. 实际改动

| 文件 | 结果 |
|---|---|
| `apps/desktop/src/components/brand-mark.tsx` | 移除 `WENSHU` 文字，恢复 `<img ... src={assetPath('nous-girl.jpg')} />`；回滚后内容与当前 `HEAD` 中的图片实现一致 |
| `wenshu-pour/architecture/R17-rollback-desktop-brand-mark.md` | 记录 R17 范围及验收结果 |

说明：`brand-mark.tsx` 的 R14 改动原本是未提交工作区差异；本次回滚后，该文件不再出现在 `git diff` 中，这是预期结果。

## 3. AC 自验

| AC | 验证 | 结果 |
|---|---|---|
| AC1 | 源码引用 `assetPath('nous-girl.jpg')`，且 `apps/desktop/public/nous-girl.jpg` 存在 | ✅ |
| AC2 | 固定仓库根检查 `apps/desktop/src`，没有 i18n/progress 路径处于修改状态；本单未编辑相关文案 | ✅ |
| AC3 | `cd apps/desktop && pnpm exec prettier --check src/components/brand-mark.tsx` | ✅ `All matched files use Prettier code style!` |
| AC4 | 检查 `brand-mark.tsx` 中不存在字面量 `WENSHU` | ✅ 0 命中 |
| AC5 | 本文件落档 | ✅ |

## 4. 验证命令

```bash
cd /Volumes/ANAN/Engineering/wenshu/apps/desktop
pnpm exec prettier --check src/components/brand-mark.tsx

ROOT=/Volumes/ANAN/Engineering/wenshu
FILE="$ROOT/apps/desktop/src/components/brand-mark.tsx"
test -f "$ROOT/apps/desktop/public/nous-girl.jpg"
grep -F "assetPath('nous-girl.jpg')" "$FILE"
! grep -Fq 'WENSHU' "$FILE"

git -C "$ROOT" diff --exit-code HEAD -- \
  apps/desktop/src/components/brand-mark.tsx
```

最终结果：以上检查均通过。没有执行 commit 或 push。工作区中的其他既有或并发改动不属于本单，均未触碰。
