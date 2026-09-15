# Issue #1: 门禁的输入面 ≠ 被检事实的载体

**修复日期**: 2026-09-15
**类别**: 其他（门禁工具）
**关联模块**: `scripts/atlas/copy_gate.py`
**严重等级**: 未定级（门禁有效性缺陷，非产品故障）

---

## 问题本质 (≤3行)
术语 `№` 已裁定退役，门禁报 PASS，实际仍在 5 处渲染。
触发条件：禁用词硬编码在 Swift 字符串字面量里，而门禁只遍历两份 `.strings` 的 value。

## 根因分析 (≤5行)
载体面与输入面不重合：`№` 住在 Swift 源码里，C1 只读 `load_strings()` 的结果，两边永不相交。
命中点在 `TaskCenterView.swift:116`、`OverviewLedgerFeed.swift:94`、`LedgerDetailView.swift:94`、
`AtlasLedgerTimeline.swift:156`、`LedgerExportBuilder.swift:117`——全部为 `Text("№\(n)")` 形态。
门禁覆盖面缺陷不会自曝：它只报「已扫的部分没问题」。

## 解决方案 (≤5行)
新增 C9 维扫描 Swift 字符串字面量中的禁用词/字形。
范围刻意只到生产源（跳过 `Tests/`）：测试断言消息与夹具不是用户可见载体，初版未排除时 22 条里 21 条是误报。
- 关键代码: `scripts/atlas/copy_gate.py:235-263`（`check_swift_literals`）

## 关键决策 (≤3行)
守卫若误报就会被绕过，故宁可窄而准：只扫生产源。
保留一份显式禁用字形表而非全量语义分析，成本可控且规则可读。

## 预防措施 (≤2行)
新增门禁规则时必须回答：**这条规则看不到的载体有哪些？**（源码字面量 / 注释 / 运行时拼接）。
C9 已纳入 `full-acceptance.sh` 第 [4/12] 步，并做过变异检验。
