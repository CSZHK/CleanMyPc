# REQ-calm-ledger-redesign Trace

## Validation Protocol
- 每任务: 计划文档内的 verify 命令（含期望输出）
- 每里程碑: swift build --package-path Apps + swift test --package-path Packages + node scripts/design/contrast-check.mjs
- M3 起每屏: 手动矩阵抽查（双语言 × 双外观 × 两档内容宽）
- 最终: 规格 §7 全量验收 + 人工 UI 审查

## Blast Radius
- Packages/AtlasDesignSystem: token 全量重铸 + 9 新组件 + AtlasScreen 插槽
- Packages/AtlasFeatures*: 全部 6 个 feature 包视图重写/拆分
- Apps/AtlasApp: 壳层（侧栏/工具栏/任务中心/菜单/窗口尺寸）+ AtlasAppModel ViewState
- Packages/AtlasDomain: AtlasRoute 改名 + L10n 键迁移（~120 键 × 2 语言）
- 不触碰: AtlasProtocol / AtlasInfrastructure / XPC / Helpers / Go

## Required Validation Modules
- swift build --package-path Apps
- swift test --package-path Packages / Apps / Helpers
- node scripts/design/contrast-check.mjs（M1 起为合并门禁）
- 人工: 手动矩阵 + zh/en 台账声部对比 + VoiceOver 抽查

## Docs Sync（规格 §0.4 全表）
DECISIONS(D-012) / Backlog(EPIC-E) / IA / COPY_GUIDELINES / DESIGN_SPEC(头注) / PRD / ROADMAP / HELP_CENTER_OUTLINE / WORKSPACE_LAYOUT / README 截图 / Docs/product 入库

## Planned Verification
| Phase | Verify Command | Status |
|-------|---------------|--------|
| M0 | git log 检查 5 个治理 commit；ls iterations/REQ-calm-ledger-redesign | PENDING |
| M1 | node scripts/design/contrast-check.mjs && swift test --package-path Packages && swift build --package-path Apps | PENDING |
| M2 | swift test --package-path Packages（新组件单测全绿） | PENDING |
| M3 | swift test --package-path Packages && swift test --package-path Apps + 每屏手动矩阵 | PENDING |
| M4 | ./scripts/test.sh + 截图重导 + 双语言键集合 diff 脚本 0 缺失 | PENDING |

## Actual Verification
（执行时填写）

## Actual Deliverables
（执行时填写）

## Close Gate
M0–M4 全部 Planned Verification = PASS + 手动矩阵 + 人工 UI 审查通过
