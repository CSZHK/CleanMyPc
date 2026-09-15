# Verify — CHG-2026-09-copy-plain-language

**状态：✅ 已收口（2026-09-15）—— 工程侧 completed，CONTRACT 追认 R-1..R-6 已签字**

> 收口后又追加了 **pass 5**（变形残留 + en 搭配错误 + 术语表收缩）与**守卫变异检验**，见文末两节。

## 门禁命令矩阵

| # | 命令 | 基线 | 实测 | 判定 |
|---|------|------|------|------|
| 1 | `./scripts/atlas/copy-gate.sh` | `FAIL:263`（改动前） | `PASS`，阻断维全零 | **PASS** |
| 2 | `swift test --package-path Packages` | `612 / 0` | `613 / 0`（+2 条新守卫 −1 条退役的 `№` 字形守卫） | **PASS** |
| 3 | `swift test --package-path Apps` | `72 / 0` | `72 / 0` | **PASS** |
| 4 | `bash -n scripts/atlas/full-acceptance.sh` | — | 语法 OK，第 4 步已插入 | **PASS** |

**未纳入矩阵**：`run-ui-automation.sh`。本次改动是文案值与文档，**不触渲染逻辑**，无 UI 行为可验。

**补做**：真机视觉验收用仓库自带截图管线（`ATLAS_EXPORT_README_ASSETS_DIR`）渲染全部屏幕 —— 见下方「真机视觉验收」节。对照 `REQ-ux-friction-remediation` 把三条命令列为「缺一不可」—— 那条约束适用于触 UI 行为的 change，不适用于本 change。

## 门禁八维明细（实测）

```
✓ C1 术语禁用表          0        ✗→✓  基线 217
✓ C2 副标题超宽          0        ✗→✓  基线   7
✓ C3 副标题规格句式       0        ✗→✓  基线   3
✓ C4 术语映射不一致       0        ✗→✓  基线  36
✓ C6 占位符不对称         0        基线   0（改前改后均零）
✓ C7 键集合不 parity     0        基线   0（改前改后均零）
─────────────────────────────────────────
  C5 孤儿键             310  ← 报告维，归 ATL-272，不参与判定
  C8 长句                 6  ← 报告维，不参与判定
ATLAS_COPY_GATE=PASS
```

**维度分别复算、分别归零** —— 不是「C1 全清所以其余也对」（`iteration-governance` 的 Validation Gate 纪律）。

## 门禁卫生自检

| 规则 | 落实 |
|---|---|
| 命令必须区分「跳过」与「通过」 | 文案源缺失时返回 **2** 并打印 `ATLAS_COPY_GATE=NOT_RUN`，**不是 0**。对照 `run-ui-automation.sh` 曾在 AX 未授权时 `exit 0` 的反面案例 |
| 上游只认哨兵、不认人类可读文案 | `full-acceptance.sh` 直接以退出码判定（`set -euo pipefail`），不 grep 英文句子 |
| **守卫是否真的会红（变异检验）** | 见下方专节 —— 本仓库刚因 4 条「改坏产品代码仍不失败」的**空转守卫**栽过跟头，故新守卫一律做变异检验 |

## 回归处置（2 处）

| 失败用例 | 根因 | 处置 | 复验 |
|---|---|---|---|
| `AtlasDomainTests.testPrimaryRoutesMatchFrozenMVP` | 断言路由标题含「台账」 | 期望值改「历史记录」；`Unfrozen row` 注释改为**二次解冻**记录，指向本 REQ | ✅ |
| `LedgerModelTests.testExportBuilderEmptyEntriesShowsPlaceholder` | 断言导出占位符含「台账」 | 随 `ledger.export.empty` 更新 | ✅ |

## 交付物清单

