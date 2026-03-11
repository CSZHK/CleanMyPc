#!/usr/bin/env python3
"""
Atlas for Mac — App Icon Generator

Brand: Calm Authority
Concept: A stylized globe with meridian lines overlaid on a deep-teal-to-emerald
gradient, with a darker premium backdrop and a refined mint accent arc representing the "atlas" mapping metaphor.

Generates all required macOS app icon sizes from a programmatic SVG.
"""

import subprocess
import os
import json
import tempfile

ICON_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Apps", "AtlasApp", "Sources", "AtlasApp", "Assets.xcassets", "AppIcon.appiconset"
)

# macOS icon sizes needed
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def generate_svg(size=1024):
    """Generate the Atlas app icon as SVG."""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">
  <defs>
    <!-- Brand gradient: darker premium teal to deep emerald -->
    <linearGradient id="bgGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#031B1A"/>
      <stop offset="50%" stop-color="#0A5C56"/>
      <stop offset="100%" stop-color="#073936"/>
    </linearGradient>

    <!-- Inner glow from top-left -->
    <radialGradient id="innerGlow" cx="0.3" cy="0.25" r="0.7">
      <stop offset="0%" stop-color="#D1FAE5" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="white" stop-opacity="0"/>
    </radialGradient>

    <!-- Globe gradient -->
    <radialGradient id="globeGrad" cx="0.4" cy="0.35" r="0.55">
      <stop offset="0%" stop-color="#A7F3D0" stop-opacity="0.38"/>
      <stop offset="60%" stop-color="#5EEAD4" stop-opacity="0.22"/>
      <stop offset="100%" stop-color="#0A5C56" stop-opacity="0.10"/>
    </radialGradient>

    <!-- Mint accent gradient -->
    <linearGradient id="mintGrad" x1="0" y1="0" x2="1" y2="0.5">
      <stop offset="0%" stop-color="#D1FAE5" stop-opacity="0.98"/>
      <stop offset="100%" stop-color="#6EE7B7" stop-opacity="0.82"/>
    </linearGradient>

    <!-- Clip to rounded square -->
    <clipPath id="roundClip">
      <rect x="0" y="0" width="{size}" height="{size}" rx="{int(size * 0.22)}" ry="{int(size * 0.22)}"/>
    </clipPath>
  </defs>

  <g clip-path="url(#roundClip)">
    <!-- Background -->
    <rect width="{size}" height="{size}" fill="url(#bgGrad)"/>
    <rect width="{size}" height="{size}" fill="url(#innerGlow)"/>

    <!-- Globe circle -->
    <circle cx="{size//2}" cy="{size//2}" r="{int(size * 0.32)}"
            fill="url(#globeGrad)" stroke="#CCFBF1" stroke-width="{max(1, size//256)}" stroke-opacity="0.24"/>

    <!-- Meridian lines (longitude) -->
    <g fill="none" stroke="#CCFBF1" stroke-width="{max(1, size//512)}" stroke-opacity="0.24">
      <!-- Vertical center line -->
      <line x1="{size//2}" y1="{int(size*0.18)}" x2="{size//2}" y2="{int(size*0.82)}"/>
      <!-- Elliptical meridians -->
      <ellipse cx="{size//2}" cy="{size//2}" rx="{int(size*0.12)}" ry="{int(size*0.32)}"/>
      <ellipse cx="{size//2}" cy="{size//2}" rx="{int(size*0.24)}" ry="{int(size*0.32)}"/>
    </g>

    <!-- Latitude lines (horizontal) -->
    <g fill="none" stroke="#CCFBF1" stroke-width="{max(1, size//512)}" stroke-opacity="0.18">
      <line x1="{int(size*0.18)}" y1="{size//2}" x2="{int(size*0.82)}" y2="{size//2}"/>
      <ellipse cx="{size//2}" cy="{size//2}" rx="{int(size*0.32)}" ry="{int(size*0.12)}"/>
      <ellipse cx="{size//2}" cy="{size//2}" rx="{int(size*0.32)}" ry="{int(size*0.22)}"/>
    </g>

    <!-- Mint accent arc — the "mapping" highlight -->
    <path d="M {int(size*0.28)} {int(size*0.58)}
             Q {int(size*0.5)} {int(size*0.35)}, {int(size*0.72)} {int(size*0.42)}"
          fill="none" stroke="url(#mintGrad)" stroke-width="{max(2, int(size*0.018))}"
          stroke-linecap="round" stroke-opacity="0.92"/>

    <!-- Small mint dot at arc start -->
    <circle cx="{int(size*0.28)}" cy="{int(size*0.58)}" r="{max(2, int(size*0.009))}"
            fill="#A7F3D0" opacity="0.95"/>

    <!-- Small mint dot at arc end -->
    <circle cx="{int(size*0.72)}" cy="{int(size*0.42)}" r="{max(2, int(size*0.009))}"
            fill="#A7F3D0" opacity="0.95"/>

    <!-- Subtle sparkle at top-right of globe -->
    <g transform="translate({int(size*0.62)}, {int(size*0.28)})" opacity="0.5">
      <line x1="0" y1="-{int(size*0.02)}" x2="0" y2="{int(size*0.02)}"
            stroke="white" stroke-width="{max(1, size//512)}" stroke-linecap="round"/>
      <line x1="-{int(size*0.02)}" y1="0" x2="{int(size*0.02)}" y2="0"
            stroke="white" stroke-width="{max(1, size//512)}" stroke-linecap="round"/>
    </g>

    <!-- Bottom subtle reflection -->
    <rect x="0" y="{int(size*0.75)}" width="{size}" height="{int(size*0.25)}"
          fill="url(#bgGrad)" opacity="0.3"/>
  </g>
