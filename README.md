<div align="center">
  <img src="Docs/Media/README/atlas-icon.png" alt="Atlas for Mac icon" width="128" />
  <h1>Atlas for Mac</h1>
  <p><em>Explainable, recovery-first Mac maintenance workspace.</em></p>
</div>

<p align="center">
  <strong>English</strong> | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="Docs/Media/README/atlas-overview.png" alt="Atlas for Mac overview screen" width="1000" />
</p>

Atlas for Mac is a native macOS application for people who need to understand why their Mac is slow, full, or disorganized, then take safe and reversible action. The current MVP unifies system overview, Smart Clean, app uninstall workflows, permissions guidance, history, and recovery into a single desktop workspace.

This repository is the working source for the new Atlas for Mac product. Atlas for Mac itself is open source under the MIT License. It remains an independent project and may reuse selected upstream Mole capabilities under the MIT License, but user-facing naming, release materials, and product direction are Atlas-first.

## Disclaimer

Atlas for Mac is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by Apple, the upstream Mole authors, or any other commercial Mac utility vendor. Some components in this repository may reuse or adapt upstream Mole code under the MIT License; when such code ships, the related attribution and third-party notices must remain available. Cleanup, uninstall, and recovery actions can affect local files, caches, and app data, so review findings and recovery options before execution.

## Installation

### Download

Download the latest release from the [Releases](https://github.com/CSZHK/CleanMyPc/releases) page:

- **`.dmg`** — Recommended. Open the disk image and drag Atlas to your Applications folder.
- **`.zip`** — Extract and move Atlas.app to your Applications folder.
- **`.pkg`** — Run the installer package for guided installation.

### Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

### Build from Source

```bash
git clone https://github.com/CSZHK/CleanMyPc.git
cd CleanMyPc
swift run --package-path Apps AtlasApp
```

Or open in Xcode:

```bash
brew install xcodegen
xcodegen generate
open Atlas.xcodeproj
```

> **Note**: The app is currently unsigned. On first launch, you may need to right-click and select "Open" to bypass Gatekeeper, or go to System Settings > Privacy & Security to allow it.

## MVP Modules

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

## Product Principles

- Explain recommendations before execution.
- Prefer recovery-backed actions over permanent deletion.
- Keep permission requests least-privilege and contextual.
- Preserve a native macOS app shell with worker and helper boundaries.
- Support `简体中文` and `English`, with `简体中文` as the default app language.

## Screens

| Overview | Smart Clean |
| --- | --- |
| ![Overview](Docs/Media/README/atlas-overview.png) | ![Smart Clean](Docs/Media/README/atlas-smart-clean.png) |

| Apps | History |
| --- | --- |
| ![Apps](Docs/Media/README/atlas-apps.png) | ![History](Docs/Media/README/atlas-history.png) |

## Repository Layout

- `Apps/` — macOS app target and app-facing entry points
- `Packages/` — shared domain, application, design system, protocol, and feature packages
- `XPC/` — worker service targets
- `Helpers/` — privileged helper targets
- `Testing/` — shared testing support and UI automation repro targets
- `Docs/` — product, architecture, planning, attribution, and execution documentation

## Local Development

### Run the app

```bash
swift run --package-path Apps AtlasApp
```

### Open the native Xcode project

```bash
xcodegen generate
open Atlas.xcodeproj
```

### Build the native app bundle

```bash
./scripts/atlas/build-native.sh
```

### Package `.zip`, `.dmg`, and `.pkg` artifacts

```bash
./scripts/atlas/package-native.sh
```

### Run focused tests

```bash
swift test --package-path Packages
swift test --package-path Apps
```

## Refresh README Media

```bash
./scripts/atlas/export-readme-assets.sh
```

This exports the configured app icon and current app-shell screenshots into `Docs/Media/README/`.

## Author & Contact

- Developer: `Lizi KK`
- Role: `Ex-Baidu & Alibaba Tech Lead · atomstorm.ai Founder`
- Website: [AtomStorm Studio](https://studio.atomstorm.ai)
- X (Twitter): [x.com/lizikk_zhu](https://x.com/lizikk_zhu)
- Discord: [discord.gg/aR2kF8Xman](https://discord.gg/aR2kF8Xman)
- GitHub Repository: [CSZHK/CleanMyPc](https://github.com/CSZHK/CleanMyPc)
- Issues: [github.com/CSZHK/CleanMyPc/issues](https://github.com/CSZHK/CleanMyPc/issues)
- Security Contact: `cszhk0310@gmail.com` for private vulnerability reports. See [SECURITY.md](SECURITY.md).

### More Socials

| WeChat Official Account | Xiaohongshu |
| --- | --- |
| ![WeChat Official Account QR code](Packages/AtlasFeaturesAbout/Sources/AtlasFeaturesAbout/Resources/Media.xcassets/qrcode-wechat.imageset/qrcode-wechat.jpg) | ![Xiaohongshu QR code](Packages/AtlasFeaturesAbout/Sources/AtlasFeaturesAbout/Resources/Media.xcassets/qrcode-xiaohongshu.imageset/qrcode-xiaohongshu.jpg) |

## Attribution

Atlas for Mac is an independent MIT-licensed open-source project. This repository builds in part on the open-source project [Mole](https://github.com/tw93/mole) by tw93 and contributors, and still contains upstream Mole code and adapters used as implementation input. If upstream-derived code ships, keep [Docs/ATTRIBUTION.md](Docs/ATTRIBUTION.md) and [Docs/THIRD_PARTY_NOTICES.md](Docs/THIRD_PARTY_NOTICES.md) in sync with shipped artifacts.
