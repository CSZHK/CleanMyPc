# Issue #5: 静态兜底文件钉版本号必然漂移

**修复日期**: 2026-09-15
**类别**: frontend
**关联模块**: `Apps/LandingSite`
**严重等级**: P2（体验问题）

---

## 问题本质 (≤3行)
`release-fallback.json` 停在 `1.0.3`，App 已发 `2.1.0`，同一时刻 `release-manifest.json` 缓存里是 `1.30.0`。
触发条件：GitHub API 取数失败，站点回落到该静态文件并展示其中版本号。

## 根因分析 (≤5行)
该文件人工维护、只在取数失败时渲染（`Apps/LandingSite/src/data/release.ts:41-48`），
钉住的值不会自己更新——**钉版本号的静态兜底必然漂移**，改对一个数字只是把下次漂移推迟。
`release-fallback.json:3` 的 `version` 与 `release-manifest.json`（构建期生成、已 gitignore）互不同步。

## 解决方案 (≤5行)
消除该类漂移而非改数：`version` / `tagName` / `publishedAt` 全置 `null`。
UI 已具备优雅降级：`ChannelBadge.astro:15` 与 `Hero.astro:88` 均以 `{version && …}` 守卫，
`getDownloadUrl()` 在 assets 全空时回落到 `releaseUrl`（releases 页）。
- 关键代码: `Apps/LandingSite/scripts/fetch-release.ts:17-62`（构建期断言）

## 关键决策 (≤3行)
保留 `channel: "prerelease"`：本仓库至今全部 release 均为 prerelease，标 `none` 会渲染成「即将推出」——那是假的。
守卫放在 `fetch-release.ts`（`prebuild` 前置）而非新增工具：不变式就发生在这个构建步骤。

## 预防措施 (≤2行)
静态兜底不得声明任何会随发布变化的值；构建期断言钉值即 `exit 1`，已变异检验。
移除 `release-manifest.json` 后构建实测：`/en/` 与 `/zh/` 版本号元素均为 0，下载链接指向 releases 页。
