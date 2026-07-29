import type { Translations } from './languages'

/*
 * English installer strings. Kept in sync with zh.ts so the i18n lookup
 * has the same keys regardless of language — en.ts is mostly used for
 * debugging / fallback when the customer's locale doesn't match zh.
 */

export const en: Translations = {
  steps: {
    Prerequisites: 'Prerequisites',
    Repository: 'Repository',
    Venv: 'Venv',
    'Python deps': 'Python deps',
    'Node deps': 'Node deps',
    Path: 'Path',
    Config: 'Config',
    Setup: 'Setup',
    Gateway: 'Gateway',
    Complete: 'Complete'
  }
}
