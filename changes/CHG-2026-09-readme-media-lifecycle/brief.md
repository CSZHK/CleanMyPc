# CHG-2026-09-readme-media-lifecycle

- **REQ**: `REQ-readme-media-lifecycle`（本 REQ 的首次也是唯一一次执行）
- **Task**: P1–P4（导出器双语化 / 六维门禁+指纹 / 清理+接线+变异自检 / 文档）
- **Scope**: README 媒体资产生命周期 —— 更新机制 + 画质守卫 + 双语资产
- **Canonical Plan**: `Docs/design/2026-09-15-readme-media-lifecycle.md`
- **状态**：**已收口（2026-09-15）**

## 这次改了什么

| 层 | 改动 |
|---|---|
| Swift | `ReadmeAssetExporter.swift`：硬编码语言 → `AtlasLanguage.allCases` 循环；产物命名 `atlas-{stem}-{lang}.png`；落盘非空断言 |
| **可复现性** | 新增 `AtlasRenderClock`（`AtlasDomain`）：一次治两处时间依赖（fixture 的绝对时间 + `relativeDate` 的参考点），导出时钉死。**重导从「4 张必变」变成幂等** |
| 脚本 | 新增 `readme_media_gate.py`（六维 + 纯标准库 PNG 解码）、`readme_media_fingerprint.py`（唯一指纹实现）、`readme-media-gate.sh`、`readme-media-gate-selftest.sh`、`readme-media-fingerprint-scope.txt`；改写 `export-readme-assets.sh` |
| 资产 | `Docs/Media/README/` 重组：删 12 张过时图 + `.DS_Store`；新增 8 张双语截图 + `manifest.json`；封面重渲 |
| README | 两份各引各自语言的截图（修掉「中文 README 展示英文界面」） |
| 验收链 | `full-acceptance.sh` 新增第 [5/13] 步，全部步骤号 `/12` → `/13` |
| CI | `atlas-acceptance.yml` 的 `paths:` 增加媒体目录与两份 README |
| **发版链** | `release.yml` 的 `native` job 新增一步，紧随版本号推导、在打包之前 fail fast |
| 文档 | 新增设计文档；`AGENTS.md` 新增「README 媒体门禁」段 |

## 关键决策

1. **守卫 + 一条命令重导，不做 CI 自动重导**（决断 D1）。CI runner 跑不了 GUI 渲染；二进制资产自动入库不可回看 diff。门禁的职责是**指名要跑哪条命令**，不是替人跑。
2. **指纹取宽，把两份 `Localizable.strings` 全量纳入**。后果：改任何一条文案都报红直到重导。这是**故意的** —— `REQ-copy-plain-language` 收口时正是手工补做了这件事。收窄版属于「黑名单穷举」，正是本仓 T3 教训点名的失效模式。
3. **PNG 解码手写，不引 Pillow**。托管 runner 不保证有它，而「没装依赖就跳过」的门禁等于没有门禁。已与 Pillow 逐位交叉验证。
4. **期望资产表 Swift / Python 各写一份，故意不同源**。同源会让门禁变成自证断言（本仓 `I-8` 同型）。
5. **孤儿判定只认 README 体系的引用面**，不认历史设计文档的叙述性提及。

## 收口前对抗审查：推翻 4 条覆盖声明（全部已修）

按 Validation Gate 第三条派独立审查员**证伪**。它推翻了 4 条，我**逐条独立复现确认成立**后再修：

| # | 被推翻的声明 | 根因 | 修复 |
|---|---|---|---|
| 1 | 尺寸维覆盖全部资产 | 共享资产不在 manifest，只比尺寸无摘要 | 共享资产进 manifest 带 `sha256` |
| 2 | 像素健康维防空白/纯色 | 采样是固定格点，可被对齐的假纹理骗过 | 采样逐行错开相位 |
| 3 | 引用维看真实展示 | 正则不懂 HTML，注释掉的引用仍算展示 | 剥离注释与代码块后再扫 |
| 4 | **漂移指纹覆盖 shell 手抄副本** | **真正被渲染的副本所在文件不在范围内** | 范围改为 `Apps/AtlasApp/Sources/AtlasApp/**/*.swift` |

第 4 条与 `REQ-copy-plain-language` 的 `№` 是**同一根因的第二次出现**（守卫输入面未覆盖全部载体）—— 命中 `iteration-governance` 台账的 T3。区别：这次载体是**代码本身**，不只是数据文件。

**过程自陈**：我复现审查员的 #2/#3 时第一次得到相反结论，原因是**把多项变异累积在同一沙箱**（被前一项遗留污染）。同一错误本次任务犯了两次。已记入 `verify.md` 与设计文档。

四条修复各补一条自检变异，加收尾的编码检查，自检 **14 条**。

## 被推翻的初始前提（3 条）

| # | 初始判断 | 事实 | 处置 |
|---|---|---|---|
| 1 | `atlas-overview.png` 是孤儿 | 是 `cover.html:115` 的封面内嵌图，**活依赖** | 先改封面源指向 `-en`，它才成真孤儿 |
| 2 | 15 个孤儿都该删 | `final_with_cover.mp4` 是 `2fd28f0` **刻意归档**「for reference」 | 摘出清单，改在门禁里 `ARCHIVED_ASSETS` 显式登记 |
| 3 | LandingSite 引用这些文件 | 它引的是**自己 public 目录**的独立副本，删了不影响它 | 删除安全；但另核出它那四张**已过时**（见下） |

## 范围外但必须报的（升级给人）

1. **LandingSite 截图已过时**：`Apps/LandingSite/public/images/screenshots/` 四张与重导后版本逐字节不同，时间戳停在 2026-04 ~ 06，而 `DESIGN.md` 把同目录的图标标注为来自 `Docs/Media/README/`。按 `AGENTS.md`（独立 Astro 站点）未扩边界，**需单独处置**。
2. **封面术语与已签字基线冲突**：`cover.html` 写 `Ledger` / `Ledger №`，而 `terminology-baseline.md` P-1 / R-1（**已签**）裁定 `Ledger` → `History`、`№` 退役。属营销美术的内容决策，且 app 侧 `№` 仍在 5 处 Swift 渲染点存活，**单改封面会造出新不一致** —— 故未擅自动手，升级给人。
