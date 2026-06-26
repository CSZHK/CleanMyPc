# REQ-calm-ledger-redesign

## Title
Calm Ledger 前端全面重设计（一次到位）

## Change Class
MAJOR — 全部 8 屏 + 壳层 + 设计系统 v3 + IA 改名，长分支整体交付

## Status
CLOSED — V2.0.0 released 2026-06-26 (commit e0044c2, tag V2.0.0 pushed to origin)

## Priority
P0（EPIC-E；非 mainline，受 EPIC-D 中断协议约束）

## Truth Sources
- 设计规格: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1)
- 决策: Docs/DECISIONS.md (D-009 / D-010 / D-012)
- IA: Docs/IA.md（M4 同步）
- 文案: Docs/COPY_GUIDELINES.md（M4 同步）
- 实施计划序列: Docs/plans/2026-06-10-calm-ledger-m0-m1.md（M2/M3/M4 计划在里程碑边界补充）

## Description
按规格 v1.1 执行「Calm Ledger · 平静台账」重设计：三声部字型、双气质表面色彩、阶段条 + 证据面板 + 行动栏骨架、历史→台账改名、概览三段式。纯前端：Worker / XPC / 协议零改动。

## Contract Unfreeze Record
- `AtlasDomainTests.testPrimaryRoutesMatchFrozenMVP` 冻结路由名包含「历史」；本 REQ 依据 D-012 与产品负责人 2026-06-10 会话确认将其解冻为「台账」。

## Project Constraints
- Swift 6 strict concurrency；macOS 14.0+；不引入第三方依赖
- 全部用户可见字符串过 AtlasL10n（zh-Hans 默认 + en）
- Feature 包只依赖 AtlasDesignSystem + AtlasDomain
- 协议层（AtlasCommand/Response/Event）与 Worker 行为不变（回归红线）
- 每视图文件 ≤ 350 行；可达性红线见规格 §6

## Acceptance（取自规格 §0.2 / §7）
- 8 屏 + 壳层表面全部迁移，无双轨并存
- 对比度脚本（scripts/design/contrast-check.mjs）全部 PASS
- 既有测试（Packages 377 + Apps 29 + Helpers 16）经更新后全绿；新组件有单测
- 双语言 × 双外观 × 两档内容宽手动矩阵通过；zh/en 台账声部截图对比专项通过
- 截图基线重导出（atlas-history.png → atlas-ledger.png 含 README 引用）
