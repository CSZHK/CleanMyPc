# Landing Page PRD — 2026-03-14

## Summary

- Product: `Atlas for Mac` landing page
- Type: marketing site + release-distribution entry
- Primary goal: turn qualified visitors into `download`, `GitHub visit/star`, and `beta updates` conversions
- Deployment baseline: `GitHub Pages` with a custom domain and GitHub Actions deployment workflow
- Recommended source location at implementation time: `Apps/LandingSite/`

This PRD is intentionally separate from the core app MVP PRD. It does not change the frozen app-module scope. It defines a branded acquisition and trust surface for direct distribution.

## Background

Atlas for Mac now has a usable direct-distribution path, GitHub Releases, packaging automation, and prerelease support. What it does not yet have is a purpose-built landing page that:

- explains the product quickly to first-time visitors
- distinguishes signed releases from prereleases honestly
- reduces fear around cleanup, permissions, and Gatekeeper warnings
- converts open-source interest into actual downloads
- gives the project a canonical domain instead of relying on the repository README alone

The landing page must behave like a launch surface, not a generic OSS README mirror.

## Goals

- Present Atlas as a modern, trust-first Mac utility, not a vague “cleaner”
- Clarify the product promise in under 10 seconds
- Make direct download, GitHub proof, and safety signals visible above the fold
- Support both `English` and `简体中文`
- Explain prerelease installation honestly when Apple-signed distribution is unavailable
- Provide a stable deployment path on GitHub with a separately managed custom domain
- Stay lightweight, static-first, and easy to maintain by a small team

## Non-Goals

- No full documentation portal in v1
- No in-browser disk scan demo
- No account system
- No pricing or checkout flow in v1
- No blog/CMS dependency required for initial launch
- No analytics stack that requires invasive tracking cookies by default

## Target Users

### Primary

- Mac users with recurring disk pressure or system clutter
- Developers with Xcode, simulators, containers, caches, package-manager artifacts, and build leftovers
- Users evaluating alternatives to opaque commercial cleanup apps

### Secondary

- Open-source-oriented users who want to inspect the code before installing
- Tech creators and reviewers looking for screenshots, positioning, and trust signals
- Early beta testers willing to tolerate prerelease install friction

## User Jobs

- “Tell me what Atlas actually does in one screen.”
- “Help me decide whether this is safe enough to install.”
- “Show me how Atlas is different from aggressive one-click cleaners.”
- “Let me download the latest build without digging through GitHub.”
- “Explain whether this is a signed release or a prerelease before I install.”

## Positioning

### Core Positioning Statement

Atlas for Mac is an explainable, recovery-first Mac maintenance workspace that helps people understand why their Mac is slow, full, or disorganized, then take safer action.

### Core Differentiators To Surface

- `Explainable` instead of opaque
- `Recovery-first` instead of destructive-by-default
- `Developer-aware` instead of mainstream-only cleanup
- `Open source` instead of black-box utility
- `Least-privilege` instead of front-loaded permission pressure

### Messaging Constraints

- Do not use the `Mole` brand in user-facing naming
- Do not claim malware protection or antivirus behavior
- Do not overstate physical recovery coverage
- Do not imply that all releases are Apple-signed if they are not

## Success Metrics

### Primary Metrics

- Landing-page visitor to download CTA click-through rate
- Download CTA click to GitHub Release visit rate
- Stable-release vs prerelease download split
- GitHub repo visit/star rate from the landing page
- Beta updates signup conversion rate if email capture ships

### Secondary Metrics

- Time on page
- Scroll depth to trust/safety section
- Screenshot gallery interaction rate
- FAQ expansion rate
- Core Web Vitals pass rate

## Release and Distribution Strategy

The page must treat release channel status as product truth, not as hidden implementation detail.

### Required States

- `Signed Release Available`
- `Prerelease Only`
- `No Public Download Yet`

### CTA Behavior

- If a signed stable release exists: primary CTA is `Download for macOS`
- If only prerelease exists: primary CTA is `Download Prerelease`, with an explicit warning label
- If no downloadable release exists: primary CTA becomes `View on GitHub` or `Join Beta Updates`

### Required Disclosure

- Show exact version number and release date
- Show channel badge: `Stable`, `Prerelease`, or `Internal Beta`
- Show a short install note if the selected asset may trigger Gatekeeper friction

## Information Architecture

The landing page should be a single-scroll page with anchored sections and a sticky top nav.

### Top Navigation