| 类型 | 路径 |
|---|---|
| 门禁脚本 | `scripts/atlas/copy-gate.sh` · `scripts/atlas/copy_gate.py` |
| 上游接入 | `scripts/atlas/full-acceptance.sh` 第 `[4/12]` 步（并重编号 `/11` → `/12`） |
| 设计规格 | `Docs/design/2026-09-15-copy-plain-language.md` |
| 术语基线 | `iterations/REQ-copy-plain-language/terminology-baseline.md` |
| 文案规范 | `Docs/COPY_GUIDELINES.md`（zh 侧判据 + 术语表 + 语域规则重写） |
| 设计语言 | `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md`（v4） |
| 文案值 | 两份 `Localizable.strings`（键名未动） |
| 回归修复 | `AtlasDomainTests.swift` · `LedgerModelTests.swift` |
| 约定登记 | `AGENTS.md`（新增「文案门禁」条） |
| README 截图 | `Docs/Media/README/` 四张（旧图含旧文案 + 中文日期 bug，已用 `export-readme-assets.sh` 重生成）；新增 `atlas-icon.png`（导出器产出，`LandingSite/DESIGN.md` 记录其归属） |
| 守卫修复 | `AtlasDesignSystem.swift` 的日期 locale（视觉验收查出，早于本 REQ 存在）+ 新测试 `AtlasFormattersLocaleTests` |

## 未完成项（**如实记录，不掩盖**）

| 项 | 状态 | 说明 |
|---|---|---|
| ~~R-1..R-6 产品负责人签字~~ | **✅ 已完成（2026-09-15）** | 产品负责人逐项签字，准予合入。记录见 `iterations/REQ-copy-plain-language/requirement.md` → 签字记录 1 |
| en 侧母语审校 | 未做 | 见 REQ 不做项 N-4 |
| 孤儿键删除 310 条 | 未做 | 显式排除，归 `ATL-272` |
| ~~`copy-gate.sh` 纳入 CI~~ | **已覆盖，无需改** | `atlas-acceptance.yml:38` 跑的就是 `./scripts/atlas/full-acceptance.sh`，而门禁已在其第 [4/12] 步，`set -euo pipefail` 下非零即红。**先前「CI workflow 未改」的说法在效果上是错的**，此处更正 |

## Pass 5 —— 收口后的追加修缮

门禁全绿**之后**、人工通读**之前**，发现 C1 的字面禁用表存在**漏网形态**：

| 漏网 | 例 | 为什么字面表抓不到 |
|---|---|---|
| 「发现」的**名词化/语序变体** | `"%d 项发现待处理"` | 字面表列的是「发现项」三连字，`项发现` 不匹配 |
| 「审计」 | `"这里会开始形成审计轨迹"` | 未列入禁用表（当时只列了「主流程」） |
| en 的**搭配错误** | `"Refresh App Storages"` | Storage 不可数；机械替换把 `footprint→storage` 后产生了复数形态，字面表无从表达 |

**处置**：修掉 6 处 zh（4 处「%d 项发现」+ 2 处「审计」）+ 19 处 en，并把这三类形态**补进门禁的 C1b 正则维** —— 每发现一次漏网就补一条规则。

**术语表收缩**：原 4 词（残留 / 足迹 / 台账 / 证据）在术语退役后，「占用」「历史记录」已是不言自明的白话，**术语表不该解释不需要解释的词**。收缩为 3 词（残留 / 未删除项 / 恢复点），`SettingsFeatureView.glossaryTermKeys` 同步改。

## 守卫变异检验（新增守卫的必做项）

`REQ-ux-friction-remediation` 的复审曾用变异检验查出 4 条**空转守卫**（改坏产品代码仍不失败）。新守卫不得重蹈，故对 C1b 正则维做同样检验：

| 变异 | 注入 | 期望 | **实测** |
|---|---|---|---|
| 1 | zh `"查看全部 %d 个清理项"` → `"查看全部 %d 项发现"` | C1 变红 | **`FAIL:1`，退出码 1** ✅ |
| 2 | en `"Installed App Storage"` → `"Installed App Storages"` | C1 变红 | **`FAIL:1`，退出码 1** ✅ |
| 3 | 恢复原文 | 回绿 | **`PASS`，退出码 0** ✅ |

