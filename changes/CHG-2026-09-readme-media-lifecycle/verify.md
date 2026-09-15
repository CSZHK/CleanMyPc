# CHG-2026-09-readme-media-lifecycle —— 验收协议源

canonical change root：`brief.md`。本文件是本 change 的**验收协议源**。

## 命令矩阵

| # | 命令 | 期望 | 实测 | 判定 |
|---|---|---|---|---|
| 1 | `bash -n scripts/atlas/{full-acceptance,export-readme-assets,readme-media-gate,readme-media-gate-selftest}.sh` | 全 ok | 全 ok | **PASS** |
| 2 | `swift build --package-path Apps` | 编译通过 | Build complete | **PASS** |
| 3 | `swift test --package-path Packages` | 全绿 | Executed **613 tests, 0 failures** | **PASS** |
| 4 | `swift test --package-path Apps` | 全绿 | Executed **72 tests, 0 failures** | **PASS** |
| 5 | `./scripts/atlas/copy-gate.sh` | 阻断维全零 | `ATLAS_COPY_GATE=PASS`；报告维 316 条（不参与判定） | **PASS** |
| 6 | `./scripts/atlas/export-readme-assets.sh` | 9 导出资产 + 封面 + 门禁 PASS | 9 张 + 封面 1,293,521 B；清单 11 条（9 导出 + 2 共享）；`ATLAS_README_MEDIA_GATE=PASS` | **PASS** |
| 7 | `./scripts/atlas/readme-media-gate.sh` | `PASS`，exit 0 | `ATLAS_README_MEDIA_GATE=PASS`，exit 0 | **PASS** |
| 8 | `./scripts/atlas/readme-media-gate-selftest.sh` | `PASS`，15/15 | `ATLAS_README_MEDIA_GATE_SELFTEST=PASS`，**15/15**，exit 0；真实树只读复核 PASS | **PASS** |
| 9 | 移走 `manifest.json` → 跑门禁 | `NOT_RUN`，**exit 2** | `ATLAS_README_MEDIA_GATE=NOT_RUN`，exit 2 | **PASS** |
| 10 | 移走指纹范围文件 → 跑指纹 | `NOT_RUN`，**exit 2** | `ATLAS_README_MEDIA_FINGERPRINT=NOT_RUN`，exit 2 | **PASS** |
| 11 | 人工抽样 `atlas-ledger-{en,zh-Hans}.png` | 各自渲染对应语言 | en=英文界面 / zh=中文界面 | **PASS** |
| 12 | PNG 解码器 vs Pillow 交叉验证（7 张图） | 统计量一致 | unique / dominant **逐位一致** | **PASS** |
| 13 | 验收链步骤号连续性 | `[1/13]…[13/13]` | 连续无缺 | **PASS** |
| 14 | 两个 workflow 的 YAML 可解析 | 能 load | `ruby -ryaml` 两个均 ok | **PASS** |
| 15 | **门禁 exit 2 时验收链是否 fail-fast**（沙箱模拟 + `set -euo pipefail`） | 中止且非零退出 | 退出码 2，`[6/13]` **未执行** | **PASS** |
| 16 | **`ATLAS_ALLOW_UI_SKIP` 能否豁免媒体门禁** | 不能 | 三个源文件里**零引用** | **PASS** |
| 17 | `git status` 清点 | 无残留临时文件 | 见「工作树清点」 | — |

第 15/16 条原先只有对抗审查员测过 —— **我自己在 `/tmp` 沙箱里独立复跑了一遍**（不采信单方陈述）。

## 六维变异矩阵（判据来源：`readme-media-gate-selftest.sh` 实测输出）

