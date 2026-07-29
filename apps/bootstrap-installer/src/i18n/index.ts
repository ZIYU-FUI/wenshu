import { en } from './en'
import { DEFAULT_LANGUAGE, type Language, type Translations } from './languages'
import { zh } from './zh'

/*
 * i18n facade for the installer.
 *
 * The installer doesn't currently switch language at runtime (the WENSHU
 * customer base reads Chinese), but this module is structured so a
 * future language picker can call `setLanguage()` without rewriting any
 * call site. Today `t()` always resolves to DEFAULT_LANGUAGE.
 *
 * Locale modules are imported eagerly so the bundler tree-shakes nothing
 * — the payload is tiny (a few hundred bytes of strings) and eager
 * import keeps the lookup hot path a single object reference.
 */

const translations: Record<Language, Translations> = {
  zh,
  en
}

let currentLanguage: Language = DEFAULT_LANGUAGE

export function getLanguage(): Language {
  return currentLanguage
}

export function setLanguage(language: Language): void {
  currentLanguage = language
}

/**
 * Translate a step label. Pass the i18n key (e.g. 'Prerequisites',
 * 'Repository'). Unknown keys return the key itself so a missing
 * translation surfaces visibly during smoke tests instead of silently
 * rendering empty UI.
 */
export function tStep(key: string): string {
  return translations[currentLanguage].steps[key] ?? key
}

/** Escape hatch for callers that want the raw translations object. */
export function getTranslations(): Translations {
  return translations[currentLanguage]
}

export type { Language, Translations } from './languages'
