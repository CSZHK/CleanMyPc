/**
 * Release manifest loader.
 * Tries build-time generated manifest first, then falls back to static fallback.
 */

export interface ReleaseManifest {
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

let cached: ReleaseManifest | null = null;

export function getRelease(): ReleaseManifest {
  if (cached) return cached;

  try {
    // Try build-time generated manifest first
    const manifest = import.meta.glob('./release-manifest.json', { eager: true });
    const key = Object.keys(manifest)[0];
    if (key) {
      cached = (manifest[key] as any).default as ReleaseManifest;
      return cached;
    }
  } catch {
    // Fall through to fallback
  }

  // Use static fallback
  const fallback = import.meta.glob('./release-fallback.json', { eager: true });
  const key = Object.keys(fallback)[0];
  cached = (fallback[key] as any).default as ReleaseManifest;
  return cached;
}

export function getDownloadUrl(manifest: ReleaseManifest): string {
  // Prefer DMG > ZIP > PKG > release page
  return (
    manifest.assets.dmg ??
    manifest.assets.zip ??
    manifest.assets.pkg ??
    manifest.releaseUrl ??
    'https://github.com/nicekid1/CleanMyPc/releases'
  );
}

export function formatDate(iso: string | null, locale: string): string {
  if (!iso) return '';
  try {
    const date = new Date(iso);
    return date.toLocaleDateString(locale === 'zh' ? 'zh-CN' : 'en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return '';
  }
}
