# Issue #2: 自证守卫——断言自己的输入

**修复日期**: 2026-09-15
**类别**: 其他（测试守卫）
**关联模块**: `Packages/AtlasFeaturesHistory/Tests`
**严重等级**: 未定级（测试层缺陷，非产品故障）

---

## 问题本质 (≤3行)
用例断言 `markdown` 含 `"# 维护台账报告"`，而它自己把该串作为 `title:` 传进了 `Input`。
触发条件：产品文案变更——改名后该用例**照样全绿**，提供的是假覆盖。

## 根因分析 (≤5行)
断言对象是测试自造的串，不是被测系统读的产品取值；生产路径 `LedgerExportBuilder.swift:193` 实际读
`AtlasL10n.string("ledger.export.report.title")`，但用例绕过了它直调 `render(input)`。
同型先例：`REQ-ux-friction-remediation` 查出的 `I-8`（「断言自己算 n 再造期望串，被测视图未读」）。

## 解决方案 (≤5行)
改走生产入口 `LedgerExportController.renderReport(taskRuns:recoveryItems:retentionDays:planNumber:)`，
断言标题等于 `AtlasL10n.string("ledger.export.report.title")` 的实际取值。
- 关键代码: `Packages/AtlasFeaturesHistory/Tests/AtlasFeaturesHistoryTests/LedgerModelTests.swift:260-289`

## 关键决策 (≤3行)
不舍弃该用例而改其载体：`renderReport` 是生产真实入口，覆盖它才有意义。
同类断言一并改为引用产品键（`ledger.export.empty`），消除第二处自造串。

## 预防措施 (≤2行)
断言期望值必须**派生自产品取值**（L10n 键、类型化常量），不得在测试内另写一份字面量。
复核既有守卫时问：改坏产品代码，它会不会红？
