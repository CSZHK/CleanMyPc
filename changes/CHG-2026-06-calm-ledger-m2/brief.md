# CHG-2026-06-calm-ledger-m2
- REQ: REQ-calm-ledger-redesign（M2 组件层里程碑）
- Canonical Plan: Docs/plans/2026-06-10-calm-ledger-m2.md（Batch F + Batch G）
- Scope:
  - Batch F 新组件（5）: AtlasStageBar / AtlasEvidencePanel(+AtlasEvidenceModels) / AtlasActionBar / AtlasLedgerTimeline / AtlasStampBadge
  - Batch G 新组件（4）: AtlasLedgerSurface(+atlasLedgerRule) / AtlasNextActionBanner / AtlasErrorState / AtlasDataText(atlasData()/atlasDataCaption()/AtlasCountUpText)
  - AtlasScreen 结构插槽: actionBar（safeAreaInset(.bottom)，AtlasActionBarHeightKey 高度上报，既有调用点零改动）+ screenTitle tracking −0.3 + 字号钳制上限文档化（findings 遗项 ①②③ 全部处置）
  - 修改清单（G6）: AtlasCircularProgress（AngularGradient conic，起止同色防接缝）/ AtlasToast（actionTitle/onAction/onTap，零改动兼容）/ AtlasTone fill→语义 fill colorset（StatusChip/Callout 等全消费者）/ AtlasFilterChip（surfaceSubdued/surfaceInput）/ AtlasEmptyState/AtlasLoadingState token 复核 + reduce-motion 守卫 / AtlasSkeleton 注释定性 / AtlasEvidenceGroupCard 弃用标记（typealias 方案保零 warning）
  - L10n: ds.* 键 19 → 26（zh/en 同步）
- 不在范围: feature 包业务逻辑、App 壳层路由、屏幕迁移（M3）；colorset 集合不变（33）
