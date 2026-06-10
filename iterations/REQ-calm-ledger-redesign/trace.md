# REQ-calm-ledger-redesign Trace

## Validation Protocol
- 每任务: 计划文档内的 verify 命令（含期望输出）
- 每里程碑: swift build --package-path Apps + swift test --package-path Packages + node scripts/design/contrast-check.mjs
- M3 起每屏: 手动矩阵抽查（双语言 × 双外观 × 两档内容宽）
- 最终: 规格 §7 全量验收 + 人工 UI 审查

## Blast Radius
- Packages/AtlasDesignSystem: token 全量重铸 + 9 新组件 + AtlasScreen 插槽
- Packages/AtlasFeatures*: 8 个路由屏对应的 feature 包（6 个重写/拆分，Settings/About 换装级；AtlasFeaturesStorage 无路由不触碰）
- Apps/AtlasApp: 壳层（侧栏/工具栏/任务中心/菜单/窗口尺寸）+ AtlasAppModel ViewState
- Packages/AtlasDomain: AtlasRoute 改名 + L10n 键迁移（~120 键 × 2 语言）
- 不触碰: AtlasProtocol / AtlasInfrastructure / XPC / Helpers / Go

## Required Validation Modules
- swift build --package-path Apps
- swift test --package-path Packages / Apps / Helpers
- node scripts/design/contrast-check.mjs（M1 起为合并门禁）
- 人工: 手动矩阵 + zh/en 台账声部对比 + VoiceOver 抽查

## Docs Sync（规格 §0.4 全表）
DECISIONS(D-012) / Backlog(EPIC-E + A/B/C 完成标记，后者随 M4) / IA / COPY_GUIDELINES / DESIGN_SPEC(头注) / PRD / ROADMAP / HELP_CENTER_OUTLINE / WORKSPACE_LAYOUT / README 截图 / Docs/product 入库

## Planned Verification
| Phase | Verify Command | Status |
|-------|---------------|--------|
| M0 | git log 检查 5 个内容提交 + 1 个收口提交；ls iterations/REQ-calm-ledger-redesign | PASS |
| M1 | node scripts/design/contrast-check.mjs && swift test --package-path Packages && swift build --package-path Apps | PASS |
| M2 | swift test --package-path Packages（新组件单测全绿） | PENDING |
| M3 | swift test --package-path Packages && swift test --package-path Apps + 每屏手动矩阵 | PENDING |
| M4 | ./scripts/test.sh + 截图重导 + 双语言键集合 diff 脚本 0 缺失 | PENDING |

## Actual Verification
（执行时填写）
- M0 (2026-06-10): 分支 redesign/calm-ledger，main..HEAD 6 commits（5 内容 + 1 收口），16 文件 883 插入 0 删除，治理工件齐备（spec 审查字节级一致）
- M1 (2026-06-10): contrast-check 32/32 ALL PASS；colorset 生成幂等（porcelain 0）；Packages 384 tests / 0 failures（377 存量 + 7 新增）；Apps build complete；宋体 cascade 实测 family=Songti SC（无需降级）；№ U+2116 glyph 可用（glyphID 1710）

## Actual Deliverables
（执行时填写）

### M0+M1（CHG-2026-06-calm-ledger-m0m1）
- 治理: D-012 / EPIC-E / REQ 包 / CHG 包 / .agent 三件套
- Token 真相源: scripts/design/calm-ledger-tokens.json（32 色 + 16 对比对）
- 门禁: contrast-check.mjs（32 检查，hex 守卫）+ generate-colorsets.mjs（幂等，32 colorset）
- Swift v3: AtlasColor 全 colorset 化（去 @MainActor）/ 三声部 AtlasTypography（含 Songti cascade）/ AtlasMotion +2 / AtlasLayout 断点 / 高程 −30%
- 测试: +7（token 存在性 ×4、字体探针 ×2、colorset 解析守卫 ×1），共 384 绿

## Close Gate
M0–M4 全部 Planned Verification = PASS + 手动矩阵 + 人工 UI 审查通过
