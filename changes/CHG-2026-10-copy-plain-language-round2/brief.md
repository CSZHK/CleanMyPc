# CHG-2026-10-copy-plain-language-round2

**REQ 基线**: `iterations/REQ-copy-plain-language`（2026-09-15 白话化的第二轮）
**裁定来源**: 2026-10-21 会话，用户逐项确认的对照表 A–D 与四项裁定（预演统一 / 不承诺深度扫描 / 删偏好中心层 / 系统词补进术语表）。
**Change Class**: 文案 + 少量 UI 结构（删一层卡片标题）+ 判据文档同步。

## 改动清单

1. **两份 Localizable.strings 同步**（zh-Hans / en）：43 键改写、11 孤儿键删除、6 键新增（术语表 ×3 词）。
2. **AtlasFeaturesSettings**：设置页删「偏好中心」标题层——`AtlasInfoCard(title: "")` 传空串，`AtlasDesignSystem.swift` 的 `!title.isEmpty` 守卫使头部整块不渲染；**设计系统源码零改动**（曾评估把 `title` 改 `String?`，实做取更小方案，11 个既有调用点不受影响）。
3. **AtlasFeaturesSettings**：设置页删「偏好中心」标题层；`glossaryTermKeys` 增 `containers / groupcontainers / savedstate`。
4. **Docs/COPY_GUIDELINES.md**：§7 术语表与「体系词解释」补 3 个系统词；不改任何门禁规则（copy_gate.py 零改动）。
5. **terminology-baseline.md**：§1-B「保留不动」补 3 条（含定义），维持「产品内定义取自基线」不变量。

## 明确不做

- 不动 `xpc.error.*` / 法定文案 / `fixture.*` / `about.author.*`。
- 不动侧边栏分组（`sidebar.section.*`，结构裁定另行）。
- 不动 en 的 Preview 用词体系（en 本就统一，仅对齐 dryRun 三键）。

## 验收协议

见本目录 `verify.md`。
