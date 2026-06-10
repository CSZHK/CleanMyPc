#!/usr/bin/env node
// Generates .colorset bundles from calm-ledger-tokens.json. Idempotent.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(readFileSync(join(here, "calm-ledger-tokens.json"), "utf8"));
const xcassets = join(here, "../../Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Resources/AtlasColors.xcassets");

function components(hex) {
  if (!/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(hex)) {
    throw new Error(`invalid hex "${hex}" — must be #RRGGBB or #RRGGBBAA`);
  }
  const h = hex.replace("#", "");
  const c = (i) => (parseInt(h.slice(i, i + 2), 16) / 255).toFixed(10);
  const alpha = h.length === 8 ? (parseInt(h.slice(6, 8), 16) / 255).toFixed(10) : "1.0000000000";
  return { red: c(0), green: c(2), blue: c(4), alpha };
}
function entry(appearanceValue, hex) {
  return {
    idiom: "universal",
    appearances: [{ appearance: "luminosity", value: appearanceValue }],
    color: { "color-space": "srgb", components: components(hex) },
  };
}
// Note: generator never deletes — renaming/removing a manifest token leaves an orphan colorset; reconcile manually (see M4 plan).
for (const [name, modes] of Object.entries(manifest.colors)) {
  const dir = join(xcassets, `${name}.colorset`);
  mkdirSync(dir, { recursive: true });
  const json = {
    colors: [entry("light", modes.light), entry("dark", modes.dark)],
    info: { author: "xcode", version: 1 },
  };
  writeFileSync(join(dir, "Contents.json"), JSON.stringify(json, null, 2) + "\n");
  console.log(`wrote ${name}.colorset`);
}
console.log(`\n${Object.keys(manifest.colors).length} colorsets generated`);
