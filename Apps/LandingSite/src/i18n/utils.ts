import zh from "./zh.json";
import en from "./en.json";

// ─── Locale types ────────────────────────────────────────────────

export type Locale = "en" | "zh";

export const defaultLocale: Locale = "zh";

export const locales: Locale[] = ["zh", "en"];

// ─── LandingCopy schema ─────────────────────────────────────────

export interface LandingCopy {
  meta: {
    title: string;
    description: string;
    ogImage: string;
  };
  nav: {
    whyAtlas: string;
    howItWorks: string;
    developers: string;
    safety: string;
    faq: string;
    download: string;
  };
  hero: {
    headline: string;
    subheadline: string;
    ctaPrimary: string;
    ctaSecondary: string;
    badgeStable: string;
    badgePrerelease: string;
    badgeComingSoon: string;
    prereleaseWarning: string;
    gatekeeperNote: string;
    versionLabel: string;
  };
  trustStrip: {
    openSource: string;
    recoveryFirst: string;
    developerAware: string;
    macNative: string;
    directDownload: string;
  };
  problem: {
    sectionTitle: string;
    scenarios: Array<{ before: string; after: string }>;
  };
  features: {
    sectionTitle: string;
    cards: Array<{
      title: string;
      value: string;
      example: string;
      trustCue: string;
    }>;
  };
  howItWorks: {
    sectionTitle: string;
    steps: Array<{ label: string; description: string }>;
  };
  developer: {
    sectionTitle: string;
    subtitle: string;
    items: Array<{ title: string; description: string }>;
  };
  safety: {
    sectionTitle: string;
    subtitle: string;
    points: Array<{ title: string; description: string }>;
    gatekeeperGuide: {
      title: string;
      steps: string[];
    };
  };
  screenshots: {
    sectionTitle: string;
    items: Array<{ src: string; alt: string; caption: string }>;
  };
  openSource: {
    sectionTitle: string;
    repoLabel: string;
    licenseLabel: string;
    attributionLabel: string;
    changelogLabel: string;
  };
  faq: {
    sectionTitle: string;
    items: Array<{ question: string; answer: string }>;
  };
  footer: {
    download: string;
    github: string;
    documentation: string;
    privacy: string;
    security: string;
    copyright: string;
  };
}

// ─── Translation map ────────────────────────────────────────────

const translations: Record<Locale, LandingCopy> = {
  zh: zh as LandingCopy,
  en: en as LandingCopy,
};

// ─── Public API ─────────────────────────────────────────────────

/**
 * Returns the full translation object for the given locale.
 *
 * @example
 * ```ts
 * const copy = t('zh');
 * console.log(copy.hero.headline);
 * ```
 */
export function t(locale: Locale): LandingCopy {
  return translations[locale] ?? translations[defaultLocale];
}

/**
 * Extracts the locale from a URL pathname.
 * Expects paths like `/en/...` or `/zh/...`.
 * Falls back to `defaultLocale` when the prefix is not a known locale.
 *
 * @example
 * ```ts
 * getLocaleFromUrl(new URL('https://atlas.atomstorm.ai/en/'));
 * // => 'en'
 *
 * getLocaleFromUrl(new URL('https://atlas.atomstorm.ai/'));
 * // => 'zh'
 * ```
 */
export function getLocaleFromUrl(url: URL): Locale {
  const [, segment] = url.pathname.split("/");
  if (segment && locales.includes(segment as Locale)) {
    return segment as Locale;
  }
  return defaultLocale;
}
