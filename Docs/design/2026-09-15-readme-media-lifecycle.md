# README 媒体资产生命周期

- **日期**：2026-09-15
- **状态**：已落地
- **追溯**：`iterations/REQ-readme-media-lifecycle/` · `changes/CHG-2026-09-readme-media-lifecycle/`
- **相关**：`Docs/design/2026-09-15-copy-plain-language.md`（术语基线，本次的第 5 维守卫会强制它重导截图）

## 问题

README 的产品截图此前**没有任何机制**。事情分三块：

| # | 缺口 | 证据 |
|---|---|---|
| G1 | **版本更新与截图无关** | `grep -i "readme\|screenshot" .github/workflows/release.yml` → 零命中；`prepare-release.sh` 只改 `project.yml` / `AtlasAppModel` / `CHANGELOG`。版本号一涨，截图原地不动，没人会知道 |
| G2 | **无画质门禁** | `grep "unique colors\|dominant\|pixel" scripts/ .github/` → 零命中。画质判据只活在会话记忆与 `cover.html` 的注释里，靠人自觉 |
| G3 | **无「截图 vs 代码」一致性检查** | 无任何脚本 |
| G4 | **无引用完整性检查** | README 图片路径写错、文件被删或改名，只能靠肉眼发现 |
| G5 | **孤儿资产堆积** | 15 个零引用文件（`atlas-*-en.png`、`atlas-history*`、`atlas-settings/about/privilege*`、`.DS_Store` 等），已记录于 `REQ-copy-plain-language/trace.md:219` 但未处置 |
| G6 | **中文 README 展示英文截图** | 导出器硬编码 `screenshotLanguage: AtlasLanguage = .en`（改动前位于 `ReadmeAssetExporter.swift`，该常量现已删除；指认请用 `git show 194d845:Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift`，**不要用行号** —— 行号随重构漂移），两份 README 引同一批无后缀 PNG。已在 `REQ-copy-plain-language` 被点名为「既有行为，不属本 REQ 范围」 |
| G7 | **截图 shell 是手抄副本** | `ReadmeAssetExporter.swift:56` 自陈 `AtlasScreenshotShell` 是 `AppShellView` 的 lightweight recreation。真实 shell 改了，截图不会跟着改 |

**代价的历史证据**：`fig01-cover.png` 曾以 **98.5% 纯色**的渲染失败产物形式挂在两份 README 顶部，直到 `57fe55b` 才被修掉 —— 它烂掉的那段时间没有任何机制报警。

## 设计决断（产品负责人，2026-09-15）

| # | 问题 | 裁定 |
|---|---|---|
| D1 | 机制形态 | **守卫 + 一条命令重导**。CI 检测漂移并报红，重导由人在本机跑。不让 CI 自动改二进制资产 |
| D2 | 中文 README 的截图语言 | **出双语两套**，两份 README 各引各的 |
| D3 | shell 手抄副本 | **把 shell 源码纳入漂移指纹**，不重构为复用真实 `AppShellView` |
| D4 | 孤儿资产 | **本轮清理** |

## 架构

```
export-readme-assets.sh          ← 唯一重导入口（本机）
  ├─ Swift 渲染      4 路由 × 2 语言 + 图标   → 8 张双语截图 + atlas-icon.png
  ├─ Chrome 渲染     cover.html              → fig01-cover.png
  └─ 重建            manifest.json           （资产摘要 + 渲染输入指纹）
                            │
                            ▼
readme-media-gate.sh  →  readme_media_gate.py  ← 六维机检（可移植，CI 跑）
                            │
                   读 readme_media_fingerprint.py（唯一指纹实现）
                            │
                   读 readme-media-fingerprint-scope.txt（范围声明）
```

### 为什么指纹只有一份实现

导出链路与门禁**都**调 `readme_media_fingerprint.py`。算法不复制进 Swift，也不复制进门禁正文 —— 两份实现必然漂移，而漂移的守卫比没有守卫更糟：它会在错误的地方报红，或者更坏，静默通过。

### 为什么期望资产表在 Python 里另写一遍

`ReadmeAssetExporter.screenshotRoutes`（Swift）与 `readme_media_gate.EXPECTED_SCREENSHOTS`（Python）**故意不同源**。同源的话，导出器把某个路由弄丢时两边会一起忘掉，门禁就成了自证断言 —— 正是本仓 `I-8` 栽过的那个坑。分开写，漏一个就会响。

