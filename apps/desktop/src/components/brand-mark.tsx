import { cn } from '@/lib/utils'

const assetPath = (path: string) => `${import.meta.env.BASE_URL}${path.replace(/^\/+/, '')}`

// Brand badge: 文枢毛笔字 (wenshu-logo-256.png + wenshu-logo-256-dark.png).
// Light mode → 黑字透明背景; Dark mode → 白字透明背景 (R102 装机 user 8/31 拍板).
// Fills the tile (softly rounded); size via className (default size-14).
// R23 替换 R17/R21 上一代 LOGO → 文枢自有毛笔字 LOGO, 装机 user 8/28 拍.
// R102 拆浅色/暗色双套, light/dark 模式自适应切换.
export function BrandMark({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      className={cn(
        'inline-flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-md bg-white dark:bg-zinc-900',
        className
      )}
      {...props}
    >
      <img
        alt=""
        className="size-full object-contain dark:hidden"
        src={assetPath('wenshu-logo-256.png')}
      />
      <img
        alt=""
        className="hidden size-full object-contain dark:block"
        src={assetPath('wenshu-logo-256-dark.png')}
      />
    </span>
  )
}