| 维度 | 变异 | 期望红 | 实测 |
|---|---|---|---|
| （基线） | — | 绿 | ✓ PASS |
| `existence` | 删除 `atlas-apps-en.png` | ✓ | ✓ 红在 `[existence]` |
| `dimensions` | 换成 100×100 | ✓ | ✓ 红在 `[dimensions]` |
| `dimensions` | 换成另一张 2880×1800（摘要比对） | ✓ | ✓ 红在 `[dimensions]` |
| `dimensions` | **共享资产封面同尺寸换内容** | ✓ | ✓ 红在 `[dimensions]` |
| `liveness` | 换成 2880×1800 纯色 | ✓ | ✓ 红在 `[liveness]` |
| `references` | 引用不存在的文件 | ✓ | ✓ 红在 `[references]` |
| `references` | 英文 README 引 zh-Hans 图 | ✓ | ✓ 红在 `[references]` |
| `orphans` | **全部引用包进 HTML 注释** | ✓ | ✓ 红在 `[orphans]`（见下「断言维度修正」） |
| `references` | **README 塞入非法 UTF-8** | ✓ | ✓ 红在 `[references]`（整段输出 162 字节 / 报错行 69 字符，不刷屏） |
| `drift` | 追加一条 en 文案 | ✓ | ✓ 红在 `[drift]` |
| `drift` | **改导出器画布尺寸** | ✓ | ✓ 红在 `[drift]` |
| `orphans` | 塞入无人引用的资产 | ✓ | ✓ 红在 `[orphans]` |
| `orphans` | **只注释掉封面引用**（新闭合的缺口） | ✓ | ✓ 红在 `[orphans]`：`fig01-cover.png … README.md 没有展示它` |
| `orphans` | README 去掉含两张截图的整行 | ✓ | ✓ 红在 `[orphans]` |
| （收尾） | 真实工作树只读复核 | 绿 | ✓ PASS |

后四条标粗的是**被对抗审查证伪后补的守卫** —— 预先是漏的。详见下节与设计文档 §对抗审查。

**断言的是「变红且红在正确维度」**，不只是「变红」：只断言后者的话，一个把尺寸写错、导致所有图都报 `existence` 的门禁也能骗过自检。

> **自检在临时副本上做**（`--root` 指向隔离副本），真实工作树一次都不碰。第一版是就地改工作树，实测撞出三类真缺陷（并发污染、用陈旧备份静默回滚无关编辑、被杀留脏树），详见 `Docs/design/2026-09-15-readme-media-lifecycle.md` §变异自检。**这同时也是「第 0 步基线必须绿」的价值证明**：隔离版首跑就在基线处抓出了工作树里一条 100×100 的残留。

## 对抗审查（证伪）—— 推翻 4 条覆盖声明，全部已修

派独立审查员去**证伪**（任务是推翻，不是复核）。它推翻了 4 条，**我逐条独立复现确认全部成立**（未采信其单方陈述），然后逐条修：

| # | 原声明 | 证伪方式 | 复现实测 | 修复 |
|---|---|---|---|---|
| 1 | 尺寸维覆盖全部资产 | 封面同尺寸换图 | **PASS**（漏检） | 共享资产进 manifest 带 `sha256` |
| 2 | 像素健康维防空白/纯色 | 纯白 + 仅在采样格点放噪声 | **PASS**（漏检，需清单同步） | 采样逐行错开相位 |
| 3 | 引用维看的是真实展示 | 全部引用包进 `<!-- -->` | **PASS**（漏检） | 剥离注释与代码块后再扫 |
| 4 | 漂移指纹覆盖 shell 副本 | 改导出器画布尺寸 | **PASS**（漏检） | 范围改为 `Apps/AtlasApp/Sources/AtlasApp/**/*.swift` |

第 4 条最严重：范围注释自称在防「手抄副本漂移」，却把**承载副本的那个文件**排除在外 —— 注释说的与范围做的正好错开。

**与我自己的复现的分歧（如实记录）**：审查员报 #2、#3 为 PASS，我第一次复现却得到 FAIL:1。查明是**我自己的实验设计错误** —— 把多项变异累积在同一个沙箱，结果被前一项的遗留污染。改为每项独立沙箱后与审查员一致。**同一个错误我在本次任务里犯了两次**（第二次是在做「指纹边界」测试时），已写进设计文档。

### 四条修复的**独立**复验（不采信子代理单方陈述）