## 六维

| # | 维度 | 抓什么 | 载体 |
|---|---|---|---|
| 1 | `existence` | manifest 列的资产是否在盘上 | `manifest.json` + 盘 |
| 2 | `dimensions` | 实际像素 vs 期望 vs manifest 记录 | PNG IHDR |
| 3 | `liveness` | **光有文件不够，得是一张画出来的图** | PNG 解码后采样 |
| 4 | `references` | README 引用存在**且语言对得上** | 两份 README |
| 5 | `drift` | 代码改了但截图没重导 | 渲染输入指纹 |
| 6 | `orphans` | 目录无堆积；**产出必被展示、共享资产必被展示** | 引用面 |

第 3 维是唯一能防住「渲染静默失败产出纯色图」的一维 —— 那正是 `fig01-cover.png` 的历史事故。

**精确边界（别把它当内容审查）**：它只采极少像素（2880×1800 截图约 0.79%，跨全部资产平均约 1.03%），是一道**启发式**，抓的是「整张空白 / 整张纯色」这类**粗粒度渲染失败**。它**不是**内容正确性检查，也挡不住刻意构造的图像（见下节对抗审查 #2）。

### 实测代价（如实记录，别被吓到）

| 命令 | 实测耗时 | 说明 |
|---|---|---|
| `readme-media-gate.sh` | **~36 s** | 主要花在第 3 维：11 张 2880×1800 图**逐字节**在 Python 里解 filter |
| `readme-media-gate-selftest.sh` | **~10 min** | 它要跑 17 遍门禁（基线 + 15 变异 + 收尾复核） |

**没有把它优化掉**：手写解码是为了不依赖 Pillow（托管 runner 不保证有它），而 `bytes` 级反过滤在纯 Python 里没有廉价提速路径。36 s 在 CI 的 acceptance 里（swift 测试 + 打包 + DMG 安装 + UI 自动化，分钟级）占比很小；放发版链更是在多分钟打包之前，可忽略。

**知情取舍**：若将来这个 36 s 变碍事，可选的路是「有 Pillow 时走 Pillow、没有时退回手写」，代价是**两份实现**——而那正是本设计在指纹里明确拒绝的模式（两份实现必然漂移）。要走这条路，须先给两条路径加一致性断言。

### 对抗审查（证伪）—— 推翻了我 4 条覆盖声明

按 `iteration-governance` 的 Validation Gate 第三条，收口时派了独立审查员去**证伪**（任务是推翻，不是复核）。它推翻了 4 条，我逐条独立复现确认全部成立，然后逐条修：

| # | 我的声明 | 证伪方式 | 实测 | 性质 |
|---|---|---|---|---|
| 1 | 「尺寸」维覆盖全部资产 | `fig01-cover.png` 同尺寸换图 | **PASS** | 共享资产不在 manifest 里，**只比尺寸、无内容摘要** |
| 2 | 「像素健康」维能防空白/纯色 | 纯白图 + 仅在采样格点 `(x%14, y%9)` 放噪声 | **PASS** | 采样是**固定格点**，是个可精确对齐的靶子 |
| 3 | 「引用完整性」维看的是真实展示 | 把 README 里全部截图引用包进 `<!-- -->` | **PASS** | 正则**不懂 HTML 语义**，注释掉的引用仍算「已展示」 |
| 4 | 「漂移指纹」覆盖 shell 手抄副本 | 改 `ReadmeAssetExporter.swift` 的画布尺寸 | **PASS** | **真正被渲染的是那份手抄副本，而它在的范围里根本没有该文件** |

第 4 条最严重：范围的注释自称「`AtlasScreenshotShell` 是 `AppShellView` 的手抄副本，会静默漂移」，却**把承载副本的那个文件排除在外** —— 注释说的事和范围实际做的事正好错开。改画布尺寸或侧栏宽度，**截图会变、门禁全绿**。

**四条修复**：