- Logo / wordmark
- `Why Atlas`
- `How It Works`
- `Developers`
- `Safety`
- `FAQ`
- language toggle
- primary CTA

### Page Sections

#### 1. Hero

- Purpose: make the product understandable immediately
- Content:
  - strong product headline
  - short subheadline
  - primary CTA
  - secondary CTA to GitHub
  - release-state badge
  - macOS screenshot or stylized product frame
- Copy angle:
  - “Understand what’s taking space”
  - “Review before cleaning”
  - “Recover when supported”

#### 2. Trust Signal Strip

- Open source
- Recovery-first
- Developer-aware cleanup
- macOS native workspace
- Direct download / GitHub Releases

#### 3. Problem-to-Outcome Narrative

- “Mac is full” -> Atlas explains why
- “Caches and leftovers are unclear” -> Atlas turns findings into an action plan
- “Cleanup feels risky” -> Atlas emphasizes reversibility and history

#### 4. Feature Story Grid

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`

Each card must show:

- user-facing value
- one concrete example
- one trust cue

#### 5. How It Works

- Scan
- Review plan
- Execute safe actions
- Restore when supported

This section should visualize the workflow as a clear four-step progression.

#### 6. Developer Cleanup Section

- Xcode derived data
- simulators
- package manager caches
- build artifacts
- developer-oriented disk pressure scenarios

This section exists because developer cleanup coverage is one of Atlas’s most differentiated acquisition angles.

#### 7. Safety and Permissions Section

- explain least-privilege behavior
- explain why Atlas does not request everything up front
- explain release channel status honestly
- include the prerelease Gatekeeper warning visual when relevant

#### 8. Screenshots / Product Tour

- 4 to 6 macOS screenshots
- captions tied to user outcomes, not just feature names
- desktop-first layout with mobile fallback carousel

#### 9. Open Source and Credibility

- GitHub repo link
- MIT license
- attribution statement
- optional changelog/release notes links

#### 10. FAQ

- Is Atlas signed and notarized?
- What happens in prerelease installs?
- Does Atlas upload my files?
- What does recovery actually mean?
- Does Atlas require Full Disk Access?
- Is this a Mac App Store app?

#### 11. Footer

- download links
- GitHub
- documentation
- privacy statement
- security contact

## Functional Requirements

### FR-01 Release Metadata

The page must display:

- latest downloadable version
- release channel
- published date
- links to `.dmg`, `.zip`, `.pkg` or the GitHub release page

### FR-02 Channel-Aware UI

If the latest downloadable build is a prerelease, the UI must:

- display a `Prerelease` badge above the primary CTA
- show a short warning near the CTA
- expose a help path for Gatekeeper friction

### FR-03 Bilingual Support

The page must support `English` and `简体中文` with:

- manual language switch
- stable URL strategy or query/path handling
- localized metadata where feasible

### FR-04 Download Path Clarity

Users must be able to tell:

- where to download
- which file is recommended
- whether they are installing a prerelease
- what to do if macOS blocks the app

### FR-05 Trust Links

The page must link to:

- GitHub repository
- GitHub Releases
- changelog or release notes
- security disclosure path
- open-source attribution / license references

### FR-06 Optional Beta Updates Capture

The page should support an optional email capture block using a third-party form endpoint or mailing-list provider without introducing a custom backend in v1.

### FR-07 Responsive Behavior

The experience must work on:

- desktop
- iPad/tablet portrait
- mobile phones

No critical CTA or release information may fall below inaccessible accordion depth on mobile.

## Visual Direction

### Design Theme

`Precision Utility`

The page should feel like a modern macOS-native operations console translated into a polished marketing surface. It should avoid generic SaaS gradients, purple-heavy palettes, and interchangeable startup layouts.

### Visual Principles

- clean but not sterile
- high trust over hype
- native Mac feel over abstract Web3-style spectacle
- strong hierarchy over crowded feature dumping
- product screenshots as proof, not decoration

### Typography

- Display: `Space Grotesk`
- Body: `Instrument Sans`
- Utility / telemetry labels: `IBM Plex Mono`

### Color System

- Background base: graphite / near-black
- Surface: warm slate cards
- Primary accent: mint-teal
- Secondary accent: cold cyan
- Support accent: controlled amber for caution or prerelease states

### Layout Style

- strong hero with diagonal or staggered composition
- large product framing device
- generous spacing
- rounded but not bubbly surfaces
- visual rhythm built from alternating dark/light emphasis bands

### Motion

- staggered section reveal on first load
- subtle screenshot parallax only if performance budget permits
- badge/CTA hover states with restrained motion
- no endless floating particles or decorative loops

## Copy Direction

- tone: direct, calm, technically credible
- avoid hype words like “ultimate”, “magic”, or “AI cleaner”
- prefer concrete verbs: `Scan`, `Review`, `Restore`, `Download`
- always qualify prerelease or unsigned friction honestly

## SEO Requirements

- page title and meta description in both supported languages
- Open Graph and Twitter card metadata
- software-application structured data
- canonical URL
- `hreflang` support if separate localized URLs are used
- crawlable, text-based headings; no hero text rendered only inside images

## Analytics Requirements

Use privacy-respecting analytics by default.

### Required Events

- primary CTA click
- GitHub CTA click
- release file choice click
- FAQ expand
- screenshot gallery interaction
- beta signup submit

### Recommended Stack

- `Plausible` or `Umami`
- Google Search Console for indexing and query monitoring

## Technical and Deployment Requirements

### Hosting

- Use `GitHub Pages`
- Deploy via `GitHub Actions` custom workflow
- Keep the site static-first

### Recommended Workflow

Build job:

- install dependencies
- build static output
- upload Pages artifact

Deploy job:

- use `actions/deploy-pages`
- grant `pages: write` and `id-token: write`
- publish to the `github-pages` environment

This aligns with GitHub’s current Pages guidance for custom workflows and deployment permissions.

### Custom Domain Strategy

- Use a dedicated brand domain
- Prefer `www` as canonical host
- Redirect apex to `www` or configure both correctly
- Verify the domain at the GitHub account or organization level before binding it to the repository
- Enforce HTTPS after DNS propagation
- Do not use wildcard DNS
- Do not rely on a manually committed `CNAME` file when using a custom GitHub Actions Pages workflow

### DNS Requirements

For `www`:

- configure `CNAME` -> `<account>.github.io`

For apex:

- use `A`/`AAAA` records or `ALIAS/ANAME` according to GitHub Pages documentation

### Repository Integration

- Source should live in this repository under `Apps/LandingSite/`
- Landing page deployment should not interfere with app release workflows
- Landing page builds should trigger on landing-page source changes and optionally on GitHub Release publication

### Release Integration

The landing page should not depend on client-side GitHub API fetches for critical first-paint release messaging if it can be avoided. Preferred order:

1. build-time generated release manifest
2. static embedded release metadata
3. client-side GitHub API fetch as fallback

## Recommended MVP Scope

### Included

- one bilingual single-page site
- responsive hero
- feature story sections
- screenshot gallery
- trust/safety section
- FAQ
- dynamic release state block
- GitHub Pages deployment
- custom domain binding
- privacy-respecting analytics

### Deferred

- blog
- changelog microsite
- testimonials from named users
- interactive benchmark calculator
- gated PDF lead magnet
- multi-page docs hub

## Acceptance Criteria

- A first-time visitor can understand Atlas in under 10 seconds from the hero
- The page clearly distinguishes `Stable` vs `Prerelease`
- A prerelease visitor can discover the `Open Anyway` recovery path without leaving the page confused
- The site is deployable from GitHub to a custom domain with HTTPS
- Desktop and mobile layouts preserve screenshot clarity and CTA visibility
- The page links cleanly to GitHub Releases and the repository
- Language switching works without broken layout or missing content

## Delivery Plan

### Phase 1

- finalize PRD
- confirm domain choice
- confirm release CTA policy for prerelease vs stable

### Phase 2

- design mock or coded prototype
- implement static site in `Apps/LandingSite/`
- add GitHub Pages workflow

### Phase 3

- bind custom domain
- enable HTTPS
- add analytics and search-console verification
- run launch QA on desktop and mobile

## Risks

- The site may overpromise signed-distribution status if release metadata is not surfaced dynamically
- GitHub Pages custom-domain misconfiguration can create HTTPS or takeover risk
- A generic SaaS aesthetic would dilute Atlas’s product differentiation
- Screenshots can become stale if app UI evolves faster than site updates
- Email capture can add privacy or maintenance overhead if introduced too early

## Open Questions

- Should the canonical domain be a product-only brand domain or a broader studio-owned domain path?
- Should prerelease downloads be direct asset links or always route through the GitHub Release page first?
- Is email capture required for v1, or is GitHub + download conversion sufficient?
- Should bilingual content use one URL with client-side switching or separate localized routes?