**结论**：C1b 正则维**不是空转的** —— 它会因真实变异而变红，且恢复后回绿。

## 终审（2026-09-15）—— 四路对抗审查推翻 9 条收口声明

收口后做了一轮对抗式终审（四路独立审查员，任务是**证伪**）。**门禁全绿、测试全绿、文档齐全的情况下，仍推翻 9 条声明**，逐条回源后全部修复：

| 声明 | 事实 |
|---|---|
| 「`№` 已退役」 | **5 处 Swift 渲染点仍硬编码** —— 门禁只扫 `.strings`，看不见 Swift 字面量 |
| 「门禁能防退化」 | 六维都会变红（无空转），但**覆盖残缺**：en 无 `finding(s)` 且大小写敏感、zh「审计」只匹配固定搭配、C2/C3 只覆盖 18/50 键、en 无宽度约束、`LINE_RE` 静默丢行 |
| 「测试覆盖了导出路径」 | `testExportBuilderRendersFooterAndEntries` **断言自己的输入**（自证守卫，同 `I-8` 型） |
| 「1166 键」 | 6 份文档一致写成 1168 |
| 「CI 已覆盖」 | 对，但设计规格同时保留「已知缺口」旧文本，两份文档冲突 |
| `trace.md` 完整 | 「补充波次」整段被粘两遍，截断 `## Docs Sync` 表（我自己的编辑事故） |
| 步骤编号 | `full-acceptance.sh` 前 3 步仍是 `/11` |
| 文案名实相符 | 导出面板说「可见」而代码传**全量**；「归档 N 个残留项目」而该步**不移动文件** |
| 「白话化完成」 | 仍有未退役内部词：工作区 / 应用包 / **辅助工具（与「辅助功能」权限撞名）** / 在这个构建中 / 前序阶段 / 审计 |

**处置**：门禁从 6 个阻断维**扩到 8 个**（新增 C9 Swift 字面量、C10 解析完整性；C2 扩范围并覆盖 en；C1 大小写不敏感；C1b 补 finding/审计词根）。**7 条新增/变更规则全部做变异检验，全部实测会变红。** 详见 REQ `trace.md` 的「终审」节。

## 真机视觉验收（补做）

用 `./scripts/atlas/export-readme-assets.sh` 渲染全部屏幕并逐张查看。

**布局验证（全部通过，无截断/破版）**：侧栏 `History` · `Plan #42 · #A1F3`（`#` 字形正常）· 阶段条 `Scan / Review / Run / Results` · 风险 chip `Needs Review` · 行动栏 `4 items recoverable · kept 7 days · fully recorded` · `Total App Storage` / `Refresh App Storage` / `Large apps`。

**顺带查出并修复一个既有真缺陷**：UI 语言 English + 系统 zh-CN 时，日期渲染为中文（「4分钟前」「2026年9月15日 17:07」）。根因是 `AtlasFormatters` 绕过 SwiftUI 环境的 locale 读 `Locale.current`。已修 + 补 2 条回归守卫 + **变异检验**（改回即红）。详见 REQ `trace.md`。

## Close Gate

**PASS**（2026-09-15）

| 条件 | 状态 |
|---|---|
| `copy-gate.sh` 退出码 0 | ✅ `ATLAS_COPY_GATE=PASS` |
| `Packages` 零失败 | ✅ `613/0`（基线 612/0，+2 条新守卫 −1 条退役守卫） |
| `Apps` 零失败 | ✅ `72/0` |
| 文档同步 | ✅ 7 项落地 |
| 真机视觉验收 | ✅ 4 屏渲染验证，README 截图重生成 |
| **R-1..R-6 签字** | ✅ **产品负责人逐项签字（2026-09-15）** |

**边界说明**：最后一条由产品负责人裁定完成，不是 agent 自主达成的。本 CHG 不声称 agent 获得了 CONTRACT 授权。