1. 共享资产进 manifest（带 `source: shared` 与 `sha256`），同尺寸换图由摘要比对抓住。
2. 采样**逐行错开相位**（固定质数取模，保持可复现），格点构造不再对齐。
3. 扫引用前**剥离 HTML 注释与围栏代码块** —— 不可见的引用不算展示。
4. 范围从「逐个点名 `AppShellView.swift`」改为 **`Apps/AtlasApp/Sources/AtlasApp/**/*.swift` 整个目录**。逐文件点名就是黑名单穷举，漏一个就静默瞎；而代价不对称 —— 多纳一个最多多要一次重导，漏一个则是截图静默过期。

四条修复各自补了一条自检变异。收尾还补了一条：**README 不是合法 UTF-8** 原先会让引用扫描静默退化
（宽容读取可能得出「引用都在」的假象），且 `repr(UnicodeDecodeError)` 会把整个二进制刷进报错文本 ——
现在它是第 4 维的一条精准红（实测整段输出 162 **字节**，其中报错行 69 字符 —— 相比修复前的数千字节刷屏）。自检共 **13 条**变异。

### 自检第三次收益：纠正了我写错的断言维度，并牵出一个真缺口

补上四条修复的变异后跑自检，**[8/13]「引用全部包进 HTML 注释」变红了，但不在我断言的维度**。查明：剥离注释后第 4 维已无引用可查，真正报出来的是第 6 维的「产出但未展示」。

- **断言维度写错 ≠ 守卫漏检**：前者让自检误报，后者才是真漏洞。「红在对的维度」这条断言把两者区分开 —— 这正是它存在的理由。改对维度即可。
- **顺带牵出一个真缺口**：共享资产（封面、预警图）只要列在 manifest 里就算「已引用」，所以第 6 维的目录扫描 **(a) 永远抓不到「README 不再展示封面」**。实测把所有图片引用包进注释后，(a) 全过。
  已补 **(b) 共享资产必须被显示**，并实测「只注释掉封面引用」也会报红。

**教训的形态**：第 4 条与 `REQ-copy-plain-language` 的 `№` 是**同一根因的第二次出现** —— 守卫的输入面没覆盖被检事实的全部载体。区别是这次载体是「承载渲染逻辑的那个文件」而非「另一份数据文件」。这印证了台账里那条 T3：同类失败第二次出现，说明单条补丁治不了，得改问法 —— 每加一条规则，先问**「这条规则看不到的载体有哪些？」**，答案不限于数据，也包括**代码本身**。

### 质量审查：门禁自身的 4 个缺陷（全部已修）

收口前另派三路独立审查（Python 门禁 / Shell 与 CI 接线 / Swift 与文档）找真缺陷。门禁自身被查出 4 条，逐条实测复现后修复：

| # | 缺陷 | 实测 | 修复 |
|---|---|---|---|
| **P0** | `~~~` 围栏不被剥离 —— 只认 ```，而 GitHub 上两者等价 | 把全部图片引用藏进 `~~~` 块 → 六维**全绿**，README 上一张图都看不见 | 围栏正则改为 ```` `{3,}\|~{3,} ```` + **反向引用**，同时修掉「4 反引号围栏内嵌 3 反引号导致提前收尾」 |
| P1 | 截断 IHDR 抛裸 `struct.error`，而各维度只捕 `PngError` / `zlib.error` | 收错类型 → 异常穿到泛化兜底，报错**丢失文件上下文** | IHDR 长度先判再 unpack；三处捕获统一成 `PNG_ERRORS` 元组 |
| P1 | 用 `os.path.isfile` 判引用存在 —— **大小写不敏感**（APFS），而 GitHub 路径大小写敏感 | 写错大小写的引用被判「存在」，且 `LANGUAGE_SUFFIX_PATTERN` 不匹配 → **静默跳过语言检查** | 改用目录清单**精确名**比对，并单列一条「大小写对不上」红 |
| P2 | 解码无尺寸上界 | 声明宽 2³¹−1 的畸形头会让 `stride = width * channels` 进内存分配路径 | IHDR 声明尺寸加 sanity 上界（40M 像素，7× 余量） |

**P0 的复现差点被我自己的测试骗过去**：第一次构造把 `~~~` 塞进表格单元格中间（不在行首），不成其为围栏，门禁返回 PASS —— 我一度以为「本来就没问题」。改用**行首的合法围栏**构造后才复现出真攻击。**测试构造的合法性，与判据本身一样需要被怀疑。**

