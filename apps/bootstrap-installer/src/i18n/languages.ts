/*
 * Supported installer languages. The installer UI is Chinese-first by
 * default (the customer base for this fork reads Chinese); English is
 * kept for fallback / debugging. Add a language by appending its code
 * here + a translation module under ./<code>.ts.
 *
 * Translations is the contract every locale module must satisfy. Adding
 * a section (e.g. errors, buttons) is additive; existing locale modules
 * just need their object literal updated to match.
 */

export const LANGUAGES = ['zh', 'en'] as const

export type Language = (typeof LANGUAGES)[number]

export const DEFAULT_LANGUAGE: Language = 'zh'

export interface Translations {
  steps: Record<string, string>
}

export function isLanguage(value: string | null | undefined): value is Language {
  if (!value) {
    return false
  }

  return (LANGUAGES as readonly string[]).includes(value)
}
