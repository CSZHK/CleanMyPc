# P3 — 回归修复

- **状态**：DONE（2026-09-15）
- **初跑**：`Packages` 612 tests / **2 failures**（基线 612/0）—— 本 REQ 引入 2 处回归
- **复跑**：`Packages` **612/0** · `Apps` **72/0**

## 两处失败的共同根因

测试**断言了文案字面值**。文案一改，断言即红。这不是测试脆弱，是**契约的一部分**——路由标题是「Unfrozen row」（可在解冻记录里改的项）。

| 失败用例 | 断言 | 处置 |
|---|---|---|
| `AtlasDomainTests.testPrimaryRoutesMatchFrozenMVP` | 路由标题数组含「台账」 | 期望值改「历史记录」；并把该用例的 `Unfrozen row` 注释从「一次解冻（历史→台账）」改为**二次解冻**记录，指向本 REQ |
| `LedgerModelTests.testExportBuilderEmptyEntriesShowsPlaceholder` | 导出 Markdown 含「当前没有可见的台账条目」 | 随 `ledger.export.empty` 更新为「当前没有可见的历史记录条目」 |

## 为什么注释也要改

`AtlasDomainTests` 的那行注释是**解冻台账**：它记录了「这个值为什么可以偏离冻结的 MVP」。若不更新，下一位读者会看到「注释说该值是台账，断言写的是历史记录」，无法判断是注释陈旧还是断言写错。

## 停止条件

两套 `swift test` 零失败且不低于各自基线。