判据同敏感度这条值得单独记：用大小写不敏感的系统调用去验证一个大小写敏感的命名契约，**判据与载体错配** —— 与「守卫的输入面没覆盖全部载体」是同一族错误的不同衣裳。

### 质量审查：接线与自检的缺陷（Shell/CI 一路）

| # | 缺陷 | 实测 | 处置 |
|---|---|---|---|
| P1 | **Chrome 封面「假成功」** —— 页面加载了但内嵌图 404 时 Chrome 仍 `exit 0`，写出**尺寸正确、像素健康**的退化封面；随后 `--build-manifest` 把它照单记入清单 ⇒ 「渲染退化 ⇒ 重建清单 ⇒ 摘要自洽 ⇒ 六维全绿」 | 健康封面 unique=2125 / 退化封面 unique=1041，**两者都在阈值内**，尺寸检查也救不了 | **已修**：渲染前断言 `cover.html` / `atlas-logo.png` / `atlas-overview-en.png` 三个输入齐备，缺则硬失败 |
| P1 | **自检的隔离副本泄漏报错指错方向** —— stage 缺文件时门禁返回 exit=2，而 `expect_red` 统一打印「期望 exit=1，实际 exit=2」，字面意思是「门禁没变红」，把人引向改门禁规则 | 删 stage 里的 scope 文件 → `NOT_RUN` exit=2 | **已修**：`expect_red` 把 exit=2 单列成「隔离副本不完整（自检搭台问题）」 |
| P2 | **liveness 对共享资产重复检查** —— 共享资产已进 manifest，`targets.extend(SHARED_ASSETS)` 又加一遍 ⇒ 同一缺陷报两次红，`FAIL:N` 这个哨兵失去定量意义 | 0 字节封面报 `FAIL:3`，其中 liveness 重复两条 | **已修**：去重（实测 `FAIL:3` → `FAIL:2`） |
| P2 | `export-readme-assets.sh` 的 `pkill` 后只 `sleep 1`，不复核是否真的退了 | — | **未修**：`pgrep -x` 精确性已验证无误；1 秒是赌注但失败方向是「渲染出错」而非静默假绿。记为已知软点 |
| P2 | 自检注释声称「可以任意并发」，但**自检 × export 并发**不成立（收尾要对真实树做只读复核，会读到导出半成品） | — | **已修**：注释写明确切范围（自检×自检 ✓ / 自检×门禁只读 ✓ / 自检×导出 ✗） |

**一条被纠正的定性**：审查员把「14 个新文件尚未纳入版本控制」列为 **P0「CI 与发版都是红的」**。这不成立 —— 那是**未提交的中间态**，不是设计缺陷；提交时这些文件会一起入库（`git check-ignore` 逐个验证过均不被忽略）。真正值得留档的是它背后的**交付前提**：

> `manifest.json`、4 张 `-zh-Hans` 截图与 5 个脚本**必须同批提交**。只提交一半（例如提交了 workflow 却没提交脚本）会让第 [5/13] 步以 127 / exit 2 挂掉 —— 那才是红的成因。

**教训**：审查员的「严重度」是**相对某一基线**给的。它取的基线是 HEAD，而交付物还在工作树 —— 基线选错会把「还没提交」报成「坏了」。采信前先问「它在跟什么比」。

### 仍未闭合：手抄副本与真实 shell 的一致性

范围扩大后，`AppShellView.swift` 变了会报红。但**报红不等于修好**：重导产出的是那份副本渲染的图，副本没变，图就不变 —— 于是「重导一次」就能让门禁回绿，而截图与真实 shell 的偏差仍在。

本维能发现「原版变了」，**发现不了「副本与原版已不一致」**。根治要么让导出器复用真实 shell（决断 D3 否掉了，需造 `AtlasAppModel` 桩），要么人工核对。**如实记录，不假装已闭合。**

### 门禁卫生

沿用 `copy_gate.py` 的退出码语义：`0` = PASS，`1` = FAIL:N，**`2` = NOT_RUN 且不是通过**。哨兵 `ATLAS_README_MEDIA_GATE=PASS|FAIL:N|NOT_RUN`，机器可读，供 `full-acceptance.sh` 消费。

