# P2 —— 六维媒体门禁 + 指纹

- **状态**：完成
- **产出**：`readme-media-gate.sh` · `readme_media_gate.py` · `readme_media_fingerprint.py` · `readme-media-fingerprint-scope.txt`

## 做了什么

六维：存在性 / 尺寸 / 像素健康 / 引用完整性 / 漂移指纹 / 零孤儿。

关键决策与踩坑：

1. **PNG 解码自己写**（`_decode_png` 一族，~120 行纯标准库）。不引 Pillow —— GitHub 托管 runner 不保证有它，而一个「没装依赖就跳过」的门禁等于没有门禁。
   - 已与 Pillow **逐位交叉验证**：7 张图 unique colors 与主色占比**完全一致**。
2. **阈值按实测定，不是拍的**。第一版定 `unique ≥ 200`，交叉验证后实测发现合法最低是 `atlas-prerelease-warning.png` 的 283（只有 1.4× 余量），改为 `≥ 64`（4.4× 余量）；主色上限从 0.60 改为 0.75（合法最高 51.6%，已知烂图 98.5%）。完整基线表写在常量注释里。
3. **期望资产表在 Python 里另写一遍**，故意与 Swift 的 `screenshotRoutes` 不同源 —— 同源会让门禁变成自证断言。
4. **第 6 维的引用面只认 README 体系**（manifest ∪ 两份 README ∪ 媒体目录内的源文件）。**故意不认**历史设计文档里的提及 —— `Docs/design/*` 里「`atlas-history.png` → `atlas-ledger.png`」是在叙述一次已发生的改名，不是活的依赖；把它算作「有人引用」会让这个维度永远抓不到真孤儿（本仓此前正是这么躺了 15 个）。
5. **`ARCHIVED_ASSETS` 白名单**，每条必须写明理由与 commit 出处 —— 否则它会变成「什么都能塞」的垃圾桶。
6. **指纹范围解析为空集时抛错**，不返回空列表。空范围会让指纹退化成常量，门禁从此永远通过 —— 那是空转守卫。
7. **指纹留逐文件摘要**（`digests`），不只留聚合值。报错要能指名道姓说「是这两个文件变了」；不可定位的报错等于没有报错。

## 门禁自身被自己抓到的两个缺陷（值得记）

第一版跑起来立刻红 19 条，其中两条是**门禁自己的 bug**：

| 缺陷 | 症状 | 修 |
|---|---|---|
| 尺寸期望对所有 manifest 条目用同一个值 | `atlas-icon.png 尺寸 1024×1024，期望 2880×1800` | 按类别取期望（截图 / 图标 / 共享） |
| 第 6 维声称「被 manifest 覆盖即算引用」但实现里没写 | 9 个刚导出的新资产全被报成孤儿 | 引用面并入 manifest |

第二个是**docstring 与实现不一致** —— 注释写了、代码没做。由第一次真跑暴露，不是靠读代码发现的。

## 实际验证

- `readme-media-gate.sh` 在干净仓库上 `ATLAS_README_MEDIA_GATE=PASS`（exit 0）。
- 清单缺失时 `NOT_RUN`（exit 2，**不是** 0）。
- 指纹范围文件缺失时 `ATLAS_README_MEDIA_FINGERPRINT=NOT_RUN`（exit 2）。
- 变异自检见 `p3-wire.md` 与 `verify.md`。
