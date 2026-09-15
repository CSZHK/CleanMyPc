# Wave 2（P1）—— 契约三余项 + 契约六 P1 + 契约四 P1 + 契约五 P1

## Objective
按规格 §9 Wave 2 行交付 P1 层。

## 范围（§9）
- **契约三余项**：`P1-5`（去技术黑话）· `P1-6`（跳转后二次引导）· `P2-8`（FO 补权限受限态）
- **契约六**：`P1-7`（Smart Clean ② 补全选/取消全选）· **`P1-18`（CONTRACT）**
- **契约四**：`P1-4`（权限计数口径）· `P1-13`（冲突口径统一）· `P1-15`（「已归档」拆词）
- **契约五**：`P1-9`（执行中不作无意义不确定态）· `P1-12`（折叠态透出去向）· `P1-16`（过期恢复项不留静默消失）

## 硬门禁
**`P1-18` 触 `AtlasAppCommands.swift`，属 CONTRACT，开工前须产品负责人签字**（`requirement.md` 的 `## Contract Unfreeze Record` 第 2 项）。

## I-11 的三个前置依赖（缺一则守卫不可用；实现顺序不可颠倒）
1. **访问级别（编不过）**：`shortcutKey` 声明在 `private extension AtlasRoute`（`AtlasAppCommands.swift:86`）。文件级 `private` 对 extension 成员等价 `fileprivate`，而 `@testable import` **只放开 `internal`** —— 不先提到 `internal`，守卫**编不过**（`inaccessible due to 'fileprivate' protection level`）。
2. **崩溃点（不是断言失败）**：`shortcutKey` 现对 `.settings / .about` 走 `preconditionFailure("Non-sidebar routes have no shortcut key")`（`AtlasAppCommands.swift:101-102`）。直接遍历 `allCases` 调用会**崩掉测试进程** —— 必须先改为返回 `KeyEquivalent?`。**这正是已标 CONTRACT 的那处改动。**
3. **断言对象**：`AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132`），**不是 `CommandMenu`**（SwiftUI View body，不可枚举）。

**守卫落点（不可写错）**：`Apps/AtlasApp/Tests/AtlasAppTests/`（`@testable import AtlasApp`），**不是** `Packages/AtlasDomain/Tests/` —— 放错包会让本波的验证命令**漏跑它**（只有 `swift test --package-path Apps` 覆盖它）。

## 本波覆盖的不变量
| # | 不变量 | 守卫载体 | 备注 |
|---|---|---|---|
| I-7 | 同一屏内两个**不同动作**的可交互控件不得共用同一可见标签 | `AtlasAppUITests` | 枚举 Button / Link / DisclosureGroup 标签；**纯分类标签（`AtlasMetricCard` / `AtlasStatusChip` / 阶段条）不计入** |
| I-8 | 同一计数在相邻两处不得给出相反结论 | **拆两个载体**：模型单测断言两处同源；`AtlasAppUITests` 只断言两文案键仍渲染 | 口径是模型层事实，UI 层读不到 |
| I-11 | 每个路由至少两条可达路径 | 路由遍历单测（落点见上） | **本规格最重要的一条** |

## 用词来源
本波全部改词取自 `terminology-baseline.md`（S-1 / S-2 / S-3 / S-5 / S-6 / S-7 / S-8 与 4-A 对齐清单）。**不得就地自造词** —— 那会绕过契约四的 CONTRACT 签字。

## Verify（三条缺一不可）
```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/run-ui-automation.sh
```
`Skipping native UI automation` → 计 `NOT RUN`、不得收口（除非显式 `ATLAS_ALLOW_UI_SKIP=1` 并在回执写明）。

## Stop Condition
- `P1-18` 未签字 → **不开工**
- 命中 `UC / INV / CONTRACT / infra` → 停下来升级给人
- 守卫基座缺失 → 该不变量记 `NOT RUN`，不得报 `Pass`