`readme_media_fingerprint.py` 在范围解析为空集时**抛错而非返回空**：空范围会让指纹退化成常量，门禁从此永远通过 —— 那就是空转守卫。宁可炸掉，不要假绿。

## 指纹范围

覆盖：4 个 feature view 源 + **`Apps/AtlasApp/Sources/AtlasApp/**/*.swift` 整个目录**（含真正被渲染的 `ReadmeAssetExporter.swift`）+ `AtlasDesignSystem` 全部源 + **`Packages/AtlasDomain/Sources/AtlasDomain/**/*.swift` 整个目录**（路由 / fixture / 语言解析 / `AtlasRenderClock`）+ **两份 `Localizable.strings`** + `AtlasApplication/**` + `Docs/Media/README/cover.html`。共 72 个文件。

### 已知看不到的载体（不含糊）

1. **运行时拼接的字符串** —— 指纹只哈希源文件内容，拼出来的值看不到。
2. **`fig01-cover.png` 的内容正确性** —— 尺寸、像素健康与内容摘要都看它，但**封面画得对不对，机器判不了**。
3. **指纹范围外的任何改动** —— 范围是声明的，不是推导的。
4. **部分渲染** —— 只画出侧栏也有一两千种颜色，第 3 维抓不住。这一类比「整张空白」更隐蔽，靠第 5 维 + 人工抽样确认兜底。

### 取舍：为什么范围取宽

两份 `Localizable.strings` 全量入范围，意味着**改任何一条文案都会报红，直到重导截图**。这是刻意的：`REQ-copy-plain-language` 收口时正是手工补做了这件事。

另一条路是把范围收窄到「被渲染的键前缀白名单」，代价是漏检 —— 而白名单属于黑名单穷举，正是本仓 T3 教训点名的失效模式。所以：**取宽**。

**这个取舍的代价现在有具体数字了**（质量审查实测）：

| 量 | 值 |
|---|---|
| 两份 `Localizable.strings` 总键 | **1166** |
| 明确不进任何截图的域（`fileorganizer` / `settings` / `permissions` / `about` / `glossary`） | ≥ **277** |
| 被 4 个截图视图直接引用的键 | **272** |

即：**约 77% 的文案改动会触发一次不必需的重导**（截图不会变，只有 manifest 的指纹会变）。

代价到底多大，取决于重导是否幂等 —— 实测**不幂等**：导出器把墙钟时间烘焙进像素，重导后 4 张图必然变化（见下节）。所以每次假阳性重导会给 git 历史增加约 4 MB 新 blob。

**若要精确化**（未实施，属设计变更）：让导出器在渲染时**记录它实际解析过的 L10n 键**，指纹只哈希那些键的值。这是「按实际使用推导」而非白名单，不落进黑名单穷举。风险：绕过 `AtlasL10n.string` 的取值路径（如 `String(localized:)`）不会被记录 → 改了那种键不报红。当前仓库约定所有 L10n 都走 `AtlasL10n`，但这是**约定不是机制**，采纳前须先给它加守卫。

## 导出器可复现性（质量审查发现，已修）

### 发现

重导两次，**9 张资产里 4 张会变**（`atlas-overview-{en,zh-Hans}` · `atlas-ledger-{en,zh-Hans}`）。差异只有 10 / 41143 个采样点，肉眼比对确认是**绝对墙钟时间**：`Sep 15, 2026 at 6:39 PM` → `9:21 PM`。

**这是既有缺陷**（未改动 `AtlasDomain.swift`），但漂移守卫把它**从偶发变成必然**：守卫会在每次文案改动后要求重导，而每次重导都产出 4 张新图 → 每次约 4 MB 新 blob 进 git 历史。

### 根因是**两半**，只修一半不够

| # | 源 | 位置 | 症状 |
|---|---|---|---|
| ① | fixture 的 `now` 取自 `Date()` | `AtlasDomain.swift` | **绝对时间**（`shortDate`）每次渲染都不同 |
| ② | 相对时间的**参考点**写死为 `Date()` | `AtlasDesignSystem.swift` 的 `AtlasFormatters.relativeDate` | 就算钉死 ①，相对时间仍随真实时间漂：今天读作「11 个月前」，几个月后变「1 年前」 |

