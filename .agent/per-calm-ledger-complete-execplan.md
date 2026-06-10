# PER: Calm Ledger 重设计全量收口（M2 → M3 → M4）

**Status:** IN_PROGRESS
**Created:** 2026-06-10
**Scope:** Packages/AtlasDesignSystem · Packages/AtlasFeatures* · Apps/AtlasApp · AtlasDomain（路由/L10n）· Docs/*（同步清单）
**Dimension:** 全量 · 深度: 标准（P0+P1）
**Canonical truth:** 规格 Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1) · REQ iterations/REQ-calm-ledger-redesign/ · findings .agent/calm-ledger-redesign-findings.md（本文件只做编排跟踪，不复制内容）

## Progress
- [x] Phase 1: 范围确认（用户指令「全部干完」，无暂停点）
- [ ] Phase 2/3: M2 组件层（Batch E 前置修复 + Batch F/G 组件）
- [ ] Phase 2/3: M3 屏幕迁移（Batch H 壳层/改名 → I 智能清理样板间 → J 台账 → K 概览 → L 应用/整理 → M 权限/设置/关于）
- [ ] Phase 2/3: M4 收尾（L10n / 文档同步 / 截图 / 门禁）
- [ ] Phase 4: 跨边界回归（全量测试 + 门禁 + 构建）
- [ ] Phase 5: 收口总结（trace 回填 + Close Gate）

## Backlog
| # | Severity | Category | Source | Description | Status |
|---|----------|----------|--------|-------------|--------|
| 1 | P0 | 测试阻塞 | findings L7 | Apps E2E 测试替身缺 scanFolders(_:destinationBasePath:recursive:)，阻塞 M3 门禁 | TODO |
| 2 | P0 | 开发路径 | findings L6 | swift run 下 32 colorset 解析 nil → 生成式 Swift 回退表（同一 manifest，保单一真相源） | TODO |
| 3 | P1 | M2 | 规格 §4.2/§4.3 | 9 新组件 + AtlasScreen actionBar/drawer 插槽 + 修改/吸收/扩展清单 | TODO |
| 4 | P1 | M3 | 规格 §2/§3 | 壳层（侧栏/工具栏/菜单/任务中心/窗口）+ 路由改名 + ViewState + 8 屏迁移 | TODO |
| 5 | P1 | M4 | 规格 §0.4/§7 | L10n 键迁移（~120×2）+ 9 文档同步 + 截图基线 + 全量门禁 | TODO |
| 6 | P2 | 视觉 | findings L5 | 宋体粗体 face/traits（台账标题观感不足时） | DEFERRED→M2 内顺带评估 |

## Decision Log
- 2026-06-10: swift-run 色彩缺口采用方案 a「生成式 Swift 回退表」——generate-colorsets.mjs 从同一 manifest 额外产出 AtlasColorFallback.swift，AtlasColor 经 atlasColor(_:) 解析（named 命中走 catalog，缺失走 dynamicProvider 回退）；保持单一真相源，发布路径行为不变。
- 2026-06-10: 评审模式调整——批次内「实施者 + 单合并审查者（spec+质量合一）+ 客观门禁（build/test/contrast）」，控制器核 diff；理由：M0/M1 六轮两段审查全 Approve，门禁已脚本化。

## Surprises & Discoveries
- 2026-06-10 ~18:0x: Batch E 实施子代理（agentId a185efceb1cc29996）撞会话用量上限（19:00 Asia/Shanghai 重置），24 次工具调用后中断。
- Batch E Part 1 进行中发现：Apps 测试漂移比 findings 记录的更广——不止两个 E2E 替身缺 `scanFolders(_:destinationBasePath:recursive:)`，`refreshFileOrganizerPreview()` 也已改签名为 `refreshFileOrganizerPreview(entryIDs:)`，多处调用点需机械同步（子代理已改约 4+ 处，未跑测试、未提交）。

## CHECKPOINT（恢复指令）
- **工作树状态**: `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift` 有未提交的半成品修改（调用点签名同步）——**不要 checkout/clean 丢弃**。
- **恢复方式**: 限额重置后，向 agentId `a185efceb1cc29996` SendMessage「继续完成 Batch E：先跑 swift test --package-path Apps 看剩余编译错误，补完签名同步，然后按原指令完成 Part 1 commit、Part 2 色彩回退表、Part 3 CHG 登记」；或派新实施者（原始完整指令在会话 transcript 的 Batch E dispatch）。
- **恢复后续序**: Batch E 收口 → 合并审查 → M2 计划写入 Docs/plans/ → Batch F/G（9 组件）→ M3 Batch H–M → M4 Batch N → Phase 4 全量回归 → Phase 5 收口（trace 回填 + Close Gate）。
- **门禁基线**（重置前最后一次全绿）: Packages 384/0 · contrast 32/32 · Apps build OK（Apps test 因漂移仍红，Batch E 目标）。
