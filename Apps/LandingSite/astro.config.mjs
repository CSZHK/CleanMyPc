import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// Single source for the deployed origin: `site` and the sitemap filter must
// agree, and a hard-coded literal in the filter would silently stop matching
// if this ever moves (staging origin, domain change) — putting the stub back
// into the sitemap with no failing signal.
const SITE = 'https://atlas.atomstorm.ai';

export default defineConfig({
  site: SITE,
  output: 'static',
  // The bare root is a redirect stub with no content of its own (see
  // src/pages/index.astro). Listing it in the sitemap asks Google to index an
  // empty page, so only the real locale pages are submitted.
  integrations: [sitemap({ filter: (page) => page !== `${SITE}/` })],
  i18n: {
    defaultLocale: 'zh',
    locales: ['zh', 'en'],
    routing: {
      prefixDefaultLocale: true,
      redirectToDefaultLocale: false,
    },
  },
  build: {
    assets: '_assets',
  },
});