**只钉 ① 的失败形态很隐蔽**：日期固定了，看起来「可复现」，但相对时间仍在变 —— 而它在截图上正是显眼的那条。

### 修法：一个注入点治两处

新增 `AtlasRenderClock`（`Packages/AtlasDomain/Sources/AtlasDomain/AtlasRenderClock.swift`），`NSLock` 保护的进程级全局态，与 `AtlasL10n` 同款：

| 消费者 | 改动 |
|---|---|
| `AtlasScaffoldFixtures.now` | `= Date()` → `{ AtlasRenderClock.now }` |
| `AtlasFormatters.relativeDate` | `relativeTo: Date()` → `relativeTo: AtlasRenderClock.now` |
| 导出器 | `setFixedInstant(renderInstant)` + `defer` 还原 |

**为什么不动 fixture 本身**：`AtlasScaffoldFixtures` 还被 `AtlasScaffoldWorkerService`（app 的脚手架 worker）与 `AtlasWorkspaceRepository` 使用，全局钉死日期会改变 app 行为。时钟是**导出专用**的注入点，**正常交互运行的 app 从不碰它** —— 对产品行为零影响。

`renderInstant` 与回执编号的 `scanDate` 复用**同一个常数**（2025-10-09 08:53:20 UTC）：两者必须一致，否则截图上的日期与编号自相矛盾。

### 验证

| 项 | 结果 |
|---|---|
| 连渲两次逐字节比对 | **9/9 一致**（修复前 4 张不同） |
| 再跑一次 `export-readme-assets.sh` | **12 张 PNG 全不变** —— 「重导」现在是幂等的 |
| 截图内容 | 绝对 `Oct 9, 2025 at 4:48 PM`、相对恒为 `4 minutes ago` —— 稳定且自洽 |
| 新增守卫 | `AtlasRenderClockTests` 6 条（`swift test --filter AtlasRenderClockTests`） |
| **变异检验** | 把 fixture 改回 `Date()` → 2 条守卫**变红**，报错信息直指「fixture 的时间戳没有跟着 `AtlasRenderClock` 走 —— 截图将不可复现」 |

### 附带的一课：范围又漏了一次

新文件 `AtlasRenderClock.swift` **影响渲染**，而指纹范围里 `AtlasDomain` 当时仍是**逐文件点名**的 —— 它立刻漏了。同一次改动里，我把「逐项点名 = 黑名单穷举」这个错**犯了第二遍**（第一遍是 `Apps/AtlasApp`）。

已改为 `Packages/AtlasDomain/Sources/AtlasDomain/**/*.swift`，范围 67 → **72** 文件，并补了变异 [13/15] 专门守这个决定。

### 一个留给产品负责人的旋钮

`renderInstant` 钉死在 2025-10-09，于是 README 截图里的日期是**固定的历史时刻**。它不会随发版更新 —— 这是可复现性的代价。若希望截图上的日期随版本走，需要一个构建期输入（如把版本日期传进导出器），属新需求，未做。

## 已知仍未闭合

- **LandingSite 的截图是独立副本且已过时**。`Apps/LandingSite/public/images/screenshots/` 的四张与 `Docs/Media/README/` 重导后的版本**逐字节不同**，时间戳停在 2026-04 ~ 06；`DESIGN.md` 把同目录的**图标**标注为「from Docs/Media/README/」，但那几行截图本身没有来源标注。按 `AGENTS.md`，LandingSite 是独立工具链，故**本轮不扩边界**，但这是同一类缺陷的另一个面，需要单独处置。
- **封面的术语漂移**。`cover.html` 的 pills 里是 `Ledger`、`ledger-strip` 显示 `Ledger №`，而术语基线（`REQ-copy-plain-language/terminology-baseline.md` P-1 / R-1，已签字）把 `Ledger` → `History`、`№` 退役。**未擅自改**：这是营销美术的内容决策，且 app 侧 `№` 目前仍在 5 处 Swift 渲染点存活（`REQ-copy-plain-language/trace.md` 终审 #1），单改封面会造出新的不一致。

## 变异自检

`./scripts/atlas/readme-media-gate-selftest.sh` —— 15 条变异逐维验红，**在临时副本上做**。改门禁规则后**必须**重跑。

