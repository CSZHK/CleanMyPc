# P3 —— 清理孤儿 + 接线验收链与 CI + 变异自检

- **状态**：完成
- **产出**：`readme-media-gate-selftest.sh` · `full-acceptance.sh` · `atlas-acceptance.yml` · `AGENTS.md`

## 清理

删 12 张 + `.DS_Store`：

| 类别 | 文件 |
|---|---|
| 被 `-en` / `-zh-Hans` 取代 | `atlas-{overview,smart-clean,apps,ledger}.png` |
| 路由改名遗留 | `atlas-history{,-en}.png` |
| README 从不展示 | `atlas-{settings,about,privilege}{,-en}.png` |

**删前改正了一处会删坏东西的判断**：`atlas-overview.png` 被 `Docs/Media/README/cover.html:115` 当作封面内嵌图引用 —— 它不是孤儿，是封面的活依赖。先把 `cover.html` 指向 `atlas-overview-en.png`，它才成为真孤儿。

### 两个刻意保留、且与「清理」前提相矛盾的资产（已报给产品负责人）

`final_with_cover.mp4` 与 `atlas-promo-cover.mp4` 零引用，但：

- `git log -- Docs/Media/README/final_with_cover.mp4` → `2fd28f0 docs(readme): archive cover-frame promo video for reference`

**刻意归档**，不是无人打理的堆积物。把刻意保留的东西当垃圾删掉是错的，故**摘出清理清单**，改在门禁里以 `ARCHIVED_ASSETS` 显式登记（每条附理由与 commit 出处）。

### LandingSite 的引用是独立副本（核过，非推测）

`Apps/LandingSite/src/i18n/{en,zh}.json` 与 `Hero.astro` 引的是 `/images/screenshots/atlas-*.png` —— **LandingSite 自己的 public 目录**，不是 `Docs/Media/README/`。所以删除不会打断落地页构建。

但顺带核出：LandingSite 那四张与重导后的版本**逐字节不同**，时间戳停在 2026-04 ~ 06，即它展示的是过时截图；而 `DESIGN.md` 把同目录的**图标**标注为来自 `Docs/Media/README/`（那几行截图本身没有来源标注 —— 我起初把图标的标注当成了截图的标注，属引用错位）。属同一类缺陷的另一个面，按 `AGENTS.md`（独立工具链）**本轮不扩边界**，记入设计文档「已知仍未闭合」。

## 接线

- `full-acceptance.sh` 插入第 [5/13] 步，并把全部步骤号从 `/12` 重编为 `/13`。
  - 重编号后实测：`[1/13] … [13/13]` 连续无缺 —— 这正是 `REQ-copy-plain-language` 收口时漏改过的那处漂移（`trace.md:55`「前 3 步仍是 `[N/11]`，与 `[4/12]` 混排」）。
- `atlas-acceptance.yml`：`paths:` 增加 `Docs/Media/README/**`、`README.md`、`README.zh-CN.md`。
  - **不加会怎样**：一次「只改了截图 / README 引用」的推送不会触发该 workflow —— 而那正是门禁最该跑的场景。
- **`release.yml`**：`native` job 新增一步 `Verify README media assets are in sync with this release`，位置紧随「Derive native release version」、在昂贵的打包之前。
  - **为什么不只在 acceptance 里拦**：发版是「版本更新」真正落地的那一刻，也正是截图最容易脱节的一刻。发版链此前**完全不碰** README/截图，这是 G1 缺口的正面封堵。
  - 纯 Python + 标准库，不需要 GUI，macos runner 直接跑。
- `AGENTS.md`：新增「README 媒体门禁」段，并把两处旧步骤号（`[4/12]` → `[4/13]`、`[10/12]` → `[11/13]`）改对。
- **历史记录不改**：`CHANGELOG.md`、`changes/CHG-2026-09-copy-plain-language/`、`iterations/REQ-copy-plain-language/` 里的 `[4/12]` 是历史事实，如实保留。若一并「修正」就是伪造历史。

## 变异自检（13 条，逐维验红，在临时副本上做）

