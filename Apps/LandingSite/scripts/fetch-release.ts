/**
 * Build-time script: Fetches latest release from GitHub API
 * and writes release-manifest.json for the landing page.
 *
 * Usage: tsx scripts/fetch-release.ts
 * Env: GITHUB_TOKEN (optional, increases rate limit)
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const OWNER = 'CSZHK';
const REPO = 'CleanMyPc';

/**
 * 静态兜底不得钉住任何具体 release —— 构建期硬门。
 *
 * 为什么需要这条守卫：`release-fallback.json` 是**人工维护**的静态文件，
 * 只在 GitHub API 取数失败时被渲染。一个钉住版本号的兜底**必然漂移** ——
 * 实测它曾停在 `1.0.3`，而 App 已发布 `2.1.0`（落后三个版本）；
 * 同一时刻 `release-manifest.json` 缓存里还留着 `1.30.0`。
 *
 * UI 侧已能优雅降级（已实测）：
 *   - `ChannelBadge.astro:15` 与 `Hero.astro:88` 都以 `{version && …}` 守卫
 *   - `getDownloadUrl()` 在 assets 全空时回落到 `releaseUrl`（releases 页）
 * 所以把这几个字段留空**不会**让页面出问题，只会显示「预发布版」徽章 +
 * 指向 releases 页的下载入口 —— 这才是取数失败时该有的诚实降级。
 *
 * 该字段一旦被写回具体值即 exit 1，prebuild 会因此失败。
 */
function assertFallbackIsVersionAgnostic(): void {
  const fallbackPath = join(__dirname, '..', 'src', 'data', 'release-fallback.json');
  let fallback: Record<string, unknown>;
  try {
    fallback = JSON.parse(readFileSync(fallbackPath, 'utf8'));
  } catch (err) {
    console.error(`Could not parse ${fallbackPath}: ${String(err)}`);
    process.exit(1);
  }

  const pinned: string[] = [];
  for (const field of ['version', 'tagName', 'publishedAt'] as const) {
    if (fallback[field] !== null) {
      pinned.push(`  - ${field} = ${JSON.stringify(fallback[field])} (must be null)`);
    }
  }
  if (pinned.length > 0) {
    console.error('release-fallback.json must stay version-agnostic, but pins a release:');
    for (const line of pinned) console.error(line);
    console.error('  This file is hand-maintained and only shown when the GitHub API call');
    console.error('  fails, so any pinned value goes stale silently. Leave these null.');
    process.exit(1);
  }
}
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
  assertFallbackIsVersionAgnostic();
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
