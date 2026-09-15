# CHG-2026-09-ux-friction-wave1

- REQ: REQ-ux-friction-remediation
- Task: wave1-p0
- Scope: 契约一全量 · 契约二全量 · 契约三 (1)(2)(3) · 守卫基座 · 契约四 P0 用词
- Canonical Plan: `Docs/design/2026-09-14-ux-friction-remediation.md` §9 Wave 1 行 + `iterations/REQ-ux-friction-remediation/tasks/wave1-p0.md`
- 前置: Wave 0 术语基线**已签字**（2026-09-14，`requirement.md` § 签字记录 1）

## 原子性（§9 纪律第 1 条）

**契约一与契约二各自整波交付，不按 P 级拆分。**
- 契约一的 P1 条目（`P1-8` `P1-11` `P1-14` `P1-17`）与它的 P0 条目共用同一次 `AtlasActionOutcome` 模型变更——拆开就要把该模型做两遍
- 契约二的四问约束是**组件 API 层面的非可选字段**，无法只对其中三条生效

## 涉及范围

| 层 | 内容 |
|---|---|
| `Packages/AtlasDomain` | 新增 `AtlasActionOutcome` 及其从属类型；新增 L10n 键（两份 strings） |
| `Apps/AtlasApp` | `AtlasAppModel` 公开 API 变更（结构化 outcome 取代 5 条模块级摘要串 + 2 个 `planIssue: String?`）；`AppShellView` 调用点同步 |
| `Packages/AtlasFeatures{SmartClean,FileOrganizer,Apps,Permissions,History,Overview}` | 渲染路径改造（`.advisory` vs `.failed`、三态控件、四问弹窗、首页顺序、TCC 前置说明） |
| `Apps/AtlasAppUITests` | 守卫基座：状态注入 + 新用例 |
| `Apps/AtlasApp/Tests/AtlasAppTests` | I-1 模型单测；既有断言随 API 变更同步 |

## 守卫基座（§9 纪律 4，本波交付物）

1. **UI 测试的状态注入能力** —— 经 `ATLAS_STATE_FILE` 预置快照（现仅冷启动空状态一种）
2. **Feature 包内的 `accessibilityIdentifier` 投放**（现全仓仅 30 处）
3. **`AtlasAppUITests` 内的新用例**（现 4 个，无一对应 §7）

**基座缺失时，对应不变量记 `NOT RUN`，不得报 `Pass`。**

## 用词来源

契约四 P0 用词取自 `iterations/REQ-ux-friction-remediation/terminology-baseline.md` §3（N-1..N-6）。**不得就地自造词。**
