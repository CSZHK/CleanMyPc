# PER: 白话文案第二轮（菜单与功能文案重写）

**Status:** COMPLETED
**Created:** 2026-10-21
**Base:** 3716c48602a57d24ac2875989ad1beed53ee2405（工作树干净）
**Scope:** 两份 Localizable.strings（zh-Hans/en）、SettingsFeatureView.swift、AtlasDesignSystem.swift（AtlasInfoCard）、Docs/COPY_GUIDELINES.md、iterations/REQ-copy-plain-language/terminology-baseline.md
**Dimension:** 全量（上一轮已定稿的表 A–D；四项裁定：预演统一 / 去掉深度扫描承诺 / 删偏好中心层 / 系统词补进术语表）

## Progress
- [x] Phase 1: 范围确认（上轮 4 项裁定 + 用户以 PER 调用确认开工）
- [x] Phase 2: 证据链核实（孤儿键零引用；UITests 零断言将改文案；copy_gate C4 为硬编码 TERM_PAIRS、glossary. 为动态前缀豁免；AtlasInfoCard 11 调用点）
- [x] Phase 3: 实施修复
- [x] Phase 4: 回归验证
- [x] 4e 审查（独立审查者：验证面全绿；4 findings → 修 2（文档失真）+ 记录 2；未派二次复核，理由见 Decision Log）
- [x] 4e 复核（只一次；用掉就勾上）—— 未使用：4e 修复全为文档/注释精度，零代码路径变更，无复核对象
- [x] Phase 5: 收口总结

## Backlog
| # | Severity | Category | File:Line | Description | Status |
|---|----------|----------|-----------|-------------|--------|
| B1 | P1 | 黑话/规格句 | zh+en strings ×22 条 | 高信号/高置信度/命中链/标识符/破坏性操作/时间窗口/真实工作链路/特权辅助组件/后续迭代等 → 白话化（表 C） | FIXED |
| B2 | P1 | 一词多义 | strings | 方案vs计划、预览/预演/模拟运行三名并存、路径vs位置、复核vs待复核、可回收杂项（表 B+D） | FIXED |
| B3 | P1 | 孤儿键 | strings ×11 键 | route.history.*/sidebar.history.dynamic/smartclean.primary.*/settings.panel.* 零引用 → 删除（表 A+裁定3） | FIXED |
| B4 | P1 | 功能承诺失真 | overview.recommend.disk.headline | 「深度扫描」无此功能 → 改为不承诺新功能（裁定2） | FIXED |
| B5 | P1 | 代码+文案 | SettingsFeatureView.swift:56 | 删「偏好中心」层：AtlasInfoCard.title 改可选，调用传 nil（裁定3） | FIXED |
| B6 | P1 | 术语表 | glossary 键 + SettingsFeatureView.swift:11 | 证据类别系统词（容器/群组容器/保存状态）补进产品术语表 + COPY_GUIDELINES §7 + terminology-baseline §1-B（裁定4） | FIXED |

## Decision Log
- 不动 `xpc.error.*` / `settings.acknowledgement.*` / `notices.body`（门禁豁免的诊断/法定文案）。
- 不动 `fixture.*`（脚手架预览数据）、`about.author.*`（作者自述）。
- en 侧「预演」不引入新词：en 本就统一用 Preview，只把 dryRun 三个键对齐到 Preview，zh/en 语义对保持（预演↔Preview）。
- AtlasInfoCard 改 `title: String?`（默认 nil）而非重构调用点：11 个调用点全部源兼容，设计系统 API 变更最小化。
- 不改 copy_gate.py（未新增/修改任何门禁规则 → 变异检验 N/A；跑 `-v` 全量验证 C10 解析完整性）。
- **4e 处置**：finding-1（verify 第 5 步未兑现）→ 真跑 `export-readme-assets.sh` 闭环（`ATLAS_README_MEDIA_GATE=PASS`）；finding-2（brief 谎报 AtlasDesignSystem 改动）→ 修正 brief 为实际方案（空串传参，DS 零改动）；glossaryTermKeys 注释滞后 → 同步改写；finding-3（en「Preview」一词两义，涉及键为孤儿）→ 按 4c 记录不修；finding-4（未提交）→ 硬约束下默认态，提交待用户授权。**未派二次复核**：4e 修复全为 markdown/注释精度，零代码路径变更，复核无对象。

## Surprises & Discoveries
- `copy_gate.py` 的 C4 成对术语是**硬编码 TERM_PAIRS**（copy_gate.py:98），不解析 COPY_GUIDELINES.md 的表格——文档 §7 与机器判据实际是两套清单，靠人工保持一致。本轮只加词条不动词对，两侧同步更新。
- `smartclean.primary.*` 六个键是**写给评审的规格句**（「扫描应该是唯一主动作」）且零引用——它们从未被渲染，直接删除而非重写。
- glossary 渲染点注释要求「定义取自 terminology-baseline.md，不得自造」——故新词定义同步落基线文档 §1-B，保持该不变量为真。
- **4e 审查者发现 `fileorganizer.action.preview` / `action.dryRun` 实为孤儿键**（无 Swift 引用）——表 D 把它们当会渲染的按钮文案改了值；改动无害且值层面更一致，但「改了不渲染的键」说明键的引用面核查应前置于重写表，事后才知道哪些文案真的活在 UI 上。
- `export-readme-assets.sh` 的截图是 `[1/3] swift run`（重建后渲染），只有封面走 Chrome——「手抄 HTML 副本」担忧对截图不成立，副本局限只影响封面源。
