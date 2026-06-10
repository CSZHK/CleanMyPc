# PER: Calm Ledger 重设计全量收口（M2 → M3 → M4）

**Status:** IN_PROGRESS
**Created:** 2026-06-10
**Scope:** Packages/AtlasDesignSystem · Packages/AtlasFeatures* · Apps/AtlasApp · AtlasDomain（路由/L10n）· Docs/*（同步清单）
**Dimension:** 全量 · 深度: 标准（P0+P1）
**Canonical truth:** 规格 Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1) · REQ iterations/REQ-calm-ledger-redesign/ · findings .agent/calm-ledger-redesign-findings.md（本文件只做编排跟踪，不复制内容）

## Progress
- [x] Phase 1: 范围确认（用户指令「全部干完」，无暂停点）
- [x] Phase 2/3: M2 组件层（Batch E 前置修复 + Batch F/G 组件；CHG-m2 6/6 PASS 已关闭）
- [ ] Phase 2/3: M3 屏幕迁移（Batch H 壳层/改名 → I 智能清理样板间 → J 台账 → K 概览 → L 应用/整理 → M 权限/设置/关于）
- [ ] Phase 2/3: M4 收尾（L10n / 文档同步 / 截图 / 门禁）
- [ ] Phase 4: 跨边界回归（全量测试 + 门禁 + 构建）
- [ ] Phase 5: 收口总结（trace 回填 + Close Gate）

## Backlog
| # | Severity | Category | Source | Description | Status |
|---|----------|----------|--------|-------------|--------|
| 1 | P0 | 测试阻塞 | findings L7 | Apps E2E 测试替身缺 scanFolders(_:destinationBasePath:recursive:)，阻塞 M3 门禁 | FIXED |
| 2 | P0 | 开发路径 | findings L6 | swift run 下 32 colorset 解析 nil → 生成式 Swift 回退表（同一 manifest，保单一真相源） | FIXED |
| 3 | P1 | M2 | 规格 §4.2/§4.3 | 9 新组件 + AtlasScreen actionBar/drawer 插槽 + 修改/吸收/扩展清单 | FIXED |
| 4 | P1 | M3 | 规格 §2/§3 | 壳层（侧栏/工具栏/菜单/任务中心/窗口）+ 路由改名 + ViewState + 8 屏迁移 | TODO |
| 5 | P1 | M4 | 规格 §0.4/§7 | L10n 键迁移（~120×2）+ 9 文档同步 + 截图基线 + 全量门禁 | TODO |
| 6 | P2 | 视觉 | findings L5 | 宋体粗体 face/traits（台账标题观感不足时） | FIXED（M2 Batch F 评审修复 068a4da：cascade 描述符按 weight 带 face，bold 实测解析 STSongti-SC-Bold，测试锁定） |
| 7 | P0 | 测试阻塞 | Batch E 发现 | AtlasAppModel.swift:696 `NSApp.appearance` 强解包——裸 swift test 无 NSApplication，29 测试全崩（来源 main 4ff6c08，此前被编译失败掩盖） | FIXED |
| 8 | P0 | 开发路径 | Batch E 发现 | 裸 swift-run 无 .app bundle，UNUserNotificationCenter 权限链抛 NSException 启动即崩（stash 基线证明 pre-existing） | FIXED |
| 9 | P0 | 可达性 | Batch G 发现 | 深色「白字 on brand」2.56:1 <AA——波及主按钮/横幅/行动栏主操作（gate 只测过反向 brand-on-surface） | TODO→Batch H |

## Decision Log
- 2026-06-10: swift-run 色彩缺口采用方案 a「生成式 Swift 回退表」——generate-colorsets.mjs 从同一 manifest 额外产出 AtlasColorFallback.swift，AtlasColor 经 atlasColor(_:) 解析（named 命中走 catalog，缺失走 dynamicProvider 回退）；保持单一真相源，发布路径行为不变。
- 2026-06-10: 评审模式调整——批次内「实施者 + 单合并审查者（spec+质量合一）+ 客观门禁（build/test/contrast）」，控制器核 diff；理由：M0/M1 六轮两段审查全 Approve，门禁已脚本化。
- 2026-06-10: Backlog #9 决策——新增 `AtlasOnBrand` token（light #FFFFFF / dark #0C1614，与视觉方向板深色稿一致：暗字亮底）+ `AtlasBannerEnd` 渐变端 token（light #0C5F58 加深 / dark #2BC4B1）；主按钮/横幅/行动栏主操作文字一律 onBrand，bannerGradient 第二停改 BannerEnd；新增 2 对比对（OnBrand×Brand、OnBrand×BannerEnd），四向预算 5.47/7.24/6.9/8.5 全 ≥4.5。落 Batch H；产品负责人不认可暗字亮底可单 token 回退。
- 2026-06-10: 台账编号与回执派生（规格 §1.6 落地细则）——`AtlasSettings` 增 `ledgerNextNumber: Int`（decode 默认按「既有任务运行数+1」一次性初始化，D-011 版本化信封内向后兼容）；扫描完成产出计划时分配 № 并自增，重扫作废旧 № 产新 №；历史任务运行无存储 № 者按时间序计算展示编号（仅限计数器引入前的存量，无碰撞）。回执 #XXXX = 扫描摘要稳定串 SHA256 前 4 hex，存于屏幕 ViewState，工具栏芯片显示当前路由模块最近回执。协议层零改动。

## Surprises & Discoveries
- 2026-06-10 ~18:0x: Batch E 实施子代理（agentId a185efceb1cc29996）撞会话用量上限（19:00 Asia/Shanghai 重置），24 次工具调用后中断。
- Batch E Part 1 进行中发现：Apps 测试漂移比 findings 记录的更广——不止两个 E2E 替身缺 `scanFolders(_:destinationBasePath:recursive:)`，`refreshFileOrganizerPreview()` 也已改签名为 `refreshFileOrganizerPreview(entryIDs:)`，多处调用点需机械同步（子代理已改约 4+ 处，未跑测试、未提交）。

## CHECKPOINT（恢复指令，更新于 M2 收口后）
- **工作树状态**: 干净（M2 全部已提交，HEAD = CHG-m2 收口提交 0152230）。
- **恢复后续序**: M3 计划（Docs/plans/2026-06-10-calm-ledger-m3.md）→ Batch H（token 增补 + ViewState + 路由改名 + 壳层）→ I 智能清理样板间 → J 台账 → K 概览 → L 应用/整理 → M 权限/设置/关于 + M3 治理收口 → M4 Batch N → Phase 4 全量回归 → Phase 5 收口。
- **门禁基线**（M2 收口）: Packages 411/0 · Apps 29/0 · contrast 33 colorsets ALL PASS · Apps build 0 warning。
