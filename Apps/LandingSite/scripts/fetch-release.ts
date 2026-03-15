/**
 * Build-time script: Fetches latest release from GitHub API
 * and writes release-manifest.json for the landing page.
 *
 * Usage: tsx scripts/fetch-release.ts
 * Env: GITHUB_TOKEN (optional, increases rate limit)
 */

import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const OWNER = 'nicekid1';
const REPO = 'CleanMyPc';
const OUTPUT = join(__dirname, '..', 'src', 'data', 'release-manifest.json');

interface ReleaseManifest {
  channel: 'stable' | 'prerelease' | 'none';
  version: string | null;
  publishedAt: string | null;
  releaseUrl: string | null;
  assets: {
    dmg: string | null;
    zip: string | null;
    pkg: string | null;
    sha256: string | null;
  };
  gatekeeperWarning: boolean;
  installNote: string | null;
  tagName: string | null;
  generatedAt: string;
}

function findAsset(assets: any[], suffix: string): string | null {
  const asset = assets.find((a: any) =>
    a.name.toLowerCase().endsWith(suffix.toLowerCase())
  );
  return asset?.browser_download_url ?? null;
}

async function fetchRelease(): Promise<ReleaseManifest> {
  const headers: Record<string, string> = {
    Accept: 'application/vnd.github.v3+json',
    'User-Agent': 'atlas-landing-build',
  };

  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  // Try latest release first, then fall back to all releases
  let release: any = null;

  try {
    const latestRes = await fetch(
      `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`,
      { headers }
    );

    if (latestRes.ok) {
      release = await latestRes.json();
    }
  } catch {
    // Ignore — try all releases next
  }

  if (!release) {
    try {
      const allRes = await fetch(
        `https://api.github.com/repos/${OWNER}/${REPO}/releases?per_page=5`,
        { headers }
      );

      if (allRes.ok) {
        const releases = await allRes.json();
        if (Array.isArray(releases) && releases.length > 0) {
          release = releases[0];
        }
      }
    } catch {
      // Will return "none" channel
    }
  }

  if (!release) {
    return {
      channel: 'none',
      version: null,
      publishedAt: null,
      releaseUrl: `https://github.com/${OWNER}/${REPO}`,
      assets: { dmg: null, zip: null, pkg: null, sha256: null },
      gatekeeperWarning: false,
      installNote: null,
      tagName: null,
      generatedAt: new Date().toISOString(),
    };
  }

  const isPrerelease = release.prerelease === true;
  const version = (release.tag_name ?? '').replace(/^V/i, '') || null;
  const assets = release.assets ?? [];

  return {
    channel: isPrerelease ? 'prerelease' : 'stable',
    version,
    publishedAt: release.published_at ?? null,
    releaseUrl: release.html_url ?? `https://github.com/${OWNER}/${REPO}/releases`,
    assets: {
      dmg: findAsset(assets, '.dmg'),
      zip: findAsset(assets, '.zip'),
      pkg: findAsset(assets, '.pkg'),
      sha256: findAsset(assets, '.sha256'),
    },
    gatekeeperWarning: isPrerelease,
    installNote: isPrerelease
      ? 'This build is development-signed. macOS Gatekeeper may require "Open Anyway" or a right-click "Open" flow.'
      : null,
    tagName: release.tag_name ?? null,
    generatedAt: new Date().toISOString(),
  };
}

async function main() {
  console.log(`Fetching release data for ${OWNER}/${REPO}...`);

  try {
    const manifest = await fetchRelease();
    writeFileSync(OUTPUT, JSON.stringify(manifest, null, 2) + '\n');
    console.log(`Wrote ${OUTPUT}`);
    console.log(`  channel: ${manifest.channel}`);
    console.log(`  version: ${manifest.version ?? '(none)'}`);
    console.log(`  gatekeeperWarning: ${manifest.gatekeeperWarning}`);
  } catch (err) {
    console.error('Failed to fetch release, using fallback:', err);
    // The build will use release-fallback.json via the data loader
    process.exit(0); // Don't fail the build
  }
}

main();
