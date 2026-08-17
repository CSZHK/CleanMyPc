import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://atlas.atomstorm.ai',
  output: 'static',
  // The bare root is a redirect stub with no content of its own (see
  // src/pages/index.astro). Listing it in the sitemap asks Google to index an
  // empty page, so only the real locale pages are submitted.
  integrations: [sitemap({ filter: (page) => page !== 'https://atlas.atomstorm.ai/' })],
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
