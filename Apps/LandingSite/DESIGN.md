# Atlas Landing Page — Atom Web Design Specification

> **Domain**: `atlas.atomstorm.ai` | **Deploy**: GitHub Pages | **Source**: `Apps/LandingSite/`
> **PRD**: `Docs/Execution/Landing-Page-PRD-2026-03-14.md`
> **Date**: 2026-03-15

---

## Table of Contents

1. [Product Definition](#1-product-definition)
2. [Tech Stack Decision](#2-tech-stack-decision)
3. [Data Architecture](#3-data-architecture)
4. [Component Architecture](#4-component-architecture)
5. [Constraint System](#5-constraint-system)
6. [Visual Design System](#6-visual-design-system)
7. [Quality Gates](#7-quality-gates)

---

## 1. Product Definition

### 1.1 User Stories

| ID | Story | Acceptance Criteria |
|----|-------|-------------------|
| US-01 | As a first-time visitor, I want to understand what Atlas does in one screen so I can decide if it solves my problem. | Hero section communicates product promise in < 10 seconds; headline + subheadline + screenshot visible above the fold. |
| US-02 | As a cautious Mac user, I want to see safety and trust signals so I can decide whether Atlas is safe enough to install. | Trust strip, open-source badge, recovery-first messaging, permissions explanation, and Gatekeeper guidance are all visible without deep scrolling. |
| US-03 | As a developer, I want to see that Atlas understands developer disk pressure (Xcode, simulators, caches) so I know it is relevant to my workflow. | Developer cleanup section lists concrete developer artifacts (derived data, simulators, package caches) with Atlas-specific handling. |
| US-04 | As a potential downloader, I want to get the latest build without navigating GitHub so I can install Atlas quickly. | Primary CTA links to the correct release asset; version number, channel badge, and release date are visible next to the CTA. |
| US-05 | As a visitor encountering a prerelease, I want honest disclosure about signing status and Gatekeeper friction so I can install without confusion. | Prerelease badge, warning label, and "Open Anyway" recovery path are shown when the latest release is not Developer ID signed. |

### 1.2 MVP Scope

| Included | Deferred |
|----------|----------|
| Single bilingual single-page site (`/zh/`, `/en/`) | Blog / CMS |
| Responsive hero with release-state CTA | Changelog microsite |
| 11 page sections (Hero → Footer) | Testimonials from named users |
| Screenshot gallery (4–6 images) | Interactive benchmark calculator |
| Dynamic release state block (build-time) | Gated PDF lead magnet |
| Trust/safety section with Gatekeeper guidance | Multi-page docs hub |
| FAQ with expand/collapse | Account system |
| GitHub Pages deployment with custom domain | Pricing or checkout flow |
| Privacy-respecting analytics (Plausible) | In-browser disk scan demo |
| Optional beta email capture (3rd-party form) | |

### 1.3 Release Channel State Machine

The page must treat release channel status as product truth. Three states drive CTA behavior:

```
┌─────────────────────┐
│   No Public Release  │ ← no GitHub Release with assets
│   CTA: "View on      │
│   GitHub" / "Join     │
│   Beta Updates"       │
└──────────┬──────────┘
           │ first release published
           ▼
┌─────────────────────┐
│   Prerelease Only    │ ← prerelease=true on latest release
│   CTA: "Download     │
│   Prerelease"         │
│   + warning label     │
│   + Gatekeeper note   │
└──────────┬──────────┘
           │ Developer ID signing configured
           ▼
┌─────────────────────┐
│   Stable Release     │ ← prerelease=false on latest release
│   CTA: "Download     │
│   for macOS"          │
│   + version badge     │
└─────────────────────┘
```

**State × CTA Behavior Matrix**:

| State | Primary CTA Label | Badge | Warning | Secondary CTA |
|-------|-------------------|-------|---------|---------------|
| Stable | Download for macOS | `Stable` (teal) | None | View on GitHub |
| Prerelease | Download Prerelease | `Prerelease` (amber) | Gatekeeper install note | View on GitHub |
| No Release | View on GitHub | `Coming Soon` (slate) | None | Join Beta Updates |

---

## 2. Tech Stack Decision

### 2.1 Stack Table

| Layer | Choice | Why |
|-------|--------|-----|
| **Framework** | Astro 5.x (static adapter) | Outputs pure HTML/CSS with zero JS by default; matches PRD's "static-first" requirement |
| **Styling** | Vanilla CSS + custom properties | 1:1 token mapping from `AtlasBrand.swift`; avoids Tailwind's generic aesthetic per PRD's "not generic SaaS" direction |
| **i18n** | `@astrojs/i18n` path-based routing | Native Astro feature; produces `/en/` and `/zh/` paths with `hreflang` tags |
| **Fonts** | Self-hosted (Space Grotesk, Instrument Sans, IBM Plex Mono) | Eliminates Google Fonts dependency; keeps < 20KB JS budget; GDPR-safe |
| **Analytics** | Plausible (self-hosted or cloud) | Privacy-respecting, cookie-free, GDPR-compliant; custom events for CTA/FAQ tracking |
| **Search Console** | Google Search Console | Indexing monitoring and query analysis; no client-side impact |
| **Hosting** | GitHub Pages | Free, reliable, native GitHub Actions integration; custom domain with HTTPS |
| **CI/CD** | GitHub Actions (`.github/workflows/landing-page.yml`) | Triggers on source changes + release events; deploys via `actions/deploy-pages` |
| **Release Data** | Build-time GitHub API fetch → static manifest | No client-side API dependency for first paint; fallback to embedded JSON |
| **UI Framework** | None (no React/Vue/Svelte) | Zero framework overhead; `.astro` components render to static HTML |
| **Package Manager** | pnpm | Fast, deterministic, disk-efficient |

### 2.2 Key Technical Decisions

1. **No UI framework islands** — Every component is a `.astro` file that renders to static HTML. The only client JS is: language toggle persistence (`localStorage`, < 200 bytes), FAQ accordion (`<details>` elements with optional progressive enhancement), and Plausible analytics snippet (< 1KB).

2. **Self-hosted fonts** — Font files are committed to `Apps/LandingSite/public/fonts/`. Subset to Latin + CJK ranges. Use `font-display: swap` for all faces.

3. **Build-time release manifest** — A `scripts/fetch-release.ts` script runs at build time to query the GitHub Releases API and emit `src/data/release-manifest.json`. A static fallback (`src/data/release-fallback.json`) is used if the API call fails.

---

## 3. Data Architecture

### 3.1 `ReleaseManifest` Schema

```typescript
/**
 * Generated at build time by scripts/fetch-release.ts
 * Consumed by Hero, CTA, and Footer components.
 * File: src/data/release-manifest.json
 */
interface ReleaseManifest {
  /** Release channel: determines CTA behavior and badge */
  channel: "stable" | "prerelease" | "none";

  /** Semantic version string, e.g. "1.0.2" */
  version: string | null;

  /** ISO 8601 date string of the release publication */
  publishedAt: string | null;

  /** GitHub Release page URL */
  releaseUrl: string | null;

  /** Direct download asset links */
  assets: {
    dmg: string | null;
    zip: string | null;
    pkg: string | null;
    sha256: string | null;
  };

  /** Whether Gatekeeper friction is expected */
  gatekeeperWarning: boolean;

  /** Human-readable install note for prerelease builds */
  installNote: string | null;

  /** Git tag name, e.g. "V1.0.2" */
  tagName: string | null;

  /** Timestamp of manifest generation (ISO 8601) */
  generatedAt: string;
}
```

**Priority chain** (per PRD):
1. Build-time generated `release-manifest.json` via `scripts/fetch-release.ts`
2. Static fallback `src/data/release-fallback.json` (committed, manually maintained)
3. No client-side GitHub API fetch for first paint

**Manifest generation logic** (`scripts/fetch-release.ts`):
```
1. Fetch latest release from GitHub API (repos/{owner}/{repo}/releases/latest)
2. If no release exists → channel: "none"
3. If release.prerelease === true → channel: "prerelease", gatekeeperWarning: true
4. If release.prerelease === false → channel: "stable", gatekeeperWarning: false
5. Extract .dmg, .zip, .pkg, .sha256 from release.assets[]
6. Write to src/data/release-manifest.json
```

### 3.2 `LandingCopy` i18n Schema

```typescript
/**
 * Translation file structure.
 * Files: src/i18n/en.json, src/i18n/zh.json
 * Keys are grouped by page section for maintainability.
 */
interface LandingCopy {
  meta: {
    title: string;           // <title> and og:title
    description: string;     // <meta name="description"> and og:description
    ogImage: string;         // og:image path
  };

  nav: {
    whyAtlas: string;
    howItWorks: string;
    developers: string;
    safety: string;
    faq: string;
    download: string;        // CTA label (dynamic, overridden by channel)
  };

  hero: {
    headline: string;
    subheadline: string;
    ctaPrimary: string;      // Overridden by channel state
    ctaSecondary: string;    // "View on GitHub"
    badgeStable: string;
    badgePrerelease: string;
    badgeComingSoon: string;
    prereleaseWarning: string;
    gatekeeperNote: string;
    versionLabel: string;    // "Version {version} · {date}"
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
    scenarios: Array<{
      before: string;        // Pain point
      after: string;         // Atlas outcome
    }>;
  };

  features: {
    sectionTitle: string;
    cards: Array<{
      title: string;
      value: string;         // User-facing value proposition
      example: string;       // Concrete example
      trustCue: string;      // Trust signal
    }>;
  };

  howItWorks: {
    sectionTitle: string;
    steps: Array<{
      label: string;
      description: string;
    }>;
  };

  developer: {
    sectionTitle: string;
    subtitle: string;
    items: Array<{
      title: string;
      description: string;
    }>;
  };

  safety: {
    sectionTitle: string;
    subtitle: string;
    points: Array<{
      title: string;
      description: string;
    }>;
    gatekeeperGuide: {
      title: string;
      steps: string[];
    };
  };

  screenshots: {
    sectionTitle: string;
    items: Array<{
      src: string;
      alt: string;
      caption: string;
    }>;
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
    items: Array<{
      question: string;
      answer: string;
    }>;
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
```

### 3.3 State Management Map

All state is resolved at build time. The only client-side state is:

| State | Scope | Storage | Purpose |
|-------|-------|---------|---------|
| Language preference | Session | `localStorage` key `atlas-lang` | Remember manual language switch |
| FAQ expanded items | Transient | DOM (`<details open>`) | No persistence needed |
| Release data | Build-time | `release-manifest.json` | Embedded in HTML at build |
| Analytics events | Fire-and-forget | Plausible JS SDK | No local state |

---

## 4. Component Architecture

### 4.1 File Structure

```
Apps/LandingSite/
├── astro.config.mjs              # Astro config: static adapter, i18n, site URL
├── package.json                   # Dependencies: astro, @astrojs/sitemap
├── pnpm-lock.yaml
├── tsconfig.json
├── public/
│   ├── fonts/                     # Self-hosted font files (woff2)
│   │   ├── SpaceGrotesk-Bold.woff2
│   │   ├── SpaceGrotesk-Medium.woff2
│   │   ├── InstrumentSans-Regular.woff2
│   │   ├── InstrumentSans-Medium.woff2
│   │   ├── IBMPlexMono-Regular.woff2
│   │   └── IBMPlexMono-Medium.woff2
│   ├── images/
│   │   ├── atlas-icon.png         # App icon (from Docs/Media/README/)
│   │   ├── og-image-en.png        # Open Graph image (English)
│   │   ├── og-image-zh.png        # Open Graph image (Chinese)
│   │   └── screenshots/           # Product screenshots
│   │       ├── atlas-overview.png
│   │       ├── atlas-smart-clean.png
│   │       ├── atlas-apps.png
│   │       ├── atlas-history.png
│   │       ├── atlas-settings.png
│   │       └── atlas-prerelease-warning.png
│   ├── favicon.ico
│   └── robots.txt
├── src/
│   ├── data/
│   │   ├── release-manifest.json  # Build-time generated
│   │   └── release-fallback.json  # Static fallback (committed)
│   ├── i18n/
│   │   ├── en.json                # English translations
│   │   ├── zh.json                # Chinese translations
│   │   └── utils.ts               # t() helper, locale detection
│   ├── styles/
│   │   ├── tokens.css             # Design tokens as CSS custom properties
│   │   ├── reset.css              # Minimal CSS reset
│   │   ├── global.css             # Global styles (fonts, base elements)
│   │   └── utilities.css          # Utility classes (sr-only, container, etc.)
│   ├── layouts/
│   │   └── BaseLayout.astro       # HTML shell: <head>, meta, fonts, analytics
│   ├── components/
│   │   ├── NavBar.astro           # [interactive] Sticky top nav + language toggle + CTA
│   │   ├── Hero.astro             # [static] Headline, subheadline, CTA, badge, screenshot
│   │   ├── TrustStrip.astro       # [static] Five trust signal pills
│   │   ├── ProblemOutcome.astro   # [static] Three pain → solution cards
│   │   ├── FeatureGrid.astro      # [static] Six feature story cards
│   │   ├── HowItWorks.astro       # [static] Four-step workflow visualization
│   │   ├── DeveloperSection.astro # [static] Developer cleanup showcase
│   │   ├── SafetySection.astro    # [static] Permissions, trust, Gatekeeper guide
│   │   ├── ScreenshotGallery.astro# [interactive] Desktop gallery / mobile carousel
│   │   ├── OpenSourceSection.astro# [static] Repo link, license, attribution
│   │   ├── FaqSection.astro       # [interactive] Expandable Q&A using <details>
│   │   ├── FooterSection.astro    # [static] Links, privacy, security contact
│   │   ├── CtaButton.astro        # [static] Reusable CTA (primary/secondary variants)
│   │   ├── ChannelBadge.astro     # [static] Release channel badge (stable/prerelease/coming)
│   │   └── FeatureCard.astro      # [static] Reusable card for feature grid
│   └── pages/
│       ├── index.astro            # Root redirect → /zh/
│       ├── zh/
│       │   └── index.astro        # Chinese landing page
│       └── en/
│           └── index.astro        # English landing page
└── scripts/
    └── fetch-release.ts           # Build-time script: GitHub API → release-manifest.json
```

### 4.2 Component Interaction Map

```
BaseLayout.astro
└── [lang]/index.astro
    ├── NavBar.astro .................. [interactive: language toggle, mobile menu]
    │   ├── CtaButton.astro            props: { label, href, variant: "primary" }
    │   └── ChannelBadge.astro         props: { channel }
    ├── Hero.astro .................... [static]
    │   ├── CtaButton.astro            props: { label, href, variant: "primary" }
    │   ├── CtaButton.astro            props: { label, href, variant: "secondary" }
    │   └── ChannelBadge.astro         props: { channel, version, date }
    ├── TrustStrip.astro .............. [static]
    ├── ProblemOutcome.astro .......... [static]
    ├── FeatureGrid.astro ............. [static]
    │   └── FeatureCard.astro (×6)     props: { title, value, example, trustCue, icon }
    ├── HowItWorks.astro .............. [static]
    ├── DeveloperSection.astro ........ [static]
    ├── SafetySection.astro ........... [static]
    ├── ScreenshotGallery.astro ....... [interactive: carousel on mobile]
    ├── OpenSourceSection.astro ....... [static]
    ├── FaqSection.astro .............. [interactive: <details> expand/collapse]
    └── FooterSection.astro ........... [static]
        └── CtaButton.astro            props: { label, href, variant: "primary" }
```

**Boundary annotations**:
- `[static]` — Pure HTML at build time, zero client JS
- `[interactive]` — Minimal client JS via inline `<script>` in the component (no framework island)

### 4.3 Component Props Summary

| Component | Props | Data Source |
|-----------|-------|-------------|
| `CtaButton` | `label: string, href: string, variant: "primary" \| "secondary" \| "ghost"` | i18n + manifest |
| `ChannelBadge` | `channel: "stable" \| "prerelease" \| "none", version?: string, date?: string` | manifest |
| `FeatureCard` | `title: string, value: string, example: string, trustCue: string, icon: string` | i18n |
| `NavBar` | `locale: "en" \| "zh", manifest: ReleaseManifest` | i18n + manifest |
| `Hero` | `locale: "en" \| "zh", manifest: ReleaseManifest` | i18n + manifest |
| `FaqSection` | `items: Array<{ question: string, answer: string }>` | i18n |
| `ScreenshotGallery` | `items: Array<{ src: string, alt: string, caption: string }>` | i18n |

---

## 5. Constraint System

### 5.1 NEVER Rules

| # | Category | Rule |
|---|----------|------|
| N-01 | Brand | NEVER use the `Mole` brand name in any user-facing text, metadata, or alt text. |
| N-02 | Brand | NEVER claim malware protection, antivirus behavior, or security scanning capability. |
| N-03 | Brand | NEVER overstate physical recovery coverage — always qualify with "when supported". |
| N-04 | Brand | NEVER imply all releases are Apple-signed if the current release is a prerelease. |
| N-05 | Security | NEVER include hardcoded GitHub tokens, API keys, or secrets in client-facing code. |
| N-06 | Security | NEVER use client-side GitHub API fetches for critical first-paint release information. |
| N-07 | Security | NEVER rely on a manually committed `CNAME` file when using a custom GitHub Actions Pages workflow. |
| N-08 | Performance | NEVER ship a client JS bundle exceeding 20KB (excluding analytics). |
| N-09 | Performance | NEVER load fonts from external CDNs (Google Fonts, etc.). |
| N-10 | Performance | NEVER use framework islands (React, Vue, Svelte) for any component. |
| N-11 | Aesthetics | NEVER use generic SaaS gradients, purple-heavy palettes, or interchangeable startup layouts. |
| N-12 | Aesthetics | NEVER use endless floating particles, decorative animation loops, or bouncy spring motion. |
| N-13 | Copy | NEVER use hype words: "ultimate", "magic", "AI cleaner", "revolutionary", "blazing fast". |
| N-14 | Copy | NEVER use fear-based maintenance language: "Your Mac is at risk", "Critical error", "You must allow this". |

### 5.2 ALWAYS Rules

| # | Category | Rule |
|---|----------|------|
| A-01 | Disclosure | ALWAYS show exact version number and release date next to the download CTA. |
| A-02 | Disclosure | ALWAYS show a channel badge (`Stable`, `Prerelease`, or `Coming Soon`) next to the CTA. |
| A-03 | Disclosure | ALWAYS show a Gatekeeper install note when the release is a prerelease. |
| A-04 | Accessibility | ALWAYS maintain WCAG 2.1 AA contrast ratios (4.5:1 for normal text, 3:1 for large text). |
| A-05 | Accessibility | ALWAYS provide alt text for every image; screenshot alt text must describe the UI state shown. |
| A-06 | Accessibility | ALWAYS ensure all interactive elements are keyboard-navigable with visible focus indicators. |
| A-07 | i18n | ALWAYS include `hreflang` tags on both `/en/` and `/zh/` pages. |
| A-08 | i18n | ALWAYS serve localized `<title>`, `<meta description>`, and Open Graph metadata per locale. |
| A-09 | Testing | ALWAYS validate HTML output with the W3C validator before each deploy. |
| A-10 | Testing | ALWAYS run Lighthouse CI on both locales before merging to main. |
| A-11 | SEO | ALWAYS use crawlable `<h1>`–`<h6>` headings; never render hero text only inside images. |
| A-12 | Copy | ALWAYS qualify recovery claims with "when supported" or "while the retention window is open". |
| A-13 | Copy | ALWAYS use concrete verbs for CTAs: `Scan`, `Review`, `Restore`, `Download`. |

### 5.3 Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| CSS custom property | `--atlas-{category}-{name}` | `--atlas-color-brand` |
| Component file | PascalCase `.astro` | `FeatureCard.astro` |
| CSS class | BEM-lite: `block__element--modifier` | `hero__cta--primary` |
| i18n key | dot-separated section path | `hero.headline` |
| Image file | kebab-case, descriptive | `atlas-overview.png` |
| Script file | kebab-case `.ts` | `fetch-release.ts` |
| Data file | kebab-case `.json` | `release-manifest.json` |

---

## 6. Visual Design System

### 6.1 Design Thinking — Four Questions

**Q1: Who is viewing this page?**
Mac users with disk pressure — both mainstream and developers — evaluating Atlas as an alternative to opaque commercial cleanup apps. They are cautious, technically aware, and skeptical of "magic cleaner" marketing.

**Q2: What should they feel?**
"This tool understands my Mac and will be honest with me." Calm authority, not hype. Precision, not spectacle. The page should feel like a modern macOS-native operations console translated into a polished marketing surface.

**Q3: What is the single most important action?**
Download the latest release (or, if prerelease, understand the install friction and proceed anyway).

**Q4: What could go wrong?**
- User mistakes a prerelease for a stable release → mitigated by mandatory channel badge and warning
- User bounces because the page looks like generic SaaS → mitigated by dark "precision utility" theme with native Mac feel
- User can't find the download → mitigated by persistent CTA in nav + hero + footer

### 6.2 CSS Custom Properties — Design Tokens

All values are derived from `AtlasBrand.swift` and the Xcode color assets. The landing page uses a **dark-only** theme per PRD direction.

```css
/* ══════════════════════════════════════════════════════
   Atlas Landing Page — Design Tokens
   Source of truth: AtlasBrand.swift + AtlasColors.xcassets
   Theme: "Precision Utility" (dark-only)
   ══════════════════════════════════════════════════════ */

:root {
  /* ── Colors: Background ──────────────────────────── */
  --atlas-color-bg-base:          #0D0F11;   /* Graphite / near-black */
  --atlas-color-bg-surface:       #1A1D21;   /* Warm slate cards */
  --atlas-color-bg-surface-hover: #22262B;   /* Card hover state */
  --atlas-color-bg-raised:        rgba(255, 255, 255, 0.06);  /* Glassmorphic tint (matches AtlasColor.cardRaised dark) */
  --atlas-color-bg-code:          #151820;   /* Code block background */

  /* ── Colors: Brand ───────────────────────────────── */
  /*
   * AtlasBrand.colorset:
   *   Light: sRGB(0.0588, 0.4627, 0.4314) = #0F766E
   *   Dark:  sRGB(0.0784, 0.5647, 0.5216) = #149085
   *
   * Landing page uses the dark variant as primary.
   */
  --atlas-color-brand:            #149085;   /* AtlasBrand dark — primary teal */
  --atlas-color-brand-light:      #0F766E;   /* AtlasBrand light — used for hover contrast */
  --atlas-color-brand-glow:       rgba(20, 144, 133, 0.25);  /* CTA shadow glow */

  /* ── Colors: Accent ──────────────────────────────── */
  /*
   * AtlasAccent.colorset:
   *   Light: sRGB(0.2039, 0.8275, 0.6000) = #34D399
   *   Dark:  sRGB(0.3216, 0.8863, 0.7098) = #52E2B5
   */
  --atlas-color-accent:           #34D399;   /* AtlasAccent light — mint highlight */
  --atlas-color-accent-bright:    #52E2B5;   /* AtlasAccent dark — brighter mint */

  /* ── Colors: Semantic ────────────────────────────── */
  --atlas-color-success:          #22C55E;   /* systemGreen equivalent */
  --atlas-color-warning:          #F59E0B;   /* Amber — prerelease/caution states */
  --atlas-color-danger:           #EF4444;   /* systemRed equivalent */
  --atlas-color-info:             #3B82F6;   /* systemBlue equivalent */

  /* ── Colors: Text ────────────────────────────────── */
  --atlas-color-text-primary:     #F1F5F9;   /* High contrast on dark bg */
  --atlas-color-text-secondary:   #94A3B8;   /* Muted body text */
  --atlas-color-text-tertiary:    rgba(148, 163, 184, 0.6);  /* Footnotes, timestamps (matches AtlasColor.textTertiary) */

  /* ── Colors: Border ──────────────────────────────── */
  --atlas-color-border:           rgba(241, 245, 249, 0.08);  /* Subtle (matches AtlasColor.border) */
  --atlas-color-border-emphasis:  rgba(241, 245, 249, 0.14);  /* Focus/prominent (matches AtlasColor.borderEmphasis) */

  /* ── Typography ──────────────────────────────────── */
  --atlas-font-display:           'Space Grotesk', system-ui, sans-serif;
  --atlas-font-body:              'Instrument Sans', system-ui, sans-serif;
  --atlas-font-mono:              'IBM Plex Mono', ui-monospace, monospace;

  /* Display sizes */
  --atlas-text-hero:              clamp(2.5rem, 5vw, 4rem);     /* Hero headline */
  --atlas-text-hero-weight:       700;
  --atlas-text-section:           clamp(1.75rem, 3.5vw, 2.5rem); /* Section title */
  --atlas-text-section-weight:    700;
  --atlas-text-card-title:        1.25rem;   /* 20px — card heading */
  --atlas-text-card-title-weight: 600;

  /* Body sizes (mapped from AtlasTypography) */
  --atlas-text-body:              1rem;       /* 16px — standard body */
  --atlas-text-body-weight:       400;
  --atlas-text-body-small:        0.875rem;   /* 14px — secondary body */
  --atlas-text-label:             0.875rem;   /* 14px — semibold label */
  --atlas-text-label-weight:      600;
  --atlas-text-caption:           0.75rem;    /* 12px — chips, footnotes */
  --atlas-text-caption-weight:    600;
  --atlas-text-caption-small:     0.6875rem;  /* 11px — legal, timestamps */

  /* Line heights */
  --atlas-leading-tight:          1.2;        /* Display text */
  --atlas-leading-normal:         1.6;        /* Body text */
  --atlas-leading-relaxed:        1.8;        /* Long-form reading */

  /* Letter spacing */
  --atlas-tracking-tight:         -0.02em;    /* Display */
  --atlas-tracking-normal:        0;          /* Body */
  --atlas-tracking-wide:          0.05em;     /* Overlines, badges */

  /* ── Spacing (4pt grid from AtlasSpacing) ────────── */
  --atlas-space-xxs:              4px;        /* AtlasSpacing.xxs */
  --atlas-space-xs:               6px;        /* AtlasSpacing.xs */
  --atlas-space-sm:               8px;        /* AtlasSpacing.sm */
  --atlas-space-md:               12px;       /* AtlasSpacing.md */
  --atlas-space-lg:               16px;       /* AtlasSpacing.lg */
  --atlas-space-xl:               20px;       /* AtlasSpacing.xl */
  --atlas-space-xxl:              24px;       /* AtlasSpacing.xxl */
  --atlas-space-screen-h:         28px;       /* AtlasSpacing.screenH */
  --atlas-space-section:          32px;       /* AtlasSpacing.section */

  /* Web-specific extended spacing */
  --atlas-space-section-gap:      80px;       /* Between page sections */
  --atlas-space-section-gap-lg:   120px;      /* Hero → Trust strip gap */

  /* ── Radius (continuous corners from AtlasRadius) ── */
  --atlas-radius-sm:              8px;        /* AtlasRadius.sm — chips, tags */
  --atlas-radius-md:              12px;       /* AtlasRadius.md — inline cards */
  --atlas-radius-lg:              16px;       /* AtlasRadius.lg — detail rows */
  --atlas-radius-xl:              20px;       /* AtlasRadius.xl — standard cards */
  --atlas-radius-xxl:             24px;       /* AtlasRadius.xxl — hero cards */
  --atlas-radius-full:            9999px;     /* Pills, badges, CTA buttons */

  /* ── Elevation (shadow system from AtlasElevation) ── */
  /* Flat — no shadow */
  --atlas-shadow-flat:            none;

  /* Raised — default card level */
  --atlas-shadow-raised:          0 10px 18px rgba(0, 0, 0, 0.05);
  --atlas-shadow-raised-border:   rgba(241, 245, 249, 0.08);

  /* Prominent — hero cards, primary action areas */
  --atlas-shadow-prominent:       0 16px 28px rgba(0, 0, 0, 0.09);
  --atlas-shadow-prominent-border: rgba(241, 245, 249, 0.12);

  /* CTA glow */
  --atlas-shadow-cta:             0 6px 12px rgba(20, 144, 133, 0.25);
  --atlas-shadow-cta-hover:       0 8px 20px rgba(20, 144, 133, 0.35);

  /* ── Motion (from AtlasMotion) ───────────────────── */
  --atlas-motion-fast:            150ms cubic-bezier(0.2, 0, 0, 1);    /* Hover, press */
  --atlas-motion-standard:        220ms cubic-bezier(0.2, 0, 0, 1);    /* Toggle, selection */
  --atlas-motion-slow:            350ms cubic-bezier(0.2, 0, 0, 1);    /* Page transitions */
  --atlas-motion-spring:          450ms cubic-bezier(0.34, 1.56, 0.64, 1); /* Playful feedback */

  /* Staggered section reveal */
  --atlas-stagger-delay:          80ms;       /* Delay between items in stagger */

  /* ── Layout (from AtlasLayout) ───────────────────── */
  --atlas-width-reading:          920px;      /* AtlasLayout.maxReadingWidth */
  --atlas-width-workspace:        1200px;     /* AtlasLayout.maxWorkspaceWidth */
  --atlas-width-content:          1080px;     /* AtlasLayout.maxWorkflowWidth — main content ceiling */

  /* Responsive breakpoints */
  --atlas-bp-sm:                  640px;      /* Mobile → Tablet */
  --atlas-bp-md:                  860px;      /* Matches AtlasLayout.browserSplitThreshold */
  --atlas-bp-lg:                  1080px;     /* Tablet → Desktop */
  --atlas-bp-xl:                  1280px;     /* Wide desktop */
}
```

### 6.3 Five-Dimension Design Decisions

| Dimension | Decision | Rationale |
|-----------|----------|-----------|
| **Color** | Dark-only graphite base (#0D0F11) with teal brand (#149085) and mint accent (#34D399) | PRD specifies "graphite/near-black" background; teal carries trust; mint provides discovery cues without clashing |
| **Typography** | Space Grotesk (display) + Instrument Sans (body) + IBM Plex Mono (utility) | Geometric display for tech authority; humanist sans for readability; monospace for version/code credibility |
| **Spacing** | 80px section gap, 4pt internal grid, max 1080px content width | Generous whitespace per PRD "not crowded"; 4pt grid matches native app; reading width prevents long lines |
| **Shape** | Continuous corners (8–24px radius scale), capsule CTAs, no sharp edges | Maps directly from `AtlasRadius`; "rounded but not bubbly" per PRD; capsule CTAs match `AtlasPrimaryButtonStyle` |
| **Motion** | Staggered section reveal on scroll, 150ms hover transitions, no decorative loops | PRD: "snappy but never bouncy"; intersection observer triggers for progressive reveal; respects `prefers-reduced-motion` |

### 6.4 Section Band Pattern

The page alternates between "dark" and "surface" bands to create visual rhythm:

```
  Section              Background                 Band
  ─────────────────────────────────────────────────────
  NavBar               transparent → bg-base       —
  Hero                 bg-base                     Dark
  Trust Strip          bg-surface                  Surface
  Problem → Outcome    bg-base                     Dark
  Feature Grid         bg-surface                  Surface
  How It Works         bg-base                     Dark
  Developer Section    bg-surface                  Surface
  Safety Section       bg-base                     Dark
  Screenshot Gallery   bg-surface                  Surface
  Open Source          bg-base                     Dark
  FAQ                  bg-surface                  Surface
  Footer               bg-base + border-top        Dark
```

### 6.5 Component Styling Convention

**BEM-lite + CSS custom properties**:

```css
/* Block */
.hero { ... }

/* Element */
.hero__headline { ... }
.hero__cta { ... }

/* Modifier */
.hero__cta--primary { ... }
.hero__cta--secondary { ... }
```

**Card pattern** (maps from `AtlasCardModifier`):

```css
.card {
  padding: var(--atlas-space-xl);                    /* 20px — AtlasSpacing.xl */
  background: var(--atlas-color-bg-surface);
  border: 1px solid var(--atlas-color-border);       /* 0.08 opacity */
  border-radius: var(--atlas-radius-xl);             /* 20px — AtlasRadius.xl */
  box-shadow: var(--atlas-shadow-raised);            /* 0 10px 18px */
  transition: transform var(--atlas-motion-fast),
              box-shadow var(--atlas-motion-fast);
}

.card:hover {
  transform: scale(1.008);                           /* Matches AtlasHoverModifier */
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.08);
}

.card--prominent {
  border-radius: var(--atlas-radius-xxl);            /* 24px — AtlasRadius.xxl */
  border-width: 1.5px;
  border-color: var(--atlas-shadow-prominent-border);
  box-shadow: var(--atlas-shadow-prominent);
  background:
    linear-gradient(135deg, rgba(255,255,255,0.08) 0%, transparent 50%),
    var(--atlas-color-bg-surface);                   /* Top-left inner glow */
}
```

**CTA button pattern** (maps from `AtlasPrimaryButtonStyle`):

```css
.cta--primary {
  font-family: var(--atlas-font-body);
  font-size: var(--atlas-text-label);
  font-weight: var(--atlas-text-label-weight);
  color: #FFFFFF;
  padding: var(--atlas-space-md) var(--atlas-space-xxl);  /* 12px 24px */
  background: var(--atlas-color-brand);
  border-radius: var(--atlas-radius-full);                /* Capsule */
  box-shadow: var(--atlas-shadow-cta);
  transition: transform var(--atlas-motion-fast),
              box-shadow var(--atlas-motion-fast);
  cursor: pointer;
  border: none;
}

.cta--primary:hover {
  box-shadow: var(--atlas-shadow-cta-hover);
  transform: translateY(-1px);
}

.cta--primary:active {
  transform: scale(0.97);
  box-shadow: 0 2px 4px rgba(20, 144, 133, 0.15);
}

.cta--primary:disabled {
  background: rgba(20, 144, 133, 0.4);
  cursor: not-allowed;
  box-shadow: none;
}
```

**Badge pattern** (channel badge):

```css
.badge {
  font-family: var(--atlas-font-mono);
  font-size: var(--atlas-text-caption);
  font-weight: var(--atlas-text-caption-weight);
  letter-spacing: var(--atlas-tracking-wide);
  text-transform: uppercase;
  padding: var(--atlas-space-xxs) var(--atlas-space-sm);
  border-radius: var(--atlas-radius-sm);
}

.badge--stable {
  background: rgba(20, 144, 133, 0.15);
  color: var(--atlas-color-accent);
  border: 1px solid rgba(20, 144, 133, 0.3);
}

.badge--prerelease {
  background: rgba(245, 158, 11, 0.15);
  color: var(--atlas-color-warning);
  border: 1px solid rgba(245, 158, 11, 0.3);
}

.badge--coming {
  background: rgba(148, 163, 184, 0.1);
  color: var(--atlas-color-text-secondary);
  border: 1px solid rgba(148, 163, 184, 0.2);
}
```

### 6.6 Responsive Strategy

| Breakpoint | Layout Behavior |
|------------|----------------|
| < 640px (mobile) | Single column; hero screenshot below CTA; feature cards stack; screenshot carousel; hamburger nav |
| 640–860px (tablet) | Two-column feature grid; hero screenshot beside text; nav items visible |
| 860–1080px (small desktop) | Three-column feature grid; full nav; gallery grid |
| > 1080px (desktop) | Max content width 1080px centered; generous margins |

### 6.7 Font Loading Strategy

```css
@font-face {
  font-family: 'Space Grotesk';
  src: url('/fonts/SpaceGrotesk-Bold.woff2') format('woff2');
  font-weight: 700;
  font-display: swap;
  unicode-range: U+0000-024F, U+4E00-9FFF; /* Latin + CJK */
}

@font-face {
  font-family: 'Instrument Sans';
  src: url('/fonts/InstrumentSans-Regular.woff2') format('woff2');
  font-weight: 400;
  font-display: swap;
  unicode-range: U+0000-024F, U+4E00-9FFF;
}

/* ... additional faces for Medium weights and IBM Plex Mono */
```

Preload critical fonts in `<head>`:

```html
<link rel="preload" href="/fonts/SpaceGrotesk-Bold.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/InstrumentSans-Regular.woff2" as="font" type="font/woff2" crossorigin>
```

---

## 7. Quality Gates

### 7.1 Core Web Vitals

| Metric | Target | Tool |
|--------|--------|------|
| Largest Contentful Paint (LCP) | < 2.0s | Lighthouse CI |
| Interaction to Next Paint (INP) | < 100ms | Lighthouse CI |
| Cumulative Layout Shift (CLS) | < 0.05 | Lighthouse CI |
| Lighthouse Performance Score | >= 95 | Lighthouse CI |
| Lighthouse Accessibility Score | >= 95 | Lighthouse CI |
| Lighthouse Best Practices Score | >= 95 | Lighthouse CI |
| Lighthouse SEO Score | >= 95 | Lighthouse CI |
| Total Client JS | < 20KB (gzip) | Build output check |
| Total Page Weight | < 500KB (excl. screenshots) | Build output check |

### 7.2 Accessibility (WCAG 2.1 AA)

| Check | Requirement |
|-------|-------------|
| Color contrast | 4.5:1 minimum for normal text; 3:1 for large text (>= 18px bold / >= 24px) |
| Keyboard navigation | All interactive elements focusable; visible focus ring; logical tab order |
| Screen reader | Semantic HTML (`<nav>`, `<main>`, `<section>`, `<article>`); ARIA labels where needed |
| Alt text | Every `<img>` has descriptive alt text; decorative images use `alt=""` |
| Reduced motion | `@media (prefers-reduced-motion: reduce)` disables all animations |
| Language | `<html lang="zh-Hans">` / `<html lang="en">` set per locale |

### 7.3 CI Pipeline

**File**: `.github/workflows/landing-page.yml`

```yaml
name: Landing Page

on:
  push:
    paths:
      - 'Apps/LandingSite/**'
    branches: [main]
  release:
    types: [published]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
          cache-dependency-path: Apps/LandingSite/pnpm-lock.yaml

      - name: Install dependencies
        working-directory: Apps/LandingSite
        run: pnpm install --frozen-lockfile

      - name: Fetch release manifest
        working-directory: Apps/LandingSite
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: pnpm run fetch-release

      - name: Build static site
        working-directory: Apps/LandingSite
        run: pnpm run build

      - name: Validate HTML
        working-directory: Apps/LandingSite
        run: pnpm run validate

      - name: Run Lighthouse CI
        working-directory: Apps/LandingSite
        run: pnpm run lighthouse

      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: Apps/LandingSite/dist

  deploy:
    name: Deploy
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

**Trigger conditions**:
1. Push to `main` that modifies `Apps/LandingSite/**`
2. GitHub Release publication (triggers manifest regeneration)
3. Manual dispatch for ad-hoc deploys

### 7.4 Acceptance Criteria → PRD Traceability

| FR | Requirement | How Addressed |
|----|-------------|---------------|
| FR-01 | Release metadata (version, channel, date, asset links) | `ReleaseManifest` schema (§3.1); Hero + Footer render from manifest; build-time fetch |
| FR-02 | Channel-aware UI (prerelease badge, warning, Gatekeeper help) | `ChannelBadge` component; release state machine (§1.3); SafetySection Gatekeeper guide |
| FR-03 | Bilingual support (EN + ZH, stable URLs) | Path-based i18n (`/en/`, `/zh/`); `LandingCopy` schema (§3.2); `hreflang` tags (A-07) |
| FR-04 | Download path clarity (where, which file, prerelease, Gatekeeper) | Hero CTA links to correct asset; ChannelBadge shows state; SafetySection explains Gatekeeper |
| FR-05 | Trust links (GitHub, releases, changelog, security, license) | OpenSourceSection + FooterSection; links derived from constants |
| FR-06 | Optional beta email capture | Deferred to 3rd-party form endpoint slot in FooterSection; no custom backend |
| FR-07 | Responsive behavior (desktop, tablet, mobile) | Responsive strategy (§6.6); breakpoints at 640/860/1080px; no CTA hidden in accordion |

### 7.5 User Story → Verification

| Story | Test |
|-------|------|
| US-01: Understand Atlas in one screen | Lighthouse "First Meaningful Paint" check; manual review that headline + subheadline + screenshot are above the fold on 1280×720 viewport |
| US-02: Safety and trust signals | Automated check: TrustStrip rendered; SafetySection contains "recovery", "permissions", "Gatekeeper" keywords; OpenSourceSection links to GitHub |
| US-03: Developer cleanup awareness | DeveloperSection renders with >= 4 concrete developer artifact types (Xcode derived data, simulators, package caches, build artifacts) |
| US-04: Download without GitHub navigation | Hero CTA `href` matches `release-manifest.json` asset URL; version and date rendered next to CTA |
| US-05: Honest prerelease disclosure | When `channel === "prerelease"`: ChannelBadge shows amber "Prerelease" badge; warning text visible; Gatekeeper "Open Anyway" steps visible |

### 7.6 Pre-Deploy Checklist

- [ ] `pnpm run build` succeeds with zero warnings
- [ ] `release-manifest.json` is valid and matches latest GitHub Release
- [ ] Both `/en/` and `/zh/` render without missing translation keys
- [ ] Lighthouse scores >= 95 on all four categories for both locales
- [ ] All images have alt text; screenshots have descriptive captions
- [ ] `hreflang` tags present and correct on both locale pages
- [ ] Open Graph meta tags render correct title, description, and image per locale
- [ ] No `Mole` brand references in rendered HTML
- [ ] Client JS budget < 20KB confirmed via build output
- [ ] `robots.txt` and `sitemap.xml` present and valid
- [ ] Custom domain DNS verified and HTTPS enforced
- [ ] Plausible analytics tracking confirmed on both locales
- [ ] Mobile viewport (375px) preserves CTA visibility and screenshot clarity
