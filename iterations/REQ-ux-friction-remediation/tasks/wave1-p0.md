# Wave 1（P0）—— 契约一 + 契约二 + 契约三(1)(2)(3) + 守卫基座

## Objective
按规格 §9 Wave 1 行交付 P0 层。**Wave 0 签字阻塞本波。**

## 范围（§9）
- **契约一全量**（`P0-1` `P0-2` `P1-8` `P1-11` `P1-14` `P1-17` + `NEW-1`）：`AtlasActionOutcome` 模型 + 三态控件 + 失败出口 + 两种恢复分流
- **契约二全量**（`P0-3` `P0-4` `P0-5` + `P1-10`）：四问约束组件 + 标签—后果一致
- **契约三 (1)(2)(3)**（`P1-1` `P1-2` `P1-3`）：横幅可推迟 + 首页顺序 + 就地索取/TCC 前置说明
- **守卫基座**（§9 纪律 4）：UI 状态注入能力（经 `ATLAS_STATE_FILE` 预置快照，现仅冷启动空状态一种）、Feature 包 `accessibilityIdentifier` 投放（现全仓 30 处，`AtlasDesignSystem` 零投放）、`AtlasAppUITests` 新用例

## 波次纪律（不得违反）
1. **契约一与契约二各自作为原子变更整波交付，不按 P 级拆分**——契约一的 P1 条目与其 P0 条目共用同一次模型变更；契约二的四问是组件 API 层面非可选字段，无法只对其中三条生效
4. **守卫基座属本波交付物**；基座缺失时不变量记 `NOT RUN`，**不得报 `Pass`**

## 涉及文件（预估）
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`（公开 API 变更 + `NEW-1` 的 `.advisory` 分流）
- `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift`（调用点同步）
- `Packages/AtlasFeaturesSmartClean`、`Packages/AtlasFeaturesFileOrganizer`、`Packages/AtlasFeaturesApps`、`Packages/AtlasFeaturesOverview`、`Packages/AtlasFeaturesHistory`
- 两份 `Localizable.strings`（N-1..N-6 定稿措辞）
- `Apps/AtlasApp/Tests/AtlasAppTests/`（I-1 模型单测）
- `Apps/AtlasAppUITests/`（I-2 I-3 I-4 渲染断言）
- `Packages/AtlasFeaturesOverview/Tests/`（I-6）

## 本波覆盖的不变量
| # | 不变量 | 守卫载体 |
|---|---|---|
| I-1 | 失败结果不得写入非本 source 的槽位 | `AtlasAppModelTests` |
| I-2 | 无恢复项时撤销控件不得可点 | `AtlasAppUITests` |
| I-3 | 可恢复动作的回执在无可恢复项时不得静默隐藏 | `AtlasAppUITests` |
| I-4 | `.destructive` 弹窗渲染 ①②③；④ 由类型区分 | 构造器非可选 + 类型 + `AtlasAppUITests` 渲染断言 |
| I-5 | 授权请求前已有作用域说明 | 模型单测（**已降级**）+ 人工验收项 |
| I-6 | `isSnoozeable: false` 横幅须说明后果 | `OverviewRecommendation` 单测 |
| I-12 | 徽章/标签须有对应动作或说明其只是分类 | `AtlasAppUITests` + strings 断言（**部分在本波**） |

## 注意（易踩）
- `OverviewRecommendationTests.swift:56` 现断言「permission banner is never snoozeable」——`P1-1` 会推翻该断言，须同步更新
- `NEW-1` 的非错误渲染路径已存在（`SmartCleanStageViews.swift:52` 的 `AtlasCallout(tone: .warning)`），不必新增
- 门禁 `NOT RUN` 失败断言已于 2026-09-14 独立完成，**不在本波范围**（§9 明文）

## Verify（三条缺一不可）
```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/run-ui-automation.sh
```
第三条若输出 `Skipping native UI automation` → 计 `NOT RUN`、**不得收口**（除非显式 `ATLAS_ALLOW_UI_SKIP=1` 并在回执写明接受覆盖缺口）。

## Stop Condition
- 命中 `UC / INV / CONTRACT / infra` → 停下来升级给人
- 守卫基座做不出来 → 该不变量记 `NOT RUN` 并如实上报，**不得用「守卫写了但跑不了」冒充覆盖**（§9 纪律 4）
- 撞到规格未覆盖的情况 → 停下来问，不自行决定
