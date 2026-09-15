# REQ-readme-media-lifecycle —— Trace

## Validation Protocol

| 层 | 判据 | 怎么验 |
|---|---|---|
| 门禁活性 | 六维各自「改坏即红」 | `readme-media-gate-selftest.sh`（15 条变异） |
| 门禁卫生 | 跳过 ≠ 通过 | 清单缺失 / 范围文件缺失 → 必须 exit 2 |
| 接线 | 验收链真的会跑到它 | `full-acceptance.sh` 步骤号连续 + `paths:` 覆盖媒体目录 |
| 产物 | 双语图真是双语 | **人工抽样**（像素统计判不了语言） |
| 漂移 | 「改文案不重导」能被抓 | 变异 6 实测 |

## Blast Radius

见 `requirement.md` §Blast Radius。要点：**不触碰**产品运行时代码与 `Localizable.strings` 的值；LandingSite 不受影响。

## Required Validation Modules

- `readme-media-gate-selftest.sh`（必跑，改门禁规则后重跑）
- `swift build --package-path Apps`
- `full-acceptance.sh` 第 [5/13] 步
- 人工抽样：双语截图各看一次

## Docs Sync

| 目标 | 动作 |
|---|---|
| `AGENTS.md` | 新增「README 媒体门禁」段；两处旧步骤号改对 |
| `Docs/design/2026-09-15-readme-media-lifecycle.md` | 新增（canonical） |
| `README.md` / `README.zh-CN.md` | 截图引用改指各自语言 |
| `Docs/Media/README/cover.html` | 内嵌图指向 `atlas-overview-en.png` |
| `.github/workflows/atlas-acceptance.yml` | `paths:` + 步骤号注释 |
| **不改** | `CHANGELOG.md`、历史 CHG/REQ 里的 `[4/12]` —— 历史事实，改它即伪造 |

## Planned Verification

1. `bash -n` 四个脚本
2. `swift build --package-path Apps`
3. `./scripts/atlas/export-readme-assets.sh` 全链路重导
4. `python3 scripts/atlas/readme_media_gate.py` → PASS
5. `./scripts/atlas/readme-media-gate-selftest.sh` → PASS
6. 清单缺失 → exit 2
7. 范围文件缺失 → exit 2
8. 人工抽样双语截图
9. 对抗审查（证伪，非复核）

## Actual Verification

| # | 命令 | 结果 |
|---|---|---|
| 1 | `bash -n` × 4 脚本 | 全 ok |
| 2 | `swift build --package-path Apps` | Build complete |
| 3 | `./scripts/atlas/export-readme-assets.sh` | 9 条资产 + 封面 1,293,521 字节；门禁 PASS |
| 4 | `./scripts/atlas/readme-media-gate.sh` | `ATLAS_README_MEDIA_GATE=PASS`，exit 0 |
| 5 | `./scripts/atlas/readme-media-gate-selftest.sh` | `ATLAS_README_MEDIA_GATE_SELFTEST=PASS`，13/13 |
| 6 | 移走 `manifest.json` 后跑门禁 | `NOT_RUN`，**exit 2** |
| 7 | 移走指纹范围文件后跑指纹 | `NOT_RUN`，**exit 2** |
| 8 | 人工抽样 `atlas-ledger-{en,zh-Hans}.png` | en=英文界面 / zh=中文界面，**确认** |
| 9 | PNG 解码器 vs Pillow 交叉验证 | 7 张图 unique/dominant **逐位一致** |
| 10 | 验收链步骤号 | `[1/13] … [13/13]` 连续无缺 |
| 11 | `readme-media-gate-selftest.sh`（隔离版，13 条） | `PASS`，基线绿，收尾复核真实树 PASS |

## 关键发现（含与初始前提相矛盾的）

### F1 —— `atlas-overview.png` 不是孤儿，是封面的活依赖

`Docs/Media/README/cover.html:115` 把它作为封面内嵌图引用。若照初始清理清单直接删，会打断封面源。处置：先把 `cover.html` 指向 `atlas-overview-en.png`。

