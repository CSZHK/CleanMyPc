# Verify — CHG-2026-09-ux-friction-wave3

**状态：✅ 已收口（2026-09-15）**

## 三条门禁

| # | 命令 | 结果 |
|---|------|------|
| 1 | `swift test --package-path Packages` | `612 / 0 failures` — **PASS** |
| 2 | `swift test --package-path Apps` | `68 / 0 failures` — **PASS** |
| 3 | `./scripts/atlas/run-ui-automation.sh` | **`11 tests, 0 failures, 0 skipped` — EXIT 0**（HEAD 基线 `4 tests / 2 failures`） |

第 3 条已无 skipped。

## 关闭的 finding（15 / 15）

| 分组 | finding |
|---|---|
| 契约四 P2 层 | `P2-1`（体系词解释 + **产品内术语入口**）· `P2-2`（同屏同名消歧）· `P2-3` · `P2-4`（译错修正）· `P2-5`（displayName 走 L10n） |
| 契约五 P2 层 | `P2-6`（估算/实测分流 + 独立分组容器）· `P2-7`（选择模型）· `P2-10`（不预选应用）· `P2-11`（两口径说明）· `P2-13`（About 版本号）· `P2-14`（截断说明）· `P2-15`（空态互斥）· `P2-16`（移除工具栏内部编号） |
| 契约六 | `P2-9`（诚实改名「同名同大小」）· `P2-12`（Settings 排除项**添加入口 + 移除**） |

## 契约四的交付物（只回写文档不算达标 ← 两件都做了）

- **双语术语表回写 `Docs/COPY_GUIDELINES.md` §Glossary**：en 单语 → zh/en 双语 19 条 + 拆词/量词规则 + 四个体系词的 zh 定义
- **产品内可读入口**：Settings 新增「术语表」（`AtlasSectionDisclosure`，四词 + 定义，定义取自 `terminology-baseline.md` §S-10，**不得自造**）

## 守卫

| # | 状态 |
|---|---|
| `I-10` | ✅ **已挂且实测通过** —— `testReceiptEstimateSitsInItsOwnGroup`：断言估算值在独立分组容器内，且实测组内不出现「预计」 |
| `I-12` | ✅ **已挂且实测通过** —— `ClassificationLabelTests`（3 条）：徽章如实描述判据、`Conditional` 是分类不是动作、风险 chip 不与阶段条同名；动作侧由 `I-7` 用例覆盖 |
| `I-9` | ✅ **已挂且实测通过**（质量修复轮转正，见下） |

### `I-9` 从 `NOT RUN` 转正（质量修复轮）

首轮守卫跑不起来：`taskcenter-many-runs` fixture 注入的 `taskRuns` **活不过启动** ——
`snapshot = output.snapshot` 在 worker 的 health / permissions / scan / execute 等路径上约有 20 处，
在**写入侧**追着补叠加是打地鼠（实测补 2 处后仍被冲掉）。

**正解：在读取侧施加** —— `taskCenterTaskRuns` 在 fixture 生效时直接返回纯函数
`uiTestFixtureTaskRuns()`，对重载次数完全免疫。

**同时纠正一处断言方式**：原先按 `identifier == "taskcenter.more"` 查不到 ——
popover 的 `.accessibilityIdentifier("taskcenter.panel")` 会**传播覆盖**子元素标识（实测子元素全是 `taskcenter.panel`）。
改为按**文案**断言 —— 规格 §7 原文即「断言存在**「还有 N 条」**」。

## 本波自身踩到并修复的错（留档）
1. 替换 `public struct PermissionsFeatureView` 的锚点打在 `struct` 上，**吃掉 `public`** → 跨模块编不过
2. 把 `_selectedAppID` 的赋值行替换成属性声明 → 错在 `init` 里（`attribute 'private' can only be used in a non-local scope`）
3. `TaskRun` 的 init 参数序（`summary` 在 `startedAt` 之前）


## 审查轮（2026-09-15）—— 找到并修复一处**行为缺陷**

### `P1-16` 的差分法有固有盲点：「不见了」≠「被清理了」

`surfaceExpiredRecoveryPruneIfNeeded()` 以「会话间 id 消失」判定被 prune。但**用户主动恢复**的项
同样会从 `recoveryItems` 消失（worker 恢复成功后 `removeAll { requestedItemIDs.contains($0.id) }`）——
于是：**恢复一条记录 → 重启 → 看到「N 条过期记录已被清理」**，与事实相反。

**修复**：恢复成功时把该项从「见过」集合剔除（`forgetSeenRecoveryItem`），在恢复侧补偿差分法的盲点。

### 这条测试我写错了两次（都靠变异检验抓出来，留档）

| 版本 | 症状 | 原因 |
|---|---|---|
| v1 | 变异后仍通过 | 断言了 `ledgerOutcome` —— 它是 `execution ?? plan`，而恢复成功写的是 execution 通道，**永远看不见那条 advisory** |
| v2 | 变异后仍通过 | 靠 init 副作用构造「上次见过」得到的是**空集合**，`disappeared` 永远为空 |
| **v3** | **变异后失败** ✅ | 显式写「见过」集合 + 断言 plan 通道 |

**教训**：**「测试通过」本身不是证据** —— 只有变异检验才证明它真的在断言那件事。
本 REQ 里 `I-11`（清空 `appMenuRoutes` → 用例失败）与本次是同一手法。

### 审查轮的最终门禁
`612/0` · **`69/0`**（+1 条经变异检验的用例）· UI `11 tests, 0 failures` **EXIT 0**
