import { useQuery } from '@tanstack/react-query'

import { getWenshuConfigRecord } from '@/wenshu'
import { queryClient, writeCache } from '@/lib/query-client'
import type { WenshuConfigRecord } from '@/types/wenshu'

// One shared cache for the whole profile config record (`GET /api/config`).
// Every settings surface (MCP, model, config) reads and writes through this key
// so a save in one shows in the others, and revisiting a tab paints the cache
// instead of blanking on a fresh fetch.
//
// Distinct from session/hooks/use-wenshu-config.ts, which is side-effecting —
// it pushes personality/cwd/voice/… into the session stores for live chat.
export const WENSHU_CONFIG_KEY = ['wenshu-config-record'] as const

// staleTime 0 → serve cache instantly, background-revalidate on every mount.
export const useWenshuConfigRecord = () =>
  useQuery({ queryKey: WENSHU_CONFIG_KEY, queryFn: getWenshuConfigRecord, staleTime: 0 })

export const setWenshuConfigCache = writeCache<WenshuConfigRecord>(WENSHU_CONFIG_KEY)

export const invalidateWenshuConfig = () => queryClient.invalidateQueries({ queryKey: WENSHU_CONFIG_KEY })