本仓两次栽在「守卫空转 / 自证」上（`REQ-ux-friction-remediation` 4 条空转守卫、`REQ-copy-plain-language` 覆盖面残缺），所以这不是形式。

### 第一版就地改工作树 —— 实测撞出三个真缺陷

第一版自检是「备份 → 就地变异 → 还原」。它**在实测中真的出事了**：

1. **与并发读互相污染。** 变异注入在盘上是可见的。它与我派出的对抗审查子代理并发跑时，双方都读到了对方注入的中间态 —— 我先后观测到 `atlas-overview-DOES-NOT-EXIST.png`、`atlas-overview-zh-Hans.png`、`selftest.drift.probe` 三个「幽灵残留」先后出现，并一度据此误判「还原逻辑是坏的」。**实际还原逻辑没问题，问题是不该就地改。**
2. **用陈旧备份覆盖期间发生的无关编辑。** 更严重：子代理那轮自检的备份是在我编辑 README 之前抓的，它的还原把我的改动**静默回滚**了（`README.md:117`）。这类损坏没有任何报错。
3. **中途被杀留脏树。** 我 `pkill` 掉跑飞的实例后，`atlas-apps-en.png` 停在变异态（100×100），伪装成「资产真的坏了」。所幸隔离版的**第 0 步基线检查**当场抓住了它。

改为：把门禁要读的那部分（指纹范围解析出的源文件 + 媒体目录 + 两份 README）复制到临时根，在那里变异，用 `--root` 指过去。真实树一次都不碰，可任意并发，被杀只留一个临时目录。

**这条教训的普适形态**：守卫自检**不该在受检对象的真实副本上做破坏性操作**。「用完还原」在单线程世界里等价，在真实世界里不等价。

## 三处接线，覆盖「版本更新」的三条路径

| 路径 | 位置 | 为什么是这里 |
|---|---|---|
| 本地验收 | `full-acceptance.sh` 第 [5/13] 步 | 改完东西在本机就能发现脱节 |
| CI 推送 | `atlas-acceptance.yml`（`paths:` 含 `Docs/Media/README/**` 与两份 README） | 「只改了截图/README」的推送也必须触发 —— 那正是门禁最该跑的场景 |
| **发版** | `release.yml` 的 `native` job，紧随版本号推导之后 | 发版是「版本更新」真正落地的那一刻，也是截图最容易脱节的一刻。放这里**fail fast**：在昂贵的打包之前就拦住 |

> ⚠️ **CI 那条接线的真实历史，别读成「已验证可用」**：`atlas-acceptance.yml` 自 **2026-08-26 起每一次运行都失败**，卡在 `full-acceptance.sh` 的**第 [1/13] 步** —— 也就是说本 REQ 的媒体门禁（第 **[5/13]** 步）**在 CI 上从未被执行过**。
>
> 收口时我只验了「门禁在本机能跑」+「workflow 接线正确」，**没查这条 workflow 的历史状态**，于是在文档里把它写成了已生效的样子。这是**验证缺口**，不是措辞问题：**一个红的 CI 与一个不存在的 CI，在「有没有在保护你」这件事上等价** —— 三周里没有人注意到。
>
> 两层阻塞已随本 REQ 一并修复（都不属本 REQ 范围，是被它揭出来的）：
>
> 1. `e6227d5` —— `FileOrganizerEvidenceBuilderTests` 断言本地化文案却**不自设语言**，结果取决于 SwiftPM 的测试执行顺序：本地过、CI 红（另见 `ATL-284`，同类文件还有 5 个）。
> 2. `b8b3e36` —— `AtlasAppModel.swift:371` 在 CI 的 toolchain（构建目标 `macos14.0`）上触发类型检查超时，本地（Swift 6.2.4 / `macosx15.0`）不复现。此前从未暴露，因为管线一直卡在第 1 步。
>
> **发版链那条不受影响**：`release.yml` 不调用 `full-acceptance.sh`、不跑 `swift test`，最近 4 次 release 全 success —— 它会在下次打 tag 时真正执行本步。

## 引用

- 工具：`scripts/atlas/{export-readme-assets.sh,readme-media-gate.sh,readme_media_gate.py,readme_media_fingerprint.py,readme-media-fingerprint-scope.txt,readme-media-gate-selftest.sh}`
- 导出器：`Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift`