### F2 —— 两个 mp4 是**刻意归档**，与「清理孤儿」的前提相矛盾

`git log -- Docs/Media/README/final_with_cover.mp4` → `2fd28f0 docs(readme): archive cover-frame promo video for reference`。把刻意保留的东西当垃圾删掉是错的。处置：**摘出清理清单**，改在门禁里以 `ARCHIVED_ASSETS` 显式登记（附理由与 commit 出处）。

### F3 —— LandingSite 展示的是过时截图（范围外，已记录）

`Apps/LandingSite/public/images/screenshots/` 的四张与重导后的 `Docs/Media/README/` 版本**逐字节不同**（时间戳 2026-04 ~ 06），而 `DESIGN.md` 把同目录的**图标**标注为来自 `Docs/Media/README/`（截图本身无来源标注）。按 `AGENTS.md`（独立工具链）本轮不扩边界。**需单独处置。**

### F4 —— 封面的术语与已签字基线冲突（升级给人）

`cover.html` 的 pills 写 `Ledger`、`ledger-strip` 显示 `Ledger №`。术语基线（`REQ-copy-plain-language/terminology-baseline.md` P-1 / R-1，**已签字**）裁定 `Ledger` → `History`、`№` 退役。**未擅自改**：这是营销美术的内容决策，且 app 侧 `№` 仍在 5 处 Swift 渲染点存活（该 REQ 终审 #1），单改封面会造出新的不一致。

### F5 —— 门禁自己抓到自己的两个缺陷

第一次真跑红 19 条，其中两条是门禁自身的 bug（尺寸期望对图标用了截图的规格；第 6 维 docstring 声称「manifest 覆盖即算引用」但实现里没写）。第二个是**注释写了、代码没做**，靠真跑暴露，读代码发现不了。

### F6 —— 变异自检的第一版有设计缺陷（实测撞出，非理论推演）

第一版自检「备份 → 就地变异 → 还原」在真实并发下出了三类事故：

| # | 现象 | 后果 |
|---|---|---|
| 1 | 变异在盘上可见，与并发读互相污染 | 与对抗审查子代理并发时双方读到对方中间态；我据此**一度误判还原逻辑坏了**（实际没坏） |
| 2 | 还原用启动时的备份 | 子代理那轮把 `README.md:117` 的改动**静默回滚**，无报错 |
| 3 | 中途被杀留脏树 | `pkill` 后 `atlas-apps-en.png` 停在 100×100，伪装成真资产损坏 |

**这里我犯了一次「核了现象没核义务」的反向错误**：看到 README 里出现变异残留，就断定还原逻辑失效；实际是并发窗口。正确的下一步是**先查有没有并发进程**（`ps`），我跳过了这一步，直接下了结论。

处置：改为在临时副本上变异（`--root`）。**教训的普适形态**：守卫自检不该在受检对象的真实副本上做破坏性操作 ——「用完还原」在单线程世界等价，在真实世界不等价。

### F7 —— 对抗审查推翻了我 4 条覆盖声明（T3 的第二次同型复发）

收口前派独立审查员去**证伪**。它推翻了 4 条，我逐条独立复现确认成立：

| # | 被推翻的声明 | 根因 | 与既有教训的关系 |
|---|---|---|---|
| 1 | 尺寸维覆盖全部资产 | 共享资产不在 manifest 里，只比尺寸无摘要 | 覆盖缺口 |
| 2 | 像素健康维防空白/纯色 | 采样是固定格点，可被对齐的假纹理骗过 | 覆盖缺口 |
| 3 | 引用维看真实展示 | 正则不懂 HTML 语义，注释掉的引用仍算展示 | 覆盖缺口 |
| 4 | **漂移指纹覆盖 shell 手抄副本** | **真正被渲染的那份副本所在的文件不在范围内** | **与 `№` 同型：守卫的输入面没覆盖被检事实的全部载体** |

第 4 条是本轮最严重的一条：范围的注释自称「`AtlasScreenshotShell` 是 `AppShellView` 的手抄副本，会静默漂移」，却把承载副本的 `ReadmeAssetExporter.swift` **排除在范围外**。注释说的事与范围做的事正好错开 —— **改画布尺寸，截图会变、门禁全绿**。

