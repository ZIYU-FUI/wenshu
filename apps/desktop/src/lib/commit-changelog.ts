/**
 * Tiny user-facing changelog builder. Takes a list of raw commit summaries,
 * parses the Conventional Commits 1.0 header (`type(scope)!: subject`),
 * filters internal noise (chore/ci/docs/...), strips PM-direct R-numbers
 * (e.g. `R107 - `) from subjects so end users don't see internal ticket ids,
 * and groups the rest into friendly buckets for the locale's translation
 * keys (新功能 / 已修复 / 更快速 / 已改进 / 其他改进 / 本次更新).
 *
 * Inlined (rather than depending on `conventional-commits-parser`) because
 * that package's index re-exports a Node `stream` helper which won't load
 * in the sandboxed Electron renderer, and its actual parse logic for the
 * header is a small regex.
 */

import { capitalize } from '@/lib/text'

export type CommitGroupId = 'new' | 'fixed' | 'faster' | 'improved' | 'other'

export interface CommitGroup {
  id: CommitGroupId
  label: string
  items: string[]
}

export interface ParsedCommit {
  type: null | string
  scope: null | string
  breaking: boolean
  subject: string
}

export interface CommitChangelogInput {
  summary?: string
}

export interface BuildOptions {
  maxGroups?: number
  maxPerGroup?: number
  maxTotal?: number
  /** Localized bucket headings. Missing keys fall back to English. */
  labels?: Partial<CommitChangelogLabels>
}

/**
 * Bucket label set. Callers pass translated strings via the `labels` option
 * on `buildCommitChangelog`; when omitted we fall back to English so the
 * helper stays usable from unit tests and from contexts without an i18n
 * provider. R108: localized labels are sourced from `i18n.{en,zh,ja,zh-hant}`
 * `updates.changelog.group*` keys.
 */
export interface CommitChangelogLabels {
  new: string
  fixed: string
  faster: string
  improved: string
  other: string
  fallback: string
}

const DEFAULT_LABELS: CommitChangelogLabels = {
  new: "What's new",
  fixed: 'Fixed',
  faster: 'Faster',
  improved: 'Improved',
  other: 'Other improvements',
  fallback: 'In this update'
}

const GROUP_ORDER: Record<CommitGroupId, number> = {
  new: 0,
  fixed: 1,
  faster: 2,
  improved: 3,
  other: 4
}

const TYPE_TO_GROUP: Record<string, CommitGroupId> = {
  feat: 'new',
  feature: 'new',
  fix: 'fixed',
  bugfix: 'fixed',
  hotfix: 'fixed',
  revert: 'fixed',
  perf: 'faster',
  performance: 'faster',
  refactor: 'improved',
  a11y: 'improved',
  ui: 'improved',
  ux: 'improved'
}

const HIDDEN_TYPES = new Set([
  'build',
  'chore',
  'ci',
  'dep',
  'deps',
  'doc',
  'docs',
  'lint',
  'release',
  'style',
  'test',
  'tests',
  'wip'
])

const CONVENTIONAL_HEADER = /^(?<type>[a-zA-Z][a-zA-Z0-9_-]*)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s+(?<subject>.+)$/

/** PM-direct R-number prefix used in commit subjects (e.g. `R107 -`). Internal
 *  ticket ids must not appear in the user-facing changelog; strip them here so
 *  end users see plain-language notes. `git log` keeps the full subject. */
const R_NUMBER_PREFIX = /^R\d+\s*[-–—:]\s*/

const FALLBACK_ITEMS = ['Improvements and fixes']

/** Parse a single commit header line per Conventional Commits 1.0. */
export function parseCommitHeader(raw: string): ParsedCommit {
  const header = (raw ?? '').split(/\r?\n/, 1)[0].trim()

  if (!header) {
    return { breaking: false, scope: null, subject: '', type: null }
  }

  const match = CONVENTIONAL_HEADER.exec(header)

  if (!match?.groups) {
    return { breaking: false, scope: null, subject: header, type: null }
  }

  return {
    breaking: Boolean(match.groups.bang),
    scope: match.groups.scope ?? null,
    subject: match.groups.subject.trim(),
    type: match.groups.type.toLowerCase()
  }
}

function tidySubject(subject: string): string {
  const stripped = subject.replace(R_NUMBER_PREFIX, '')
  const cleaned = stripped
    .replace(/\s+/g, ' ')
    .replace(/[.;,\s]+$/, '')
    .trim()

  if (!cleaned) {
    return cleaned
  }

  return capitalize(cleaned)
}

/**
 * Build a small grouped changelog from a list of raw commits.
 * Always returns at least one group; falls back to a neutral placeholder
 * when every commit was filtered or unparseable.
 *
 * Pass `labels` to localize the bucket headings for the active locale.
 */
export function buildCommitChangelog(
  commits: readonly CommitChangelogInput[] | undefined,
  options: BuildOptions = {}
): CommitGroup[] {
  const { maxGroups = 3, maxPerGroup = 4, maxTotal = 6, labels } = options
  const l: CommitChangelogLabels = { ...DEFAULT_LABELS, ...(labels ?? {}) }
  const groups = new Map<CommitGroupId, string[]>()
  const seen = new Set<string>()
  let total = 0

  for (const commit of commits ?? []) {
    if (total >= maxTotal) {
      break
    }

    const parsed = parseCommitHeader(commit.summary ?? '')

    if (parsed.type && HIDDEN_TYPES.has(parsed.type)) {
      continue
    }

    const groupId: CommitGroupId = parsed.type ? (TYPE_TO_GROUP[parsed.type] ?? 'other') : 'other'
    const subject = tidySubject(parsed.subject)

    if (!subject) {
      continue
    }

    const dedupeKey = subject.toLowerCase()

    if (seen.has(dedupeKey)) {
      continue
    }

    const bucket = groups.get(groupId) ?? []

    if (bucket.length >= maxPerGroup) {
      continue
    }

    bucket.push(subject)
    groups.set(groupId, bucket)
    seen.add(dedupeKey)
    total += 1
  }

  const result = Array.from(groups.entries())
    .map(([id, items]) => ({ id, items, label: l[id] }))
    .sort((a, b) => GROUP_ORDER[a.id] - GROUP_ORDER[b.id])
    .slice(0, maxGroups)
    .map(({ id, items, label }): CommitGroup => ({ id, items, label }))

  if (result.length === 0) {
    return [{ id: 'other', items: [...FALLBACK_ITEMS], label: l.fallback }]
  }

  return result
}