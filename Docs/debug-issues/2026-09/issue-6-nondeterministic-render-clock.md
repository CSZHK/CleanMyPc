# Issue #6: 渲染不可复现——墙钟时间烘焙进像素，且根因是两半

**修复日期**: 2026-09-15
**类别**: 其他（构建/导出工具）
**关联模块**: `Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift`
**严重等级**: P2（物料可复现性；不直接影响用户功能）

---

## 问题本质 (≤3行)
同一份代码重导 README 截图，9 张里 4 张字节不同，差异是烘焙进像素的绝对时间戳。
触发条件：fixture 的时间戳与相对时间的参考点都取自真实 `Date()`。

## 根因分析 (≤5行)
**两处独立依赖，只修一处仍不可复现**——这是本条的全部价值所在。
① `AtlasScaffoldFixtures.now` 直接取 `Date()`，于是**绝对时间**每次都变（`AtlasDomain.swift:1377`）。
② `AtlasFormatters.relativeDate` 的参考点写死 `Date()`，于是**相对时间**（"4 minutes ago"）
   在日期钉死后**仍随真实时间漂**：今天读作「11 个月前」，几个月后变「1 年前」（`AtlasDesignSystem.swift:93`）。
只修 ① 的失败形态最阴——日期固定了，肉眼看「已可复现」，而截图上最显眼的相对时间仍在漂。

## 解决方案 (≤5行)
新增单一注入点 `AtlasRenderClock`（`AtlasRenderClock.swift:30-47`），`NSLock` 保护的进程级全局态；
①② 都改走它，导出器钉死 + `defer` 还原。
- 关键代码: `AtlasDomain.swift:1377`、`AtlasDesignSystem.swift:93`、`ReadmeAssetExporter.swift:263-264`
- 钉死值复用回执编号的 `scanDate` 同一常数，避免截图上的日期与编号自相矛盾（`ReadmeAssetExporter.swift:214`）

## 关键决策 (≤3行)
**不动 fixture 本身**：它被 `AtlasScaffoldWorkerService` 与 `AtlasWorkspaceRepository` 共用，
全局钉死日期会改变 app 行为。时钟是导出专用注入点，正常运行的 app 从不碰它。
取「一个注入点治两处」而非两处各打补丁——否则第三处时间依赖出现时还会再漏一次。

## 预防措施 (≤2行)
守卫 `AtlasRenderClockTests.swift:52`：钉死后 fixture 时间戳必须等于钉死值 − 300s。
**变异检验**：把 fixture 改回 `Date()` → 该条与「两次调用须一致」共 2 条变红。

---
**相关链接**: `Docs/design/2026-09-15-readme-media-lifecycle.md` §导出器可复现性 · 提交 `d6e5cc0`