| # | 修复 | 复验方式 | 实测 |
|---|---|---|---|
| 1 | 共享资产进 manifest 带摘要 | 自检变异 [4/13] | ✓ 红在 `[dimensions]` |
| 2 | 采样逐行错开相位 | **重建清单消掉摘要红后**，只放旧格点 `(x%14, y%9)` 的噪声 | ✓ 红在 `[liveness]`（主色 92.5%）；对照诚实纯白图亦红 |
| 3 | 剥离注释与代码块 | 自检变异 [8/13] | ✓ 红在 `[references]` |
| 4 | 范围改为整个 App 源目录 | 自检变异 [11/13] + 载体清单 | ✓ 红在 `[drift]`；`Apps/` 下由 1 个文件增至 8 个 |

第 2 条的复验方式值得记：**先重建清单**把「摘要不符」那条红消掉，才隔离出像素健康单独一维 —— 否则任一张被改过的图都会因摘要而红，liveness 到底有没有生效根本看不出来。

## 质量审查（三路独立，找真缺陷）—— 报 9 条，7 条属实已修

收口前另派三路审查（Python 门禁 / Shell 与 CI 接线 / Swift 与文档）。**逐条复现定基线后**入账：

| 路 | 严重度 | 缺陷 | 处置 |
|---|---|---|---|
| Python | **P0** | `~~~` 围栏不剥离（只认 ```` ``` ````，而 GitHub 上两者等价）→ 全部引用藏进去则**六维全绿** | 已修；正则加反向引用，顺带修 4 反引号嵌套 |
| Python | P1 | 截断 IHDR 抛裸 `struct.error`，各维度只捕 `PngError` → 报错丢文件上下文 | 已修：长度先判 + `PNG_ERRORS` 统一捕获 |
| Python | P1 | `os.path.isfile` 大小写不敏感 → 错大小写的引用被判存在且**跳过语言检查** | 已修：目录清单精确名比对 + 单列一条红 |
| Python | P2 | 畸形头声明 2³¹−1 宽可进内存分配路径 | 已修：IHDR 尺寸 sanity 上界 |
| Shell/CI | P1 | Chrome 封面**假成功**（内嵌图 404 仍 exit 0，写出尺寸正确、像素健康的退化封面，随后被写进 manifest ⇒ 六维全绿） | 已修：渲染前断言三个输入齐备 |
| Shell/CI | P1 | 自检隔离副本泄漏时 `expect_red` 打印「期望 exit=1，实际 exit=2」，**指错方向** | 已修：exit=2 单列成「搭台问题」 |
| Shell/CI | P2 | liveness 对共享资产重复检查，`FAIL:N` 计数虚高 | 已修：去重（`FAIL:3`→`FAIL:2`） |
| Shell/CI | P2 | 自检注释称「可任意并发」，但自检 × 导出并发不成立 | 已修：写明确切范围 |
| Shell/CI | ~~P0~~ | 「14 个新文件未纳入版本控制 ⇒ CI 红」 | **定性被纠正**：那是未提交的中间态，非设计缺陷。留档为其背后的**交付前提**（清单与脚本须同批提交） |

**我自己在复现 P0 时踩的坑**：第一版测试构造把 `~~~` 塞进表格单元格中间（不在行首，不成其为围栏），门禁返回 PASS，我一度判定「本来就没问题」；改用行首的合法围栏才复现。**测试构造的合法性，与判据本身一样需要被怀疑。**

## 第 5 维指纹的**载体覆盖与边界**独立实测

不只验「坏一处会红」，还验「范围**确有边界**」—— 否则一个「什么改动都报红」的指纹会逼人无脑重导，等于没有守卫。每项用独立沙箱（避免累积污染）：

| 载体 | 归属 | 基线 | 改动后 | 判定 |
|---|---|---|---|---|
| `AppsFeatureView.swift` | 范围**内** | PASS | **FAIL:1** | ✓ 覆盖 |
| `AppShellView.swift` | 范围**内**（shell 手抄来源，决断 D3 的关键） | PASS | **FAIL:1** | ✓ 覆盖 |
| `AtlasBrand.swift`（设计系统） | 范围**内** | PASS | **FAIL:1** | ✓ 覆盖 |
| `AtlasDomain.swift`（路由 + fixture） | 范围**内** | PASS | **FAIL:1** | ✓ 覆盖 |
| `cover.html`（封面源） | 范围**内** | PASS | **FAIL:1** | ✓ 覆盖 |
| `AtlasActionOutcome.swift` | 范围**外** | PASS | **PASS** | ✓ 边界成立 |
| `AtlasAppModel.swift` | 范围**外** | PASS | **PASS** | ✓ 边界成立 |

**过程失误自陈**：第一版这项测试把多个载体**累积**改在同一个沙箱里，于是「范围外」那一项拿到的是前几项遗留的红，结论无效。重做为「每项独立沙箱」才得到上表。单次实验设计错了，就会产出看似合理实则无意义的证据。

## 实测耗时（CI 成本）

| 命令 | 耗时 |
|---|---|
| `readme-media-gate.sh` | **~36 s** |
| `readme-media-gate-selftest.sh` | **~10 min**（跑 17 遍门禁） |

未优化的理由与将来若要优化的取舍见设计文档 §实测代价。

## 人工抽样证据（机器判不了的部分）

像素统计能判「非空白」，**判不了「是中文」**。故抽样人眼确认：

| 文件 | 实测渲染内容 |
|---|---|
| `atlas-ledger-en.png` | History · Overview · Smart Clean · File Organizer · Apps · Permissions · Visible events · Latest update 4 minutes ago |
| `atlas-ledger-zh-Hans.png` | 历史记录 · 概览 · 智能清理 · 文件整理 · 应用 · 权限 · 当前记录 · 最近更新 4 分钟前 |

## 维度闭合复算（脚本计数，非目测）

| 维度 | 复算 | 结果 |
|---|---|---|
| 门禁维度 → 变异覆盖 | 6 维：existence 1 / dimensions 3 / liveness 1 / references 4 / drift 2 / orphans 2 | **15 条变异，零遗漏** |
| manifest 资产 → 盘上文件 | 11（9 导出 + 2 共享） | 11，摘要与尺寸**逐条一致**，零缺 |
| README 引用 → 盘上文件 | 两份各 **6 处图片引用**（4 截图 + 封面 + 预警）+ 1 处目录名（导出命令注释里） | 全部存在；**两份 README 均不引 `atlas-icon.png`**（它服务 LandingSite） |
| 清理清单 → 实际删除 | 12 张 + `.DS_Store` | 12 + 1，**零遗漏** |
| 指纹范围 → 解析文件 | `readme-media-fingerprint-scope.txt` 12 条 glob（含 `Apps/AtlasApp/Sources/AtlasApp/**`） | 72 个文件 |

> **任一维 100% 覆盖不构成其他维也覆盖的证据** —— 上表各维分别复算，不互相代言（`iteration-governance` Validation Gate 第一条）。

## 工作树清点

`git status --short` 实测（脚本计数，非目测）：**修改 13 个 / 删除 12 个 / 新增 14 个**。

- 无临时文件残留：自检的隔离副本由 `trap` 清理，真实工作树自始至终未被自检触碰。
- 变异用的临时 PNG（100×100、纯色、`atlas-zzz-orphan.png`）全部落在隔离副本内，不进工作树。

## 未覆盖项（如实记录，不掩盖）

1. `fig01-cover.png` 的**内容**正确性无机检（只比尺寸、像素健康与内容摘要；摘要抓「被换过」，抓不了「画得对不对」）。
2. **部分渲染**抓不住 —— 只画出侧栏也有一两千种颜色。
3. 指纹范围外的改动看不见。
4. LandingSite 截图未同步（范围外，已升级）。
5. 封面术语未改（范围外，已升级）。
6. 运行时拼接的字符串不在指纹内。
7. 步骤 3/4/5（Swift 测试与文案门禁）的实跑结果见下节。
