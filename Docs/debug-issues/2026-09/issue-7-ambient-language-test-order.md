# Issue #7: 测试断言本地化文案却不自设语言，结果取决于测试执行顺序

**修复日期**: 2026-09-15
**类别**: 其他（测试守卫）
**关联模块**: `Packages/AtlasFeaturesFileOrganizer/Tests/AtlasFeaturesFileOrganizerTests/FileOrganizerEvidenceBuilderTests.swift`
**严重等级**: P2（CI 持续红三周；不直接影响用户功能）

---

## 问题本质 (≤3行)
同一份代码，本地 613 条测试全过、CI 上同一条用例必红。
触发条件：用例断言**本地化后的标签文本**，而语言取自进程级全局态 —— 结果取决于哪个测试文件先跑。

## 根因分析 (≤5行)
`AtlasL10n.currentLanguage` 是进程级全局态（`AtlasLocalization.swift:55`），由各测试文件的 `setUp` 写入、无谁负责还原。
本文件从不设定它（改动前 `setUp` 不存在），于是继承前一个文件留下的值。
断言 `contains("Destination") || contains("目标")`（`:263`）只对 zh 成立：en 现值 `fileorganizer.evidence.destination = "Move target"` 两个关键词都不含。
本地恰好落在 `.zhHans`（过），CI 落在 `.en`（红）—— 2026-08-26 起连续三周，每次都是 `:242`/`:244`。

## 解决方案 (≤5行)
`setUp` 里显式钉死 `AtlasL10n.setCurrentLanguage(.zhHans)`，消除顺序依赖。
- 关键代码: `FileOrganizerEvidenceBuilderTests.swift:25-28`
- 全量复跑：619 tests / 0 failures；CI 同轮由 2 failures 转 0

## 关键决策 (≤3行)
**只修不确定性，不裁决文案。** 钉死 zh 后该用例只覆盖中文侧，en 侧 `Move target` 与已签字裁定
「`Destination` 保留」（`Docs/COPY_GUIDELINES.md:99`）的冲突**未被裁决**，另记 `ATL-283`。
别把这里的绿读成「文案没问题」—— 那正是本仓栽过的「核了现象没核义务」。

## 预防措施 (≤2行)
断言本地化文本的测试**必须自设语言**，不得依赖环境残留；同类文件另有 5 个（`ATL-284`）。
判定 CI 红时的第一问应是「本地与 CI 的**环境差异**是什么」，而非「代码哪里错了」。

---
**相关链接**: 提交 `e6227d5` · `Docs/Backlog.md` 的 `ATL-283` / `ATL-284`
