import { cn } from '@/lib/utils'

const assetPath = (path: string) => `${import.meta.env.BASE_URL}${path.replace(/^\/+/, '')}`

// Brand badge: 文枢毛笔字 (wenshu-logo-256.png), identical in light/dark.
// Fills the tile (softly rounded); size via className (default size-14).
// R23 替换 R17/R21 上一代 LOGO → 文枢自有毛笔字 LOGO, 装机 user 8/28 拍.
export function BrandMark({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      className={cn(
        'inline-flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-md bg-white',
        className
      )}
      {...props}
    >
      <img alt="" className="size-full object-contain" src={assetPath('wenshu-logo-256.png')} />
    </span>
  )
}
