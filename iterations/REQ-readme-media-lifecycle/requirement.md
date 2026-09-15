# REQ-readme-media-lifecycle

## Title

README 产品截图与更新机制 —— 版本更新后截图不再脱节，且画质有守卫

## Change Class

**CAP** —— 新增能力（媒体资产生命周期 + 六维机检），不改变既有产品契约的语义。

## Status

`COMPLETE`（2026-09-15 首轮即唯一一轮执行）

## Priority

P1 —— 用户可见物料直连产品第一印象；且历史上已经出过一次「98.5% 纯色封面挂在 README 顶部无人发现」的事故。

## Truth Sources

| 来源 | 用途 |
|---|---|
| `Docs/design/2026-09-15-readme-media-lifecycle.md` | **canonical** —— 设计决断、六维定义、指纹范围、已知缺口 |
| `changes/CHG-2026-09-readme-media-lifecycle/verify.md` | 本次执行的验收协议 |
| `Docs/COPY_GUIDELINES.md` | 文案判据（与本 REQ 相邻但不同维度） |
| `iterations/REQ-copy-plain-language/trace.md:219` | 孤儿截图的既有记录（本 REQ 处置它） |

## Description

两份 README 的产品截图此前既**没有更新机制**（发版链完全不碰它们），也**没有画质守卫**（全仓零个像素检查脚本），还**语言错配**（中文 README 展示英文界面截图）。

本 REQ 建立：

1. **一条命令重导** —— `export-readme-assets.sh` 同时产出 8 张双语截图、图标与封面，并重建 `manifest.json`。
2. **六维机检** —— `readme-media-gate.sh`：存在性 / 尺寸 / 像素健康 / 引用完整性 / 漂移指纹 / 零孤儿。
3. **漂移检出** —— 渲染输入指纹覆盖 feature view 源 + shell 源 + 设计系统 + **两份 `Localizable.strings`**，因此「改了文案没重导截图」会被强制暴露。
4. **双语资产** —— 修掉中文 README 展示英文界面的既有缺陷。

## Acceptance

| # | 判据 | 验证方式 |
|---|---|---|
| A1 | 两份 README 引用的每张图语言与自身一致 | 门禁第 4 维（实测变红记录见 `verify.md`） |
| A2 | 八张双语截图确实渲染出对应语言 | **人工抽样**（像素统计判不了语言，见 `trace.md`） |
| A3 | 六维各自「改坏即红」 | `readme-media-gate-selftest.sh` 15 条变异 |
| A4 | 门禁接入验收链且能区分「跳过」与「通过」 | `full-acceptance.sh` 第 [5/13] 步 + NOT_RUN 实测 |
| A5 | 无孤儿资产残留 | 门禁第 6 维 + 目录实测清点 |
| A6 | **发版**时截图脱节可被检出 | 第 5 维指纹，接在 `release.yml` 的 `native` job（紧随版本号推导、打包之前 fail fast）。**注意**：本 REQ 只做「检出」，不做「自动重导」（决断 D1） |

## 契约解冻记录

**无** —— 本 REQ 不触碰 `UC / INV / CONTRACT`，也不改 `infra`。媒体资产是展示层物料，不参与产品语义。

（对照：`REQ-copy-plain-language` 需要二次解冻契约四，因为术语是产品语义。本 REQ 不是。）

## Blast Radius

| 面 | 影响 |
|---|---|
| Swift | `ReadmeAssetExporter.swift` 一个文件（语言循环 + 编目断言） |
| 脚本 | 新增 5 个；改 `export-readme-assets.sh`、`full-acceptance.sh` |
| CI | `atlas-acceptance.yml` 的 `paths:` 与步骤号注释；`release.yml` 的 `native` job 新增一步 |
| 文档 | `AGENTS.md`；新增设计文档 |
| 资产 | `Docs/Media/README/` 重组：删 12 张 + 增 9 张 |
| **不受影响** | 产品运行时代码、`Localizable.strings` 的值、LandingSite（独立工具链，见「不做项」） |

## 不做项（显式列出，防止被当作遗漏）

1. **CI 自动重导并提交** —— 决断 D1 明确否掉。CI runner 跑不了 GUI 渲染，且二进制资产自动入库不可回看 diff。
2. **重构导出器复用真实 `AppShellView`** —— 决断 D3 选了「指纹覆盖 shell 源」而非重构。重构要造 `AtlasAppModel` 桩，风险与工作量显著更高。
3. **LandingSite 截图同步** —— 它是独立 Astro 站点（`AGENTS.md`）。其四张截图与重导后的 `Docs/Media/README/` **逐字节不同且已过时**，已记入设计文档「已知仍未闭合」，**需单独处置**。
4. **封面美术的术语改写** —— `cover.html` 里 `Ledger` / `Ledger №` 与已签字的术语基线冲突，但属营销美术的内容决策，且 app 侧 `№` 仍在 5 处 Swift 渲染点存活。单改封面会造出新不一致。**升级给人。**
5. **`fig01-cover.png` 的内容正确性机检** —— 机器只能判尺寸与像素健康，判不了封面画得对不对。
