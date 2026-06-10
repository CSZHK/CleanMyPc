#!/usr/bin/env node
// WCAG AA contrast gate for Calm Ledger tokens.
// Usage: node scripts/design/contrast-check.mjs   (exit 1 on any failure)
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)));
const manifest = JSON.parse(readFileSync(join(root, "calm-ledger-tokens.json"), "utf8"));

function srgb(hex) {
  const h = hex.replace("#", "");
  const v = (i) => parseInt(h.slice(i, i + 2), 16) / 255;
  return [v(0), v(2), v(4)]; // alpha (if present) ignored: gate checks opaque pairs only
}
function luminance(hex) {
  const lin = srgb(hex).map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}
function ratio(fg, bg) {
  const [l1, l2] = [luminance(fg), luminance(bg)].sort((a, b) => b - a);
  return (l1 + 0.05) / (l2 + 0.05);
}

let failures = 0;
for (const pair of manifest.contrastPairs) {
  for (const mode of ["light", "dark"]) {
    const fg = manifest.colors[pair.fg]?.[mode];
    const bg = manifest.colors[pair.bg]?.[mode];
    if (!fg || !bg) { console.error(`MISSING token: ${pair.fg} or ${pair.bg} (${mode})`); failures++; continue; }
    const r = ratio(fg, bg);
    const ok = r >= pair.min;
    if (!ok) failures++;
    console.log(`${ok ? "PASS" : "FAIL"}  [${mode}] ${pair.fg} on ${pair.bg}  ${r.toFixed(2)}:1  (min ${pair.min})`);
  }
}
if (failures > 0) { console.error(`\n${failures} failure(s)`); process.exit(1); }
console.log("\nALL PASS");
