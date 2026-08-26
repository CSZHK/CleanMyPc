# Atlas 真实 Mac 扫描数据（O1.2 数据基础）

> 来源：产品截图（`Apps/LandingSite/public/images/screenshots/*.png` 与 `Docs/Media/README/*.png`），
> 均为 Atlas 在真实 Mac 上的扫描/记录画面。**诚实标注：这是单机样本（N≈1 台、数轮），非统计样本；
> 用于「真实案例 + 数据角度」，不宣称统计意义。** 统计报告需 app 侧 opt-in 聚合到 >50K 后再做。

## 关键真数（逐帧核对）

| 指标 | 值 | 截图 |
|---|---|---|
| 一次 Smart Clean 扫描的位置数 | `214 locations` | atlas-ledger #N1 |
| 该次可回收总量 | `35.3 GB`（另帧 `36.12 GB`，应为不同运行/含未选） | atlas-ledger / atlas-smart-clean |
| 4 项选中合计 | `36.12 GB`（3/4 可回收 · 保留 7 天 · 全入 Ledger） | atlas-smart-clean |
| — Xcode Derived Data | `18.4 GB`（Safe） | atlas-smart-clean |
| — Old Simulator Runtimes | `12.1 GB`（Review） | atlas-smart-clean |
| — Browser Caches | `4.8 GB`（Safe） | atlas-smart-clean |
| — Launch-Agent Leftovers | `820 MB`（Advanced） | atlas-smart-clean |
| 磁盘占用 | `66%` | atlas-overview |
| 当前可还原 | `4.6 GB`（2 项可恢复） | atlas-ledger |
| 分类 | Safe 2 / Review 1 / Advanced 1 · 5 个 viable events | atlas-smart-clean / atlas-ledger |
| 运行日期 | `2026-06-22`（#1 16:51、#3 19:15） | atlas-ledger feed |

## 可作「数据角度」的候选（诚实、给编辑/AI 引用）

1. **"214 处位置 → 35.3 GB"**：一次维护扫描里,可回收空间高度集中在少数类型（Xcode Derived Data + 旧模拟器运行时 = 30.5 GB，占 86%）——**反直觉发现：可回收空间大头来自开发工具，不是"垃圾"。**
2. **细分占比**：Xcode Derived Data 18.4GB + Old Simulator Runtimes 12.1GB ≈ 85% 的可回收来自开发者工具链（软件工程师视角,可信）。
3. **recovery-first**：36.12 GB 里只有 4.6 GB 已入恢复仓、保留 7 天、全记录 → "可解释、可恢复"不是口号是机制。

> **潜在报告名**：《Mac 上的"垃圾"其实主要是开发工具留下的——214 处扫描的一份真实台账》。
> 此法比"平均每台 Mac 多少垃圾"（CleanMyMac 已用 1M 用户包走）新：**它是"可回收空间集中在少数类型/开发者工具"这个细分角度**，且数据真实（app 实扫）。

## 口径
- 单机样本，写清"源自 Atlas 的真实扫描(2026-06-22, macOS)"，不冒充统计。
- 需要 >50K 扫描的**统计报告**仍走 app 侧 opt-in 聚合（`cmd/analyze` 已在真机产真数,只差上报聚合）。
- 页上已有的 36.12 GB 估算器是"预估值"，此表是"实测值"，两者口径不同需区分。