`./scripts/atlas/readme-media-gate-selftest.sh` —— 实测结果：

| # | 变异 | 期望维度 | 来源 |
|---|---|---|---|
| 0 | （基线）未改动的副本 | PASS | — |
| 1 | 删除 manifest 列出的资产 | existence | 自设 |
| 2 | 换成 100×100 的图 | dimensions | 自设 |
| 3 | 换成另一张 2880×1800 图（摘要比对） | dimensions | 自设（补 manifest 摘要的死数据） |
| 4 | **共享资产（封面）同尺寸换内容** | dimensions | **对抗审查 #1** |
| 5 | 换成 2880×1800 纯色图 | liveness | 自设 |
| 6 | README 引用不存在的文件 | references | 自设 |
| 7 | 英文 README 引用 zh-Hans 截图 | references | 自设 |
| 8 | **引用全部包进 HTML 注释** | **orphans** | **对抗审查 #3**（首版断言写 references，被自检纠正） |
| 9 | **README 塞入非法 UTF-8 字节** | references | **对抗审查（收尾项）** |
| 10 | 向 en `Localizable.strings` 追加一条 | drift | 自设 |
| 11 | **改导出器的画布尺寸** | drift | **对抗审查 #4** |
| 12 | 塞入无人引用的资产 | orphans | 自设 |
| 13 | README 去掉含两张截图的整行 | orphans | 自设 |
| — | 收尾：真实工作树只读复核 | PASS | — |

断言的是「**变红且红在正确维度**」，不只是「变红」—— 只断言后者的话，一个把尺寸写错、导致所有图都报 existence 的门禁也能骗过自检。

四条标「对抗审查」的变异是**被证伪后补的守卫**，不是预先想到的覆盖率。详见设计文档 §对抗审查。

## 自检自身的一处设计缺陷（实测撞出来的）

第一版自检是「备份 → 就地变异 → 还原」。**它在实测中真的出事了**，且不是理论风险：

| # | 现象 | 后果 |
|---|---|---|
| 1 | 变异在盘上可见，与并发读互相污染 | 我与对抗审查子代理并发跑，双方都读到对方注入的中间态；我据此**一度误判还原逻辑是坏的**（实际不是） |
| 2 | 还原用的是**启动时的备份** | 子代理那轮的备份早于我编辑 README，其还原把 `README.md:117` 的改动**静默回滚**，无任何报错 |
| 3 | 中途被杀留脏树 | `pkill` 后 `atlas-apps-en.png` 停在 100×100 变异态，伪装成「资产真的坏了」 |

处置：改为把门禁要读的那部分复制到**临时根**，用 `--root` 指过去做变异。真实树一次都不碰。

**这条同时验证了「基线必须绿」那一步的价值** —— 隔离版首次运行时，「[0/13] 基线」当场抓出工作树里那条 100×100 的残骸。

## 自检抓到我自己的断言错误（第三次收益）

[8/13]「引用全部包进 HTML 注释」首版断言的是 `references` 维度，实测**变红了但红在 `orphans`**。
查明：剥离注释后 dim 4 已无引用可查，真正报出来的是 dim 6 的「产出但未展示」。

**断言维度写错**与**守卫漏检**是两件事 —— 前者会让自检误报，后者才是真漏洞。
自检的「红在对的维度」这条断言把它区分开了，改对维度即可。

**顺带查出一个真缺口**：共享资产（封面、预警图）只要在 manifest 里就算「已引用」，
所以被注释掉时 **(a) 扫描永远抓不到**。实测把所有图片引用包进注释后，(a) 全过、
只有新增的 (b) 共享资产检查能报出来。已补，并实测「只注释掉封面引用」也会红。

## 门禁卫生实测

| 场景 | 哨兵 | 退出码 |
|---|---|---|
| 干净仓库 | `ATLAS_README_MEDIA_GATE=PASS` | 0 |
| 清单缺失 | `ATLAS_README_MEDIA_GATE=NOT_RUN` | **2（不是 0）** |
| 指纹范围文件缺失 | `ATLAS_README_MEDIA_FINGERPRINT=NOT_RUN` | **2（不是 0）** |
