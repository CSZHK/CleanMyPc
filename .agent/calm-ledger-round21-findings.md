# Calm Ledger Round-21 — Findings 索引

来源：Workflow `wf_e45b63d5-055`（10 surface × 14 维 review + 对抗验证，43 agents / 1.79M tok）+ 主循环缺口复核。
基线：Packages 595/0 · Apps 62/0 · Helpers 3/0 · contrast 36/36 · build 0 新 warning · swift run BOOT_OK。
**确认：0 P0 / 0 P1 / 11 P2 / 2 P3。**

## 失败 agent（已人工补审）
- `review:overview`（429）→ 主循环直读 4 文件：**clean**（只读 snapshot，无 filter 耦合，№ 抗碰撞正确，a11y 齐）。
- `verify:appshell:D1`（429，3 票丢 1）→ D1 finding 仍 2/3 confirmed，成立。
- critique 担心的 SmartClean summary tile filter 耦合 → **不成立**（SmartCleanFeatureView 未用 AggregateSummaryCard；其度量取全量 findings 或有意 selection；AggregateSummaryCard 全仓零引用=死码）。

## confirmed P2（11，必修）

### 指标诚实（D4/D9，metric off filtered/expired set）
1. **AppsFeatureView:135** D4 — 库存卡（Listed/Footprint/Leftovers）读 filtered `sortedApps`；toggle「仅残留」三项总量同步缩水，且与同屏 chip 计数（line 211 取全量）打架。修：取 `Self.sortedApps(apps)` 全量。
2. **SettingsFeatureView:169** D9 — 恢复区占用读 `filteredRecoveryItems`（受 Ledger 搜索过滤），却标注「总大小」。wiring 在 AppShellView:397。修：取未过滤总量。
3. **LedgerFeatureView:115** D4 — 「可恢复项」metric 用 `sortedRecoveryItems.count`（含已过期，不可恢复）；detail `totalRecoveryBytes` 亦含过期；tone 误报。修：排除 expired。

### a11y / 触达（D3/D7）
4. **FileOrganizerRuleEditorView:207** D3 — move-up/down/delete 裸 SF Symbol 无 44pt frame，低于分支 44pt 红线（对照 entry-row info btn line 309 有 44×44）。修：加 `.frame(width:44,height:44).contentShape(Rectangle())`。
5. **AtlasSegmentedControl:31** D3 — segment ~25pt（caption+xs padding），分支唯一 <44pt 可点控件（语言/主题切换）。修：`.frame(minHeight:44)`。
6. **AtlasFilterChip:72** D7 — VO label 硬编码英文 `"\(title), \(count) items"`，未过 AtlasL10n，zh-Hans（默认）漏英文。修：新增 `ds.chip.count` 键本地化。

### FileOrganizer（D4/D14/D1）
7. **FileOrganizerStageViews:480** D4 — execute 阶段 AtlasCircularProgress 回显 stale `scanProgress`（冻结 ~100%），与 action-bar（indeterminate）自相矛盾。修：execute 时不回显 stale 进度。
8. **FileOrganizerEvidenceBuilder:126** D14 — `conflictingEntryIDs` 在 view body 每次 render 同步 `FileManager.fileExists` 逐项 stat（rules/preview/evidence 三处），大扫描卡顿。修：移出 main thread / 缓存。
9. **AtlasAppModel:1166** D1 — FO re-scan 不重新分配 №/回执（仅 `planNumber==nil` 时分配），工具栏 chip + 回执长期 stale；与 SmartClean 无条件重分配（line 395）不对称。修：FO plan-producing scan 无条件重分配。

### 回执 / 证据（D12/D9）
10. **LedgerExportBuilder:151** D12 — 导出 entries 只取 taskRuns，recovery items 全部丢弃，但 header 声称「可恢复项 N 个 / 可恢复总量 X」。修：entries 纳入 recovery items（带 recoveryBytes）。
11. **PermissionEvidenceBuilder:48** D9 — 权限状态 KV 行 label 复用「为什么需要」，实为状态分类（与同 section 的 why 标题撞义）。修：新增 `permissions.evidence.section.status` 键。

## carryForward P3（2，仅记录不修）
- C1 **LedgerFeatureView:219** D12 — 导出忽略 active filter（承诺「当前可见」却导出全量）。
- C2 **Localizable.strings** D7 — 6 个 history→ledger 改名残留孤儿键（route.history.*/taskcenter.openHistory*/sidebar.history.dynamic/emptystate.action.viewHistory，零 swift 引用，zh/en parity 完好无可见缺陷）。

## 其它（gap 复核结论）
- Overview / SmartClean / AggregateSummaryCard（死码）/ PermissionEvidenceBuilder（无 IO）：clean，无 P2。
