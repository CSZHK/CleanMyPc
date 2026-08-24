<div align="center">
  <img src="Docs/Media/README/fig01-cover.png" alt="Atlas for Mac — 可解释、以恢复为先的 Mac 维护工作台" width="1024" />
</div>

<div align="center">
  <h1>Atlas for Mac</h1>
  <p><em>可解释、以恢复为先的 Mac 维护工作台。</em></p>
  <p><a href="README.md">English</a> | <strong>简体中文</strong></p>
  <p>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT" /></a>
    <a href="https://github.com/CSZHK/CleanMyPc/releases"><img src="https://img.shields.io/github/v/release/CSZHK/CleanMyPc?include_prereleases&sort=semver" alt="最新版本" /></a>
    <a href="#install"><img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+" /></a>
    <a href="https://github.com/CSZHK/CleanMyPc"><img src="https://img.shields.io/github/stars/CSZHK/CleanMyPc?color=yellow" alt="GitHub stars" /></a>
  </p>
</div>



https://github.com/user-attachments/assets/a88be4bd-d720-4836-a0c6-b98d08873f94



> **为什么选 Atlas？** 你的 Mac 早就知道它为什么变慢、变满、变乱——Atlas 告诉你原因，再安全地把它修好。**6.2 MB** 安装包，比同类 Mac 清理工具小约 20 倍。先解释再执行，每个操作都可回退。

## Atlas 能做什么

Atlas for Mac 是一款原生 macOS 应用，回答你的 Mac 已经在问的三个问题——然后安全地动手解决：

- **为什么变慢？**—— 系统概览与按 App 精细洞察，用大白话讲清楚。
- **为什么变满？**—— Smart Clean 与文件整理精准定位哪些可以安全清理。
- **我刚刚动了什么？**—— 每个经审核的操作都进入「恢复台账」，在存在受支持恢复路径期间都能撤销。

先建议、后执行；优先恢复而非永久删除，并且对恢复能力保持诚实——并非每个"可恢复"项目都真的能回到磁盘。

## 界面截图

| Overview | Smart Clean |
| --- | --- |
| ![Overview — 一眼看清机器状态](Docs/Media/README/atlas-overview.png) | ![Smart Clean — 有解释、可安全的清理](Docs/Media/README/atlas-smart-clean.png) |

| Apps | Ledger |
| --- | --- |
| ![Apps — 完整卸载，无残留](Docs/Media/README/atlas-apps.png) | ![Ledger — 每个操作都可恢复](Docs/Media/README/atlas-ledger.png) |

## 安装