这印证了 `iteration-governance` 台账里那条 T3：**同类失败第二次出现，说明单条补丁治不了，得改问法**。`№` 那次问的是「数据载体有哪些」，这次答案是「**代码本身**也是载体」。已把问法写进 [[new-guards-need-mutation-test]]。

四条修复各自的变异已补进自检，加上收尾的编码检查，自检从 9 条增至 **13 条**。

**我自己的复现失误（同一错误犯了两次）**：审查员报 #2/#3 漏检，我第一次复现却得到 FAIL —— 因为我**把多项变异累积在同一个沙箱**，被前一项的遗留污染。这个错误在做「指纹边界」测试时已经犯过一次并写进 `verify.md`，随后立刻又犯。**实验设计错误会产出看似合理实则无意义的证据**，已作为独立条目记入设计文档。

### F8 —— 导出器曾不可复现（质量审查发现，已修）

重导两次 9 张里 4 张会变，差异是截图里烘焙的**绝对墙钟时间**。既有缺陷（未改 `AtlasDomain.swift`），但漂移守卫把它从偶发变成**每次文案改动都要付**——每次约 4 MB 新 blob。

**根因有两半，我最初只看到一半**：① fixture 的 `now = Date()`；② `AtlasFormatters.relativeDate` 的参考点写死 `Date()`。只钉 ① 的话，日期固定了、看起来可复现，但相对时间（截图上最显眼的那条）仍在漂。

修法：新增 `AtlasRenderClock` 作单一注入点，两处都走它；导出器钉死 + `defer` 还原。**不动 fixture 本身**——它被 `AtlasScaffoldWorkerService` 与 `AtlasWorkspaceRepository` 共用，全局改会变更 app 行为。

验证：连渲两次 **9/9 逐字节一致**；再跑一次导出脚本 **12 张 PNG 全不变**（幂等）；新增 6 条守卫测试，并把 fixture 改回 `Date()` 做**变异检验**——2 条变红。

**附带教训（同一次改动内重犯）**：新文件 `AtlasRenderClock.swift` 影响渲染，而指纹范围里 `AtlasDomain` 仍是**逐文件点名**的，**立刻漏了它**。「逐项点名 = 黑名单穷举」这个错，我在同一次改动里犯了第二遍。已改为整目录，范围 67 → 72 文件，并补变异 [13/15] 守这个决定。

## 与既有 REQ 的关系

| 对象 | 关系 |
|---|---|
| `REQ-copy-plain-language` | **承接其未处置项** —— 该 REQ `trace.md:219` 记录了孤儿截图与「中文 README 展示英文截图」，明确「本次不修，仅报告」。本 REQ 处置这两条 |
| 同上（副作用） | 第 5 维指纹把**两份 `Localizable.strings` 全量**纳入范围，因此该 REQ 的后续文案改动会被强制要求重导截图 —— 把当时手工补做的动作变成机制 |
| `REQ-ux-friction-remediation` | 无交集 |

## 未覆盖项（如实记录，不掩盖）

0. **手抄副本与真实 shell 的一致性**（本轮唯一新发现的残留局限）。范围扩大后，`AppShellView.swift` 变了会报红；但重导产出的是副本渲染的图，副本没变图就不变 —— 于是「重导一次」就能回绿，而偏差仍在。要根治得让导出器复用真实 shell（决断 D3 否掉了，需造 `AtlasAppModel` 桩）。
1. **`fig01-cover.png` 的内容正确性**无机检 —— 只比尺寸、像素健康与内容摘要。摘要能抓「被换过」，抓不了「画得对不对」。
2. **部分渲染**抓不住 —— 只画出侧栏也有一两千种颜色。
3. **指纹范围外的改动看不见** —— 范围是声明的，不是推导的。
4. **LandingSite 截图未同步**（F3）。
5. **封面术语未改**（F4）。
6. **运行时拼接的字符串**不在指纹内。
