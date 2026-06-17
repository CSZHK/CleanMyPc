# FileOrganizer 全功能验收修复 ExecPlan

> 来源：两轮 audit workflow（11 维 + 3 维补漏，对抗式验证）+ 主循环独立复核。
> 24 confirmed / 3 rejected。综合结论：**核心 happy path 未打通**（两处 wiring 死闭包）+ 安全边界过宽。

## 根因主线（P0+P1，同类病）
`FileOrganizerFeatureView` 的 `onRefreshPreview` 与 `onClassify` 在 commit `62f30d7`（五段式重构）被删调用点，仅留声明+AppShell 接线 →
- 扫描后 `isFileOrganizerPlanFresh` 恒 false → 阶段落回 ①扫描，**用户卡死无法前进**（#7 P0）。
- 分类器（自定义规则 + UTType）生产中**从不运行**，规则编辑完全无效（#19 P1）。

## 修复批次（同批绑定标注）

### Batch 1 · 管线 wiring（#7 P0 + #19 P1）— 必修，核心
- model `runFileOrganizerScan` 扫描成功后：`classifyFileOrganizerEntries([])` → `refreshFileOrganizerPreview([])`，使阶段进入 ②规则、规则生效。
- 现有测试 line 867 `assertFalse(isFileOrganizerPlanFresh)` 翻转为 true（它编码了 bug）。
- TDD：新增"扫描后自动 fresh + 计划非空 + 阶段越过 scan"失败测试。

### Batch 2 · 设置失效（#15 P2）— 与 Batch 1 同批（强绑）
- `updateFileOrganizerRules` / `updateFileOrganizerDestination` / `updateFileOrganizerRecursiveScan`：设置变更后若已有 entries，reclassify + refreshPreview，重算 proposedDestination。避免"文件移到旧目录"。

### Batch 3 · 安全边界（#22 P1 + #23/#24 P2）
- FO 目的地限定在用户 home（destinationBasePath 落 home；worker execute 硬校验 dest ∈ home）。
- `destinationSubfolder` sanitization：拒绝/剥离 `..`、绝对路径、空段、null。
- 结果：#23（系统目录写入）/ #24（恢复不对称）对 FO 自然消解（dest 恒在 home → 恒可恢复）。

### Batch 4 · execute 诚实性（#8/#9 P2）
- 输出加 `failedCount` 信号回 AppModel；删 `hasPartialSuccess` 死三元；全失败不清空 entries、报失败、留重试；receipt 反映部分失败。

### Batch 5 · scan 去重（#1 P2）
- Scanner 对输入 paths 去重 + 嵌套裁剪；resolved 文件路径 seen-set 去重。

### Batch 6 · 规则编辑器（#3/#4/#6 P2；#5/#21 P3）
- 扩展名剥前导点；导入需校验+确认+去重；size 字段数值校验+上限；禁止纯名称规则。

### Batch 7 · a11y（#18 P2）
- 规则编辑器 move-up/move-down/delete 加 accessibilityLabel。

### Batch 8 · P3 收尾（#2/#10/#11/#13/#14/#17）
- displayPath 分隔符边界；sourceFolder 取目录；totalBytesMoved；prune 孤儿；台账 tilde；settingsSet 文案。

## 验证
- 每批 `swift test`（Apps + 相关 Package）。
- 全部完成后跑 verify workflow（build + 全量 test + 修复路径回归再审）。
- 最后跑 code audit workflow（correctness/state/contract/security 多维 + merge-blocker）。

## rejected（不动）
- #16 重启不回填 entries（设计取舍）。
- preview-plan stalePlan 子集冲突（previewPlan 实际用全量，与 execute 一致）。
- dry-run 选择语义（设计为全量预演）。
- security ~user 展开（当前被 safeRoots 守卫，非现行可利用）。

## 完成状态（verify workflow 后）

**全部批次实施完毕，构建通过，Packages 590 + Apps 61 测试全绿。**

verify+audit workflow（7 域对抗复核 + diff 全量审查）发现 3 个 P2 + 若干 P3，已补救：
- **#12 撤销幂等成死代码（fixHolds=false→已修）**：validateRestoreItems 预校验整批 reject，幂等跳过不可达。已把幂等短路前置进 `validateRestoreTarget`（dest 存在&&source 不在→直接 return 成功），让预校验放行。
- **扫描失败+残留 entries → 过期 plan 标 fresh（P2→已修）**：`runFileOrganizerScan` 起始清空 `fileOrganizerEntries`，失败时 regenerate no-op，保留失败提示。
- **部分失败 UI 静默（P2→已修）**：`FileOrganizerExecutionReceipt` 加 `failedItemCount`，receipt 视图在 `failureReason==nil && failedItemCount>0` 显示「未移动项目」行。
- P3：worker `resolvedDisplay` 边界对齐 `homeDir+"/"`；`hasAnyPattern` 改用 parsed(split/filter) 避免纯分隔符启保存；新增 security `/Applications` home-guard 回归测试（旧 `/etc` 测试在上游 safeRoots 被拦，打不到新防线）。

暂缓（P3，已记录理由）：#11（totalBytesMoved 用声明值）、#13（过期不清 ~/Organized——那是用户要的整理结果）、#14（台账 tilde）、#21（min==max 退化窗）、codable legacy-JSON 测试（合成 Codable 已保证可选字段兼容）。

## 交付
- 13 文件，+453/-96。
- 最终代码审计 workflow 对完整 diff 终审（见会话）。