从 [Releases](https://github.com/CSZHK/CleanMyPc/releases) 页面下载最新构建，或访问 [atlas.atomstorm.ai](https://atlas.atomstorm.ai/) 了解更多。

- **`.dmg`** - 打开磁盘镜像，将 Atlas 拖入 Applications 文件夹。
- **`.zip`** - 解压后将 `Atlas.app` 移动到 Applications 文件夹。
- **`.pkg`** - 运行安装包，按向导完成安装。

**系统要求：** macOS 14.0（Sonoma）或更高版本 · Apple Silicon 或 Intel Mac。

> **下载的是预发布版本？** GitHub 预发布版本可能是开发签名构建，macOS 可能在 `系统设置 -> 隐私与安全性` 里拦截，并要求你使用 `仍要打开`（或右键 `打开`）。遇到这种情况，你会看到类似下面的提示：

<p align="center">
  <img src="Docs/Media/README/atlas-prerelease-warning.png" alt="Atlas for Mac 预发布版本在 macOS 安全性设置中的拦截提示与 Open Anyway 操作示意图" width="900" />
</p>

## MVP 模块

| 模块 | 作用 |
| --- | --- |
| `Overview` | 系统健康与磁盘占用，一目了然、大白话。 |
| `Smart Clean` | 先解释，再清理——基于你的使用习惯，始终先审核。 |
| `File Organizer` | 把杂乱收拾成你能理清的秩序。 |
| `Apps` | 完整卸载，不是拖进废纸篓的残留。 |
| `Ledger` | 恢复台账——你审核过的任何操作都被追踪、可回退。 |
| `Permissions` | 最小权限、结合上下文的权限指引。 |
| `Settings` | 配置、语言（English / 简体中文）与应用默认项。 |

恢复能力贯穿 Smart Clean、Apps 与文件整理：经审核的操作会记录到「台账」中，并在存在受支持恢复路径期间保持可还原。

## 产品原则

- 执行前先解释推荐原因。
- 优先提供可恢复的操作，而不是永久删除。
- 对恢复能力保持诚实：并非每个"可恢复"项目都能真正回到磁盘。
- 权限请求遵循最小权限并结合具体上下文。
- 保持原生 macOS 应用外壳，并明确 worker 与 helper 边界。
- 同时支持 `简体中文` 和 `English`，其中 `简体中文` 为应用默认语言。

## 构建与开发

```bash
git clone https://github.com/CSZHK/CleanMyPc.git
cd CleanMyPc
swift run --package-path Apps AtlasApp        # 运行应用
```

**Xcode 工程**

```bash
brew install xcodegen
xcodegen generate
open Atlas.xcodeproj
```

**构建原生应用包 / 打包产物**

```bash
./scripts/atlas/build-native.sh
./scripts/atlas/ensure-local-signing-identity.sh   # 无 Apple 发布证书时推荐
./scripts/atlas/package-native.sh
```

本地签名初始化会给本地构建和预发布构建提供一个稳定的开发签名，而不是退回 ad hoc 打包。

**测试与 README 媒体资源**

```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/export-readme-assets.sh   # 导出图标与截图到 Docs/Media/README/
```

## 仓库结构

- `Apps/` - macOS 应用 target 与面向应用层的入口
- `Packages/` - 共享的 domain、application、design system、protocol 和 feature packages
- `XPC/` - worker service targets
- `Helpers/` - 特权 helper targets
- `Testing/` - 共享测试支持与 UI 自动化复现 targets
- `Docs/` - 产品、架构、规划、归因和执行文档

## 贡献与支持

- **[Releases](https://github.com/CSZHK/CleanMyPc/releases)** —— 获取应用
- **[Issues](https://github.com/CSZHK/CleanMyPc/issues)** —— 反馈问题
- **⭐ 点亮 Star** —— 让更多人用上一个可解释、以恢复为先的 Mac 清理工具。

## 许可、归因与安全

Atlas for Mac 是一个独立的、基于 **MIT License** 发布的开源项目。此仓库部分构建工作基于开源项目 [Mole](https://github.com/tw93/mole)（由 tw93 和贡献者维护），并且当前仍包含作为实现输入的上游 Mole 代码和适配器。如果发布中包含上游衍生代码，请保持 [Docs/ATTRIBUTION.md](Docs/ATTRIBUTION.md) 和 [Docs/THIRD_PARTY_NOTICES.md](Docs/THIRD_PARTY_NOTICES.md) 与实际交付产物同步。

Atlas for Mac **不**与 Apple、Mole 上游作者或其他任何商业 Mac 工具厂商存在隶属、赞助或背书关系。清理、卸载和恢复类操作可能影响本地文件、缓存和应用数据——执行前请先查看发现结果和恢复选项。可恢复操作仍会在 Atlas 中保留可追溯记录，但只有具备受支持恢复路径的项目，才支持磁盘级恢复。

私下报告安全漏洞请见 [SECURITY.md](SECURITY.md)（联系：`cszhk0310@gmail.com`）。

## 作者与联系

- 开发者：**Lizi KK** —— 前百度 & 阿里技术负责人 · atomstorm.ai 创始人
- 官网：[AtomStorm Studio](https://studio.atomstorm.ai)
- X（Twitter）：[x.com/lizikk_zhu](https://x.com/lizikk_zhu)
- Discord：[discord.gg/aR2kF8Xman](https://discord.gg/aR2kF8Xman)
- GitHub：[CSZHK/CleanMyPc](https://github.com/CSZHK/CleanMyPc) · [Issues](https://github.com/CSZHK/CleanMyPc/issues)

| 微信公众号 | 小红书 |
| --- | --- |
| ![微信公众号二维码](Packages/AtlasFeaturesAbout/Sources/AtlasFeaturesAbout/Resources/Media.xcassets/qrcode-wechat.imageset/qrcode-wechat.jpg) | ![小红书二维码](Packages/AtlasFeaturesAbout/Sources/AtlasFeaturesAbout/Resources/Media.xcassets/qrcode-xiaohongshu.imageset/qrcode-xiaohongshu.jpg) |