</svg>'''


def main():
    os.makedirs(ICON_DIR, exist_ok=True)

    # Write SVG
    svg_content = generate_svg(1024)
    svg_path = os.path.join(ICON_DIR, "icon_1024.svg")
    with open(svg_path, "w") as f:
        f.write(svg_content)

    print(f"SVG written to {svg_path}")

    # Try to convert to PNG using sips (built-in macOS tool) via a temp file
    # First, check if we have rsvg-convert or cairosvg
    converters = []

    # Check for rsvg-convert (from librsvg)
    if subprocess.run(["which", "rsvg-convert"], capture_output=True).returncode == 0:
        converters.append("rsvg-convert")

    # Check for python cairosvg
    try:
        import cairosvg
        converters.append("cairosvg")
    except ImportError:
        pass

    # Check for Inkscape
    if subprocess.run(["which", "inkscape"], capture_output=True).returncode == 0:
        converters.append("inkscape")

    images = {}

    if "rsvg-convert" in converters:
        print("Using rsvg-convert for PNG generation...")
        for s in SIZES:
            out = os.path.join(ICON_DIR, f"icon_{s}x{s}.png")
            subprocess.run([
                "rsvg-convert", "-w", str(s), "-h", str(s),
                svg_path, "-o", out
            ], check=True)
            images[f"icon_{s}x{s}.png"] = s
            print(f"  Generated {s}x{s}")
    elif "cairosvg" in converters:
        print("Using cairosvg for PNG generation...")
        import cairosvg
        for s in SIZES:
            out = os.path.join(ICON_DIR, f"icon_{s}x{s}.png")
            cairosvg.svg2png(
                bytestring=svg_content.encode(),
                write_to=out,
                output_width=s,
                output_height=s
            )
            images[f"icon_{s}x{s}.png"] = s
            print(f"  Generated {s}x{s}")
    elif "inkscape" in converters:
        print("Using Inkscape for PNG generation...")
        for s in SIZES:
            out = os.path.join(ICON_DIR, f"icon_{s}x{s}.png")
            subprocess.run([
                "inkscape", svg_path,
                "--export-type=png",
                f"--export-filename={out}",
                f"--export-width={s}",
                f"--export-height={s}"
            ], check=True, capture_output=True)
            images[f"icon_{s}x{s}.png"] = s
            print(f"  Generated {s}x{s}")
    else:
        print("WARNING: No SVG-to-PNG converter found.")
        print("Install one of: librsvg (brew install librsvg), cairosvg (pip install cairosvg), or Inkscape")
        print(f"Then run: cd {ICON_DIR} && rsvg-convert -w 1024 -h 1024 icon_1024.svg -o icon_1024x1024.png")
        print("SVG file is ready for manual conversion.")
        # Still write Contents.json with expected filenames
        for s in SIZES:
            images[f"icon_{s}x{s}.png"] = s

    # Write Contents.json for Xcode
    icon_images = []
    for s in [16, 32, 128, 256, 512]:
        # 1x
        icon_images.append({
            "filename": f"icon_{s}x{s}.png",
            "idiom": "mac",
            "scale": "1x",
            "size": f"{s}x{s}"
        })
        # 2x
        icon_images.append({
            "filename": f"icon_{s*2}x{s*2}.png",
            "idiom": "mac",
            "scale": "2x",
            "size": f"{s}x{s}"
        })

    contents = {
        "images": icon_images,
        "info": {
            "author": "atlas-icon-generator",
            "version": 1
        }
    }

    contents_path = os.path.join(ICON_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)

    print(f"Contents.json written to {contents_path}")
    print("Done!")


if __name__ == "__main__":
    main()
