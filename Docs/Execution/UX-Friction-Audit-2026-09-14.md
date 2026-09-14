# UX 摩擦审查 — 普通用户视角

- **日期**：2026-09-14
- **范围**：Atlas for Mac 全部用户可达面（Overview / Smart Clean / File Organizer / Apps / Ledger / Permissions / Settings / About）+ 三条跨界面路径（首次上手、失败与恢复、文案与术语）
- **性质**：**只诊断，不含实现方案**。每条都落到具体界面/文案；落不到的一律删除。
- **上游**：`iterations/REQ-ui-ux-overhaul/requirement.md`（上一轮 22 项，状态 DONE，已完成项不重复报）、`Docs/IA.md`、`Docs/Backlog.md`

## 目标用户定义

「普通用户」= 非技术 Mac 用户。不知道缓存 / 残留 / 索引 / 权限弹窗各是什么，装完就想点一下把空间腾出来，出错了只想撤回。界面默认 **zh-Hans**。

## 证据基线与验证方式

两类证据，每条 finding 都标注来源：

- **【实机】** — 用当前 HEAD 源码重新构建（`./scripts/atlas/build-native.sh` → `.build/atlas-native/…/Release/Atlas for Mac.app`），以 zh-Hans 实跑，逐屏截图 + AX 交互验证。截图存于 `/tmp/atlas-*.png`。
- **【代码】** — 未实机复现，依据当前 HEAD 源码 + `Packages/AtlasDomain/Sources/AtlasDomain/Resources/{zh-Hans,en}.lproj/Localizable.strings`。行号与原文均已逐条核对。

**为什么不用现成的 `dist/native/Atlas for Mac.app`**：该包构建于 2026-06-01，落后 HEAD 70 个提交，拿它当"真实界面"会误导。

**严重度定义**：`P0` = 挡住核心任务或造成数据风险；`P1` = 明显劝退；`P2` = 打磨项。

---

## P0 — 挡住核心任务或造成数据风险

### P0-1. 台账恢复失败完全静默，错误文案被写进 **Smart Clean 页**的摘要行 【代码】· EPIC-07

- **位置**：Ledger 详情面板 → 点「恢复」→ 失败后 / `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:828`、`Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift:196`
- **现象**：用户点「恢复」，画面无任何变化，按钮回到「恢复」原样。失败信息写入 `latestScanSummary`，而该字段**只**在 `AppShellView.swift:196` 被渲染——那是 **SmartCleanFeatureView 的 `scanSummary`**。Ledger 屏幕本身对该失败零呈现，用户必须自己切到智能清理页才能看到一行孤立的错误串。
- **代价**：用户得出「我点了恢复 = 文件回来了」的结论。实际 worker 可能在 `validateRestoreTarget` 就整体拒绝，文件仍在恢复区没被还原。他会把这条当作已完成而不做补救——这是「出错了只想撤回」这条核心需求上最直接的失效。
- **证据**：`latestScanSummary = error.localizedDescription`（`AtlasAppModel.swift:828`，位于 `catch` 块内）；`scanSummary: model.latestScanSummary`（`AppShellView.swift:196`，`.smartClean` 分支）；Ledger 构造处（`AppShellView.swift:359-361`）未传任何错误通道。

### P0-2. File Organizer 回执的「撤销」不过门控，点了静默无反应 【代码】· EPIC-13

- **位置**：File Organizer ⑤ 回执 → 点「撤销」/ `Packages/AtlasFeaturesFileOrganizer/Sources/AtlasFeaturesFileOrganizer/FileOrganizerStageViews.swift:586`、`AtlasAppModel.swift:1259-1263`
- **现象**：回执撤销按钮的渲染条件只有 `if let onUndo`，而 `onUndoExecution` 在 `AppShellView.swift:321-323` 是**无条件**传入的，所以按钮总是渲染。点击后 `undoFileOrganizerExecution()` 的第一步是 `guard let recoveryItem = snapshot.recoveryItems.first(where: { if case .fileOrganizer = item.payload }) else { return }` —— 找不到就**直接返回，无任何反馈**。
- **代价**：这是全产品唯一承诺「把文件搬回来」的控件，它说谎了。用户点完以为文件已回到原位，实际一个字节都没动；他可能接着对同一批文件做第二次操作。对比 Smart Clean 同位置有 `hasRestorePoint` 门控（`SmartCleanReceiptView.swift:136`），两个破坏性模块对同一件事规则不同，用户无法学习。
- **佐证**：实机复核时状态文件里被 prune 掉的那条恢复项，正是一条 `文件整理恢复` payload（含真实 `~/Desktop/CleanShot ….png → ~/Organized/Images/…` 映射）——这类记录一旦过期或缺失，撤销按钮仍会渲染。
- **证据**：`if let onUndo {` / `Button(AtlasL10n.string("fileorganizer.undo.action"), action: onUndo)`（`FileOrganizerStageViews.swift:586-587`）；`guard let recoveryItem = snapshot.recoveryItems.first(where: { item in` / `if case .fileOrganizer = item.payload { return true }` / `return false` / `}) else { return }`（`AtlasAppModel.swift:1260-1263`）；对照组 `if receipt.hasRestorePoint, let onUndo {`（`SmartCleanReceiptView.swift:136`）。

### P0-3. Apps 卸载确认弹窗不回答「能不能撤回」 【代码】· EPIC-13

- **位置**：Apps → 选中应用 → 主按钮「执行卸载」→ 确认弹窗 / strings `apps.confirm.uninstall.message`（`zh-Hans.lproj/Localizable.strings:746` ｜ `en.lproj/Localizable.strings:727`）
- **现象**：这是全产品唯一真正删掉应用包的最终确认。弹窗正文是「将移除 %@ 应用包。**仅供复核的残留证据会继续显示在计划里**，本次卸载也会记录到台账中。」——两个未定义名词（残留证据 / 计划）叠在一句里，却没有任何一个字说明：应用没了以后能不能找回、多久内、从哪儿找。
- **代价**：用户在按下破坏性按钮前拿不到判断依据。对照同款确认的 Smart Clean 版（zh:744）明确写了「可恢复项目会保留在台账中；只有具备受支持恢复路径的项目，才支持磁盘级恢复」——卸载版两者都缺。用户要么放弃卸载，要么在错误假设下卸载。
- **证据**：zh-Hans `"apps.confirm.uninstall.message" = "将移除 %@ 应用包。仅供复核的残留证据会继续显示在计划里，本次卸载也会记录到台账中。"`（`zh-Hans.lproj/Localizable.strings:746`）；en `"This will remove %@. Review-only leftover evidence stays visible in the plan, ..."`（`en.lproj/Localizable.strings:727`）；破坏性按钮 `Button(AtlasL10n.string("apps.uninstall.action"), role: .destructive)`（`AppsFeatureView.swift:111`）。

### P0-4. File Organizer 执行确认弹窗不说文件会被移到哪 【代码】· EPIC-02

- **位置**：File Organizer ③ 预演 → 主按钮「执行整理」→ 确认弹窗 / strings `fileorganizer.confirm.execute.message`（zh:965 ｜ en:946）、`FileOrganizerFeatureView.swift:170-181`
- **现象**：标题「执行文件整理？」、正文「将按分类计划移动文件。可在台账中恢复原始位置。」、确认按钮「执行整理」——**标题、正文、按钮三处都不含目标位置**。默认目标是 `~/Organized`（`FileOrganizerFeatureView.swift:70`），一个普通用户从没听过的路径。
- **代价**：这是把文件从用户熟悉的位置（桌面/下载）搬走的操作，按确认前唯一想知道的就是「我的文件会去哪」。用户点完回桌面发现文件没了，会经历一段「我文件被删了吗」的恐慌。破坏性动作的后果无法在执行前从弹窗读出。
- **证据**：zh-Hans `"fileorganizer.confirm.execute.message" = "将按分类计划移动文件。可在台账中恢复原始位置。"`（`zh-Hans.lproj/Localizable.strings:965`）；`Text(AtlasL10n.string("fileorganizer.confirm.execute.message"))`（`FileOrganizerFeatureView.swift:180`）；目标目录默认值 `~/Organized`（`FileOrganizerFeatureView.swift:70`）。

### P0-5. Smart Clean 执行确认弹窗把「台账 / 恢复路径」当已知概念，且不说这次有几项可恢复 【代码】· EPIC-12

- **位置**：Smart Clean ② 复核 → 主按钮「执行已选 N 项」→ 确认弹窗 / strings `smartclean.confirm.execute.message`（zh:744 ｜ en:725）、`SmartCleanFeatureView.swift:156-167`
- **现象**：弹窗正文通篇讲「台账」「磁盘级恢复路径」；确认按钮文案 `smartclean.action.execute` =「执行计划」，与弹性主按钮同名，用户无法从按钮区分「这一步会真的删」。而真正能回答后果的那个数字（这次选中的 N 项里有几项可恢复）**只在主按钮下方的 promise 行里**（`smartclean.promise.partial` ∈ zh:1165），弹窗把它丢了。
- **代价**：「台账」对普通用户不是产品页面而是系统物件（垃圾桶？Time Machine？）。「可恢复项目会保留」听起来像「全都会保留」，下一句又限定「只有具备受支持恢复路径的项目」——用户在两个互斥的听感之间无法收敛，只能按默认动作往下走，把破坏性决定当成下一步。
- **证据**：zh-Hans `"smartclean.confirm.execute.message" = "将按复核后的计划执行清理。可恢复项目会保留在台账中；只有具备受支持恢复路径的项目，才支持磁盘级恢复。"`（`zh-Hans.lproj/Localizable.strings:744`）；`Button(AtlasL10n.string("smartclean.action.execute"), role: .destructive)`（`SmartCleanFeatureView.swift:161`）；实机 ② 复核页 promise 实测原文 `⛨ 22/23 项可恢复 · 保留 7 天 · 全程录入台账`。

---

## P1 — 明显劝退

### 首次上手路径

#### P1-1. 首次上手被一条不可忽略的权限横幅挡住 【实机】· EPIC-11

- **位置**：Overview → 全新安装、未授予完全磁盘访问时的最高优先级横幅 / `Packages/AtlasFeaturesOverview/Sources/AtlasFeaturesOverview/OverviewRecommendation.swift:127-141`、strings `overview.recommend.permission.headline`（zh:326）
- **现象**：`recommend()` 的第一条分支（Row 1）在缺必需权限时无条件返回，`isSnoozeable: false` —— 用户**不能忽略、不能绕过**。实机截图确认：首屏横幅「先授权以解锁完整功能 / 当前仍缺少至少一项主流程必需权限，Atlas 因此保持受限模式。」+「前往授权」按钮，**画面上不存在任何忽略/关闭控件**。
- **代价**：用户一次扫描都没跑过，产品第一句话就是要求系统级授权。「主流程必需权限」「受限模式」对非技术用户不可映射；因为无法忽略，他要么被迫跳进系统设置面对更陌生的弹窗，要么卡在原地完不成首次清理。
- **证据**：实机截图 `/tmp/atlas-01-overview.png`；`if inputs.requiredPermissionsTotal > 0 && inputs.requiredPermissionsGranted < inputs.requiredPermissionsTotal {` / `return BannerConfig(...)` / `isSnoozeable: false`（`OverviewRecommendation.swift:129-140`）；zh-Hans `"overview.recommend.permission.headline" = "先授权以解锁完整功能";`（zh:326）。

#### P1-2. Overview 首屏第一句是问候语，没有一句告诉他第一步干什么 【实机】· EPIC-11

- **位置**：Overview 落地页顶部 / `OverviewFeatureView.swift:164-194`
- **现象**：实机确认渲染顺序为：问候语「你好，这台 Mac 今天怎么样」（`overview.greeting.morning`，硬编码 morning 变体）→ 三枚状态胶囊（磁盘 23% / 可恢复 0 项 / 权限 0/1）→ 才轮到"下一步"横幅。另外 `overview.callout.limited.title/detail`（zh:250-251，「你仍然可以在受限模式下继续使用」）**在全部 Swift 源码中零引用**——唯一一句解释受限模式的现成文案没有被渲染。
- **代价**：首屏最贵的位置被"寒暄 + 三个读不懂的指标"占掉。用户需要继续往下扫视才碰到可点按钮。
- **证据**：实机截图 `/tmp/atlas-01-overview.png`；`Text(AtlasL10n.string("overview.greeting.morning"))`（`OverviewFeatureView.swift:167`）；胶囊三连（`:171-193`）；`grep -rn 'overview\.callout\.limited' --include='*.swift'` 零命中，而键存在于 `zh-Hans.lproj/Localizable.strings:250-251`。

#### P1-3. 第一次扫描会撞上一个毫无铺垫的系统弹窗 【实机】· EPIC-11

- **位置**：文件整理 ① 扫描 → 点「扫描文件夹」/ 系统 TCC 弹窗
- **现象**：扫描一开始，立刻弹出裸的 macOS 授权框：**「"Atlas for Mac" 想访问 "下载" 文件夹中的文件。」**（不允许 / 允许）。此时 app 自己那行还写着「正在扫描 Desktop、Downloads… (1/1)」，进度环转到 10%。**弹窗之前没有任何 app 内的前置说明**。
- **代价**：这是普通用户在这个 app 里做的第一个动作，第一反应就是系统级的隐私质询。他不理解为什么一个清理软件要动「下载」文件夹，最省事的反应是点「不允许」——一拒就永久挡住了文件整理的主路径，而 app 端只显示一个裸错误（见 P2-16：FO 模块内零权限文案）。对比：Smart Clean 有 `model.scan.limited.permissions`（「尚未授予完全磁盘访问，扫描可能较慢…可在「权限」中授权」，zh:215）这类铺垫，文件整理路径上完全没有。**（二次回源补记）** 但这句话并不像这里说的那么体面——它实际被渲染在**失败标题**下，见补报 `NEW-1`。
- **证据**：实机截图 `/tmp/atlas-06-fo-scan2.png`（TCC 对话框 + 同期 app 内进度文案）。**审查过程中未代点「允许」或「不允许」**——那是持久的系统授权决定，应由产品负责人/用户自行决定；本条验证到此为止。

### Permissions

#### P1-4. 权限页「暂不需要」卡显示的是未授予数，同一批权限在下方又叫「待处理」 【实机】· EPIC-11

- **位置**：Permissions → 权限概览指标卡 / `PermissionsFeatureView.swift:80-86`、strings `permissions.metric.later.title`（zh:634）、`permissions.optionalSection.count.other`（zh:646）
- **现象**：实机截图确认两张卡并排：「当前必需 `0/1`」与「**暂不需要 `2`**」——后者是一个**缺失计数**挂在读作类别名的标题下。同一批权限在下方列表里又被标成 `"%d 项待处理"`。
- **代价**：用户读到「暂不需要 2」和「2 项待处理」两个指同一件事、结论相反的说法，不得不反复判断到底要不要管。这是权限页唯一在回答「我现在还差什么」的地方，两个口径打架等于没回答。
- **证据**：实机截图 `/tmp/atlas-10-permissions.png`；`title: AtlasL10n.string("permissions.metric.later.title"),` / `value: "\(optionalMissingCount)",`（`PermissionsFeatureView.swift:81-82`）；zh-Hans `"permissions.metric.later.title" = "暂不需要";`（zh:634）｜ `"permissions.optionalSection.count.other" = "%d 项待处理";`（zh:646）。

#### P1-5. 权限行的说明文字直接暴露 `Library` 和「系统级缓存」 【实机】· EPIC-11

- **位置**：Permissions → 权限列表每行副标题 + 「下一步」卡片 / `Packages/AtlasFeaturesPermissions/Sources/AtlasFeaturesPermissions/PermissionRowView.swift:28`、strings `fixture.permission.fullDiskAccess.rationale`（zh:80）、`permissions.support.fullDiskAccess`（zh:658）
- **现象**：每行副标题直接绑定 `state.rationale`；下一步卡片实机渲染原文为「**只有在你想扫描更深层的受保护 Library 位置时才需要。**若刚开启，请完全退出并重新打开 Atlas，再回来检查。」
- **代价**：用户在最需要被说服的那一行读到的是纯技术描述：不知道 `Library` 是什么。他无法形成「给你这个权限对我是安全的」的判断，倾向于直接拒绝——权限被拒 → 回到 P1-1 的卡死。真正可读的三段式解释（为什么需要/影响范围/如何授权）反而被折叠在需要主动点开的槽位里。
- **证据**：实机截图 `/tmp/atlas-10-permissions.png`；`subtitle: state.rationale`（`PermissionRowView.swift:28`）；zh-Hans `"fixture.permission.fullDiskAccess.rationale" = "只有在扫描系统级缓存、应用残留和受保护的 Library 路径时才需要。";`（zh:80）。

#### P1-6. 权限被拒跳转后没有二次引导，也无回执 【代码】· EPIC-11

- **位置**：Permissions → 点「打开系统设置」跳走再回来 / `PermissionsFeatureView.swift:272-286`、`:157-162`
- **现象**：点按钮只做 `NSWorkspace.shared.open(url)` 就结束；回到 app 只靠 `scenePhase == .active` 被动触发一次 `onRefresh()`。若用户没勾选、或勾完没重启 Atlas，页面状态不变，也没有任何「你去过了但仍未生效，可能是 X」的提示。
- **代价**：用户点了按钮、跳走、回来、发现还是「需要授权」——结论是「这个软件坏了」，然后放弃清理。
- **证据**：`if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }`（`PermissionsFeatureView.swift:283-285`）；`guard newPhase == .active, !isRefreshing else { return }` / `onRefresh()`（`:158-161`）。
- **修订说明**：本条原含「重启提示埋在折叠面板深处」的子论断，实机复核**已推翻**——重启提示在「下一步」卡片里直接可见（见 P1-5 证据）。故本条降级并只保留"跳转后无回执/无二次引导"部分。

### Smart Clean

#### P1-7. Smart Clean ② 复核页没有「全选」，对比 File Organizer 有 【实机】· EPIC-12

- **位置**：Smart Clean ② 复核 → 想一次清完 / `SmartCleanStageViews.swift:118-147`
- **现象**：实机 ② 复核页右侧面板只有「已选 23 项 / 7.4 GB」+ 风险图例（安全 10 / 复核 12 / 高级 1），**没有任何全选 / 取消全选控件**。File Organizer 的同阶段有完整的「全选 / 取消全选」（`FileOrganizerStageViews.swift:168-189`，strings `fileorganizer.action.selectAll` ∈ zh:1004）。
- **代价**：用户的核心意图是「把空间腾出来」，最自然的动作是「全选然后执行」。扫描出几十项时他只能逐条点勾——大概率放弃，或只勾前几项。而且主按钮「执行已选 N 项」在 N=0 时置灰（`SmartCleanActionBarModel.swift:115`），用户要先经历一次「按钮点不动」才知道要先勾选。
- **证据**：实机截图 `/tmp/atlas-20-rightpanel.png`；② 阶段 body 无 select-all 分支（`SmartCleanStageViews.swift:130-142`）；对照 `Text(AtlasL10n.string("fileorganizer.action.selectAll"))`（`FileOrganizerStageViews.swift:174-178`）；`isEnabled: inputs.canExecutePlan && inputs.selectedCount > 0`（`SmartCleanActionBarModel.swift:115`）。

#### P1-8. Smart Clean 回执的「撤销」在不满足条件时是**不存在**，不是置灰 【代码】· EPIC-12

- **位置**：Smart Clean ④ 回执 → 想撤回 / `SmartCleanReceiptView.swift:136`、门控 `:53-55`
- **现象**：撤销按钮的渲染条件是 `receipt.hasRestorePoint, let onUndo`，而 `hasRestorePoint` 要求 `!recoveryItemIDs.isEmpty && recoveryBytes > 0`。只要本次运行没有产生**字节数 > 0** 的恢复项，按钮**完全不渲染**——回执上没有任何「本次不可恢复」的说明。
- **代价**：用户把「界面上没有撤销按钮」读成「这次不需要撤销」或「这功能本来就没有撤销」，而不是「本次不可恢复」。执行是破坏性的，回执是他唯一会主动看的收尾界面。（门控本身是 fail-closed 的刻意设计，问题在于缺失没有解释。）
- **证据**：`if receipt.hasRestorePoint, let onUndo {`（`SmartCleanReceiptView.swift:136`）；`public var hasRestorePoint: Bool {` / `!recoveryItemIDs.isEmpty && recoveryBytes > 0`（`:53-54`）。

#### P1-9. Smart Clean ③ 执行中：一个空弧 + 一句话，没有进度也没有剩余时间 【代码】· EPIC-12

- **位置**：Smart Clean ③ 执行中 → 点完确认之后 / `SmartCleanStageViews.swift:299-309`、`SmartCleanActionBarModel.swift:100`
- **现象**：执行阶段渲染的是**故意的不确定态**：空弧进度圈、`play.circle.fill` 图标、一行 `smartclean.loading.execute` =「正在执行已复核的清理计划」。action bar 的主按钮位被替换成 `progress: nil, intent: .none` 的胶囊。
- **代价**：破坏性操作正在跑、界面不给任何「到哪了/还剩多久」，普通用户的第一反应是「卡住了/死机了」，接着会去点别的（切页面、重复点扫描）。而 `isExecuting` 期间 action bar 唯一动作是 `.none`——点了没反应，进一步强化「卡住了」的判断。
- **证据**：`progress: isExecuting ? 0 : progress,`（`SmartCleanStageViews.swift:301`）；`Text(AtlasL10n.string("smartclean.loading.execute"))`（`:309`）；`progress: nil, intent: .none`（`SmartCleanActionBarModel.swift:100`）。
- **未实机复核**：走到 ③ 需要执行一次真实清理（破坏性），审查期间未执行。以上为代码证据。

#### P1-10. Smart Clean 空态里的「重新扫描」弹出的是「作废」破坏性对话框 【代码】· EPIC-12

- **位置**：Smart Clean ② 复核 → 命中 0 条时的空态按钮 / `SmartCleanStageViews.swift:120-128`、`SmartCleanFeatureView.swift:347-348`、`AppShellView.swift:225-229`
- **现象**：空态按钮文案是 `smartclean.stage.actionbar.rescan` =「重新扫描」，动作走 `rescanTapped()` → `state.planNumber != nil ? onRequestRescan() : onStartScan()`。只要存在计划编号，`onRequestRescan` 就把 `rescanConfirmationPending` 置 true，弹出 `role: .destructive` 的「作废并重新扫描」对话框，正文是「当前计划 №N 将作废」。
- **代价**：用户的意图是「再扫一遍」，收到的却是「你要作废一个计划吗」+ 一个红色破坏性按钮。他大概率取消；取消后仍停在同一个空态，而那个按钮是这一屏唯一的出口动作。标签与后果不匹配会让他对后续所有红色确认按钮脱敏。
- **证据**：`actionTitle: AtlasL10n.string("smartclean.stage.actionbar.rescan"),` / `onAction: onRequestRescan`（`SmartCleanStageViews.swift:126-127`）；`state.planNumber != nil ? onRequestRescan() : onStartScan()`（`SmartCleanFeatureView.swift:348`）；`Button(AtlasL10n.string("smartclean.rescan.confirm"), role: .destructive, action: onConfirmRescan)`（`SmartCleanFeatureView.swift:151`）。

#### P1-11. Smart Clean 执行失败后，「查看回执」是一个死按钮 【代码】· EPIC-15

- **位置**：Smart Clean ③ 错误态 → 想搞清楚发生了什么 / `SmartCleanActionBarModel.swift:131-135`、`SmartCleanEvidenceBuilder.swift:95-97`
- **现象**：执行中途失败时，错误态提供的出路是「查看回执」，但 action bar 这一项 `isEnabled: inputs.hasReceipt`，而 `hasReceipt` 来自 `executionReceipt != nil`。若失败发生在 worker 返回 receipt 之前，按钮置灰；此时错误态内嵌的 `AtlasErrorState` action 虽可点，但 `onViewReceipt` 只改 `displayedStage`，而 `effectiveStage` 会把它退回 `currentStage`——界面不动。
- **代价**：用户看到失败，唯一给出的出路点了没反应 → 判定「这个 App 坏了」，而不是「这次失败连回执都没生成」。破坏性操作失败后他最需要知道的是「到底删了没有、删了几项」——这条路径把他堵死。
- **证据**：`isEnabled: inputs.hasReceipt, promise: nil, metricText: nil,`（`SmartCleanActionBarModel.swift:133`）；`if displayedStage == SmartCleanStage.receipt,` / `currentStage == SmartCleanStage.execute,` / `hasReceipt {`（`SmartCleanEvidenceBuilder.swift:95-97`）。

#### NEW-1. 非错误信息走在错误通道上：受限模式软提示被渲染成「未能更新当前计划」的失败标题 【代码】· EPIC-12

- **位置**：Smart Clean ② 复核 / `Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanStageViews.swift:45-50`；赋值点 `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:390`
- **现象**：`AtlasAppModel.swift:387-390` 的注释自述「受限模式软提示（**非阻断**）」，却把这条提示赋给 `smartCleanPlanIssue`：

```swift
// 受限模式软提示（非阻断）：未授权完全磁盘访问时扫描可能缓慢且范围受限。
// 此前用户在受限模式下只看到静态「正在开始…」文案并误判为卡死。
if !smartCleanRequiredPermissionsReady {
    smartCleanPlanIssue = AtlasL10n.string("model.scan.limited.permissions")
}
```

  而 `SmartCleanStageViews.swift:45-50` 把 `planIssue` **一律**渲染为错误态——不论它是真失败还是这条非阻断提示：

```swift
if let planIssue {
    AtlasErrorState(
        title: AtlasL10n.string("smartclean.status.revalidationFailed"),  // 「未能更新当前计划」
        message: planIssue,                                               // 「…扫描可能较慢且范围受限…」
        layout: .inlineRow
    )
} else if hasCachedFindings {
    AtlasCallout(..., tone: .warning, ...)   // :52 —— 同一视图里「警告态」的渲染路径本就存在
}
```

  结果是**失败标题配非失败正文**：未授权用户在整个扫描期间读到「未能更新当前计划」+「扫描可能较慢且范围受限」，且该值只在扫描成功后才被清（`AtlasAppModel.swift:414`）。
- **代价**：受限模式**不是错误**——扫描照常跑（注释明言「非阻断」）。但用户读到的是失败标题，会以为 Smart Clean 坏了；紧接着正文说「扫描可能较慢」，两者对不上，他无法判断这是故障还是正常降级。而「未授权完全磁盘访问」恰是新用户首跑的**最常见状态**——错误信号出现在第一次使用的主路径上，与 P1-1/P1-3 的「首跑信任」问题同源。
- **证据**：`if let planIssue {` / `AtlasErrorState(` / `title: AtlasL10n.string("smartclean.status.revalidationFailed"),` / `message: planIssue,`（`SmartCleanStageViews.swift:45-49`）；`smartCleanPlanIssue = AtlasL10n.string("model.scan.limited.permissions")`（`AtlasAppModel.swift:390`）；注释原文（`:387-388`）；清空点 `smartCleanPlanIssue = nil`（`:414`）；对照——同视图 `:52` 已有 `AtlasCallout(tone: .warning)` 这一非错误渲染路径可用。
- **补报说明**：本条为**漏报**，非引用错误。`P1-3` 曾把这句文案当作（相对 FO 的）正面「铺垫」引用，未发现它挂在失败标题下——审计的**评价性引用**（正面/负面）同样需要回源。详见文末「审校记录 § 补报 1 条」。

### File Organizer

#### P1-12. 整理去向的折叠区用了 Smart Clean 的标题，且折叠态不透出当前去向 【实机】· EPIC-02

- **位置**：File Organizer ① 扫描 → 首次进入 / `FileOrganizerSupportViews.swift:227-239`
- **现象**：实机确认 ① 扫描页显示一个折叠的 `› 扫描与计划` 区块，其标题取自 `smartclean.controls.title` = **「扫描与计划」**——智能清理的字符串被文件整理复用。区块内是「文件夹选择 / 目标文件夹 / 包含子文件夹」三项，`defaultExpanded: false`。
- **前提说明**：**「配置区默认收起」本身是 `iterations/REQ-ui-ux-overhaul/requirement.md` P2-3 明确指定的既定设计**（「配置区（AtlasSectionDisclosure，默认收起）」），已作为 DONE 交付，**不计为问题**。本条只针对该实现残留的两点：① 折叠标题借用了别的模块的文案；② 折叠态下标题与摘要都不透出「文件将被整理到哪里」，而这是用户在按下执行前唯一必须知道的参数。
- **代价**：用户点扫描前看不到文件会被整理到哪（默认 `~/Organized` 是个陌生路径），也看不到「包含子文件夹」这个显著改变扫描范围的开关是关着的。以为在整理桌面、实际只扫了一层；或者以为去「桌面/文档」、实际去了一个没听过的目录。中文标题「扫描与计划」出现在「文件整理」模块里，还会让他怀疑走错了页面。
- **证据**：实机截图 `/tmp/atlas-03-fo.png`（折叠态 `› 扫描与计划`）；`AtlasSectionDisclosure(` / `title: AtlasL10n.string("smartclean.controls.title"),` / `defaultExpanded: false`（`FileOrganizerSupportViews.swift:228-230`）；zh-Hans `"smartclean.controls.title" = "扫描与计划";`（zh:352）。

#### P1-13. 同一件「冲突」在 File Organizer 三个位置给出三种后果暗示 【代码】· EPIC-12

- **位置**：FO ② 规则列表 footnote（`FileOrganizerStageViews.swift:282`）／ ③ 预演 callout（`:413-421`）／ 回执 fact 行（`:610-615`）
- **现象**：② 说「目标位置已存在同名文件：%@」（听感＝会覆盖）；③ 说「执行时将自动重命名冲突文件（如 filename (1).png）。取消选中可跳过这些文件。」（听感＝自动、无损）；回执说「%d 项失败（可重试）」（听感＝又失败了，而且没地方重试）。
- **代价**：用户在 ② 阶段（比 ③ 停留得多）读到「已存在同名文件」会主动取消勾选，白做一遍工、并怀疑产品会覆盖文件；带着 ③ 的「自动重命名」承诺去执行的用户，得到的是「N 项失败」且不知道失败的就是那批文件。「可重试」在回执上也没有对应入口。
- **证据**：zh-Hans `"fileorganizer.conflict.exists" = "目标位置已存在同名文件：%@";`（zh:1012）｜ `"fileorganizer.conflict.callout.detail" = "执行时将自动重命名冲突文件（如 filename (1).png）。取消选中可跳过这些文件。"`（zh:1014）｜ `"fileorganizer.receipt.failed.value" = "%d 项失败（可重试）";`（zh:1091）；渲染点两处：`return AtlasL10n.string("fileorganizer.conflict.exists", entry.proposedDestination)`（`FileOrganizerStageViews.swift:282`，② 列表 footnote；同一 key 亦渲染于证据面板 `FileOrganizerEvidenceBuilder.swift:245`）。

#### P1-14. File Organizer 执行失败后同一条死路径 【代码】· EPIC-15

- **位置**：File Organizer ④ 执行 → 中途失败 / `FileOrganizerActionBarModel.swift:153-157`、`FileOrganizerStageMap.swift:161-163`
- **现象**：与 P1-11 同构——「查看回执」的 `isEnabled: inputs.hasReceipt`，进入回执页也要求 `hasReceipt`，`onViewReceipt` 只改 `displayedStage`。
- **代价**：FO 的后果更重——失败发生在**文件正在被移动**的过程中，用户最需要知道「哪些已经移走、原来在哪」。回执不可达时这些信息没有任何出口（只在台账里，而普通用户不知道台账是什么）。
- **证据**：`isEnabled: inputs.hasReceipt, promise: nil, metricText: nil,`（`FileOrganizerActionBarModel.swift:155`）；`if displayedStage == FileOrganizerStage.receipt,` / `currentStage == FileOrganizerStage.execute,` / `hasReceipt {`（`FileOrganizerStageMap.swift:161-163`）。

### Ledger

#### P1-15. 台账把「已过期」显示成「已归档」，且和「任务失败/取消」共用同一个词 【代码】· EPIC-07

- **位置**：Ledger 时间线状态徽标 / `LedgerTimelineView.swift:160-173`、strings `ds.ledger.status.archived`（zh:1237）
- **现象**：恢复项过期后 `status(for item:)` 返回 `.archived`，徽标显示「已归档」。**另一个同名重载** `status(for run:)` 里，任务运行 `.failed` / `.cancelled` **也**返回 `.archived`。两者是 `LedgerTimelineView.swift` 里两个独立重载（`status(for run: TaskRun)` @ `:156`、`status(for item: RecoveryItem, now: Date)` @ `:167`），**并非同一段 switch**；但「已归档」一词确实同时兼指「恢复窗口已关闭」与「任务没成功」两个状态，问题实质不变。同时 `LedgerFilter.archive` 的匹配条件就是 `item.isExpired`（`LedgerFeatureView.swift:336`）。实机确认筛选芯片文案为「全部 | 可恢复 | 归档」。
- **代价**：普通用户读「已归档」＝「已安全保存」，不会意识到这是**不可恢复的终态**。等意识到文件找不回来时为时已晚。「归档」在这里同时指「已完成任务的历史」和「恢复窗口已关闭」，用户点「归档」筛选想找刚卸载的那个 app 时，看到的是一堆过期记录。
- **证据**：`if expiresAt <= now { return .archived }`（`LedgerTimelineView.swift:171-172`）；`case .failed, .cancelled: return .archived`（`:162-163`）；`case .archive: return item.isExpired`（`LedgerFeatureView.swift:336`）；zh-Hans `"ds.ledger.status.archived" = "已归档"`（zh:1237）；实机截图 `/tmp/atlas-12-ledger.png`。

#### P1-16. 过期恢复项会被静默删除，用户看到的「记录消失」没有任何解释 【实机】· EPIC-07

- **位置**：Ledger 时间线与指标 / `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasScaffoldWorkerService.swift:988-998`
- **现象**：`pruneExpiredRecoveryItemsIfNeeded` 执行 `state.snapshot.recoveryItems.removeAll { expiredIDs.contains($0.id) }` 并落盘。**实机复核期间当场观察到：`recoveryItems` 由 1 → 0**（原记录是一条 `文件整理恢复`，`expiresAt` ≈ 2026-07-19，payload 含真实 `~/Desktop/CleanShot ….png → ~/Organized/Images/…` 移动映射）。
- **代价**：用户上次看到某条「即将到期」，下次打开 app 它凭空不见了，没有任何提示说明「这条已被清理」。他会去找（以为还有几天），找不到就怀疑 Atlas 弄丢了数据。这也让 `ledger.recovery.badge.expired` 那一整套「已过期」文案在实践中几乎不可达——用户永远见不到那条记录的终态。
- **证据**：`state.snapshot.recoveryItems.removeAll { expiredIDs.contains($0.id) }`（`AtlasScaffoldWorkerService.swift:995`）；`await persistState(context: context)`（`:996`）；实机对比 `/tmp/atlas-workspace-state.backup.json` 与运行后的 `~/Library/Application Support/AtlasForMac/workspace-state.json`。

#### P1-17. 恢复成功的反馈对「真还原了文件」和「只在 Atlas 内标记」是同一种 【代码】· EPIC-07

- **位置**：Ledger 详情 → 点「恢复」之后 / `LedgerDetailView.swift:166-187`、`AtlasScaffoldWorkerService.swift:377-396`、`:421`
- **现象**：点之前界面是诚实的——按钮标题区分「恢复」/「在 Atlas 中恢复」，hint 区分 `fileBacked` / `stateOnly`。但恢复完成后，无论走磁盘还原还是仅状态还原，恢复项都被 `removeAll` 移除（`:421`），指标「可恢复项」数字同步下降，台账留下一条 `.completed` 任务。两种恢复的**成功信号完全相同**；`physicalRestoreCount` / `atlasOnlyRestoreCount` 只影响 `restoreSummary`，不影响任何 UI 状态。
- **代价**：state-only 的恢复项（例如清缓存记录）恢复后，用户看到「已完成」，会去访达找文件——文件从来没被还原过。文案底子是对的，反馈层没有继承它。
- **证据**：`if let restoreMappings = item.restoreMappings, !restoreMappings.isEmpty { ... physicalRestoreCount += 1 } else { atlasOnlyRestoreCount += 1 }`（`AtlasScaffoldWorkerService.swift:377-396`）；`state.snapshot.recoveryItems.removeAll { requestedItemIDs.contains($0.id) }`（`:421`）；`let canRestore = restoringItemID == nil && !item.isExpired`（`LedgerDetailView.swift:168`）。

### App Shell

#### P1-18. 「设置」没有任何菜单入口或键盘路径，⌘, 也不响应 【实机】· EPIC-14

- **位置**：App Shell 菜单栏 / `Apps/AtlasApp/Sources/AtlasApp/AtlasAppCommands.swift:14-28`、`:86-104`
- **现象**：实机读出的导航菜单只有 **概览 / 智能清理 / 文件整理 / 应用 / 台账 / 权限** 六项 + 打开任务中心；设置与关于不在其中（`AtlasRoute.sidebarRoutes` 不含二者）。⌘1–⌘6 覆盖那六个，而 `shortcutKey` 对 `.settings / .about` 直接 `preconditionFailure`。实测按 **⌘, 无任何反应**（无 Settings scene，也无该快捷键绑定）。关于尚可通过 App 菜单的「关于 Atlas」抵达；**设置只能用鼠标点侧边栏**。
- **代价**：习惯键盘或菜单栏的用户找不到设置入口，会以为产品没有设置。macOS 用户对 ⌘, 有肌肉记忆，按下去没反应会进一步加深「这软件没做完」的判断。
- **与已交付 REQ 的关系**：`iterations/REQ-ui-ux-overhaul/requirement.md` 的 P1-3 把「**⌘,: 打开 Settings**」列为已完成项（该 REQ 整体 Status = DONE）。实际代码里不存在该绑定。**所以本条不是重复上报已完成项，而是记录一个标记为 DONE 却未交付的子项。**
- **证据**：实机读出的菜单项 `概览, 智能清理, 文件整理, 应用, 台账, 权限, missing value, 打开任务中心`；`case .settings, .about: preconditionFailure("Non-sidebar routes have no shortcut key")`（`AtlasAppCommands.swift:101-103`）；`CommandMenu` 只遍历 `AtlasRoute.sidebarRoutes`（`:14-20`）；`grep -n 'keyboardShortcut' AtlasAppCommands.swift` 无任何 `","` 绑定。

---

## P2 — 打磨项

### 术语与文案

#### P2-1. 「残留 / 足迹 / 台账 / 复核 / 证据」是全产品的核心词汇，但没有任何一处解释 【实机】· EPIC-02

- **位置**：Apps 指标卡与证据面板、Smart Clean 风险分区、Ledger 标题 / strings `apps.metric.leftovers.title`（zh:442）、`apps.evidence.why.idle`（zh:513）、`route.ledger.title`（zh:13）、`risk.review`（zh:25）
- **现象**：实机确认 Apps 证据面板原文「**Xcode 的占用与残留足迹**。先预览卸载计划，再逐项确认可恢复步骤。」——「足迹」在中文里默认指行踪。`Docs/COPY_GUIDELINES.md:44-48` 有 en 术语表（`App Footprint` / `Leftover Files` / `Limited Mode`），但那是给开发者看的，产品内无对应说明。
- **代价**：用户不知道「残留」是卸载后留下的配置文件、「证据」是扫到但本次不移除的清单。最坏情况是把「仅供复核」读成「需要我批准才能删」，于是在纯风险提示的分组里逐个手点。
- **证据**：实机截图 `/tmp/atlas-11-apps.png`；zh-Hans `"apps.evidence.why.idle" = "%@ 的占用与残留足迹。先预览卸载计划，再逐项确认可恢复步骤。";`（zh:513）｜ en `"Footprint and leftovers for %@. ..."`（en:513）｜ `"apps.metric.leftovers.title" = "残留文件";`（zh:442）。

#### P2-2. 风险筛选 chip「复核」与阶段条「复核」同屏同名、语义无关 【代码】· EPIC-14

- **位置**：Smart Clean ② 复核页 / `SmartCleanStageViews.swift:149-167`、`SmartCleanSupportViews.swift:48`
- **现象**：实机 ② 页顶部阶段条第二段是「复核」，同一屏的筛选 chips 里也有「复核」（来自 `risk.review`）。两个控件共用一个词。
- **代价**：用户点阶段条的「复核」是切到第 2 步，点 chips 的「复核」是筛风险级别。同名控件、同屏、完全不同的行为——用户会把它当成导航，点下去发现列表被过滤了而标题没变，判断为「界面出错了」。
- **证据**：实机截图 `/tmp/atlas-20-sc-review.png`；zh-Hans `"risk.review" = "复核";`（zh:25）｜ `"smartclean.stage.review" = "复核";`（zh:1146）；渲染点 `AtlasStage(id: SmartCleanStage.review, title: AtlasL10n.string("smartclean.stage.review"))`（`SmartCleanSupportViews.swift:48`）。

#### P2-3. 同一个「%d 项」在权限语境和文件语境里反复切换量纲 【代码】· EPIC-14

- **位置**：Permissions 概览（zh:646）、Overview 权限胶囊（zh:303）、侧栏（zh:1136）／ Smart Clean 与 File Organizer 计数（zh:421、zh:1003）
- **现象**：权限语境用「项」（「2 项待处理」），文件语境也用「项」（「%d 个发现项」「已选 %d / %d 项」）。中文没有单复数形态，`%d 项` 在两种语境下字形完全相同。
- **代价**：用户在权限页读到「2 项待处理」会先想「哪 2 个文件」；在动作条读到「3/5 项可恢复」又要重新判断这次是文件还是权限。每次都要靠上下文重算「项」的量纲。
- **证据**：zh-Hans `"permissions.optionalSection.count.other" = "%d 项待处理";`（zh:646）｜ `"smartclean.summary.findingCount" = "%d 个发现项";`（zh:421）｜ `"fileorganizer.selection.count" = "已选 %d / %d 项";`（zh:1003）。

#### P2-4. 「需确认」是一个分类标签，但它读起来像一个待办动作 【代码】· EPIC-14

- **位置**：证据面板安全分组 chip / strings `evidence.safety.conditional`（zh:1207 ｜ en:1188）
- **现象**：en 是 `"Conditional"`（形容词，风险等级），zh 译成「需确认」——状态变成了动作。同族还有 `apps.preview.row.review`（zh:468）「仅供复核的证据项」、`smartclean.execution.reviewOnly`（zh:378）等，en 侧三个不同词（`Review` / `Review Only` / `Conditional`）在 zh 侧全部塌缩到「复核」一族。
- **代价**：用户看到「需确认」会去找「确认」按钮，而这个 chip 只是分类标签、没有对应动作。找不到 → 反复点开证据面板，或者干脆放弃那批文件。
- **证据**：zh-Hans `"evidence.safety.conditional" = "需确认";`（zh:1207）｜ en `"evidence.safety.conditional" = "Conditional";`（en:1188）。

#### P2-5. 语言设置里显示的值是硬编码中文，`language.*` 两个键零引用 【代码】· EPIC-14

- **位置**：Settings → 通用 → 界面语言 / `Packages/AtlasDomain/Sources/AtlasDomain/AtlasLocalization.swift:24-31`、strings `language.zhHans`（zh:2）
- **现象**：`AtlasLanguage.displayName` **硬编码返回中文**（`.zhHans → "简体中文"`，`.en → "English"`），完全绕过 `AtlasL10n`。界面语言为 English 时，设置行显示「Simplified Chinese」，分段控件的两个 tab 也是「简体中文 | English」。而 `language.zhHans` / `language.en` 两个键在两份 strings 里都有，**全仓库零引用**。
- **代价**：英文用户在这一行看到一半中文，第一反应是「汉化没做完」；更实质的是他无法确认当前生效语言是哪个——值和 tab 里都是「简体中文」字样。
- **证据**：`public var displayName: String { switch self { case .zhHans: return "简体中文" case .en: return "English" } }`（`AtlasLocalization.swift:24-31`）；`grep -rn 'language\.zhHans\|language\.en' --include='*.swift'` 零命中，键存在于 zh:2 / en:2。

### Smart Clean / File Organizer

#### P2-6. 回执把「预计释放」和实测数据并排成等权事实行 【代码】· EPIC-12

- **位置**：Smart Clean ④ 回执 fact rows / `SmartCleanReceiptView.swift:163-168`、strings `smartclean.receipt.estimated.label`（zh:1180）
- **现象**：成功回执的 mono 事实行是「执行项目 N 项」「预计释放 X」「完成时间」「扫描回执」，等权呈现；其中「预计释放」行由 `if receipt.estimatedFreedBytes > 0` 守卫（`SmartCleanReceiptView.swift:163`），即一个字面写「预计」的**估算值**与同组实测值（执行项数、完成时间）视觉权重完全相同。
- **代价**：用户执行完回桌面发现可用空间没涨那么多（缓存会重建），判定「这 App 骗人」。文案字面留了「预计」，但在同构的事实行里，用户不会区分哪行是实测、哪行是估算。
- **证据**：`label: AtlasL10n.string("smartclean.receipt.estimated.label"),`（`SmartCleanReceiptView.swift:165`）；zh-Hans `"smartclean.receipt.estimated.label" = "预计释放";`（zh:1180）。

#### P2-7. File Organizer ② 没有说明「不勾选的文件会怎样」 【代码】· EPIC-12

- **位置**：FO ② 规则 / `FileOrganizerStageViews.swift:168-189`，文案 `fileorganizer.selection.count`（zh:1003）
- **现象**：`selectionControls` 显示「已选 %d / %d 项」+「全选」/「取消全选」，主按钮相应变成「预演已选 N 项」。界面上**没有任何一句说明未选中文件的去向**。
- **代价**：用户取消勾选一个文件的动机是「这个不想被整理」，需要确认「不勾的会留在原地」。因为无法确认，他可能放弃取消勾选（于是本该保留的文件被移走），或者取消后反复去原目录检查文件还在不在。选择模型（选中 = 被移动）没有被显式表达。
- **证据**：`Text(AtlasL10n.string("fileorganizer.selection.count", selectedIDs.count, entries.count))`（`FileOrganizerStageViews.swift:170`）；zh-Hans `"fileorganizer.selection.count" = "已选 %d / %d 项";`（zh:1003）｜ `"fileorganizer.stage.actionbar.dryRun" = "预演已选 %d 项";`（zh:1075）。

#### P2-8. File Organizer 没有权限受限的界面态；扫描失败复用「文件整理未能完成」 【代码】· EPIC-11

- **位置**：FO ① 扫描 / `FileOrganizerStageViews.swift:48-53`
- **现象**：`planIssue` 非空时渲染 `AtlasErrorState(title: AtlasL10n.string("fileorganizer.status.executionFailed"), ...)`——标题用的是 **executionFailed**（「文件整理未能完成」，zh:988），而这是**扫描**阶段的失败。权限相关文案在 FO 包内零命中。
- **代价**：用户第一次扫描被系统隐私保护挡住时（见 P1-3），看到的是「文件整理未能完成」+ 一句 `planIssue`。他不知道该去「权限」页授权，只会反复重试或以为 App 坏了。而扫描是 FO 的第一个必经步骤——卡在这里等于整个模块不可用。
- **证据**：`title: AtlasL10n.string("fileorganizer.status.executionFailed"),`（`FileOrganizerStageViews.swift:50`）；zh-Hans `"fileorganizer.status.executionFailed" = "文件整理未能完成";`（zh:988）。
- **证据的作证方式（二次回源修正）**：本条**不以「FO 包内 `permission|权限` 零命中」作证**——该 zero-hit 单独不构成证据，因为对照组 SmartClean 包内**同样为 0**（那条文案住在 app 层，不在 feature 包）。真正的差异在**接线**：`fileOrganizerPlanIssue` 的全部赋值点只有 `nil` 与 `error.localizedDescription`（`AtlasAppModel.swift:1123/1128/1195/1215/1327`），**没有任何权限分支**；而 `smartCleanPlanIssue` 有一条权限分支（`:390`）。

#### P2-9. 「重复文件」徽章的判据只是同名同大小，且徽章没有任何对应动作 【代码】· EPIC-12

- **位置**：File Organizer ② 规则 → 条目 footnote 徽章 / `FileOrganizerStageViews.swift:285-291`、`FileOrganizerEvidenceBuilder.swift:285-288`
- **现象**：`duplicateFileIDs` 由 `Dictionary(grouping: entries, by: { FileNameBytesKey(name: $0.fileName, bytes: $0.bytes) })` 得出——**只比 name + bytes，不比对内容**。徽章只在 footnote 里追加两个字，列表按 `FileOrganizerCategory` 分组，没有任何按大小/重复筛选、排序或批量操作的入口。
- **代价**：用户看到「重复文件」徽章，直觉是「这些该处理掉」，但界面上无法把它们聚到一起，也无法区分「真重复」和「同名同大小的不同文件」——后者会被判为重复。徽章给了一个「值得行动」的信号却不给行动方式，用户只能手动在长列表里找，且可能误处理掉其实不同的文件。
- **证据**：`parts.append(AtlasL10n.string("fileorganizer.insight.duplicate.badge"))`（`FileOrganizerStageViews.swift:289`）；`Dictionary(grouping: entries, by: { FileNameBytesKey(name: $0.fileName, bytes: $0.bytes) })`（`FileOrganizerEvidenceBuilder.swift:286`）。

### Apps

#### P2-10. Apps 一进屏就自动选中了第一个应用，用户从没「选择」过 【实机】· EPIC-13

- **位置**：Apps → 每次进入 / `Packages/AtlasFeaturesApps/Sources/AtlasFeaturesApps/AppsFeatureView.swift:76`、`:350-352`
- **现象**：实机截图确认一进入 Apps 屏，Xcode 已被高亮选中，右侧证据面板已铺满它的足迹；而列表区块副标题写的是「从分组列表里**选择一个**应用，先检查占用，再生成卸载计划并决定是否执行。」代码上 `_selectedAppID = State(initialValue: initialSelectedAppID ?? Self.sortedApps(apps).first?.id)`，配合 `syncSelection` 的 `if selectedApp == nil { selectedAppID = sortedApps.first?.id }`。
- **代价**：与屏幕副标题的承诺不符。用户没选却已经看到「某一个 app 的卸载详情」，容易误以为这是全盘结论，或以为 Atlas 在推荐卸载它——对不懂技术的用户，「已经被选中」天然带推荐含义。
- **证据**：实机截图 `/tmp/atlas-11-apps.png`；`_selectedAppID = State(initialValue: initialSelectedAppID ?? Self.sortedApps(apps).first?.id)`（`AppsFeatureView.swift:76`）；`if selectedApp == nil { selectedAppID = sortedApps.first?.id }`（`:351`）。

#### P2-11. 恢复后刷新提示把两种不同口径的计数并排展示 【代码】· EPIC-13

- **位置**：Apps → 恢复后的证据卡 / strings `apps.restore.refresh.refreshed.detail`（zh:501 ｜ en:501）
- **现象**：文案「Atlas 在恢复 %@ 后已刷新应用清单。当前清单显示有 %2$d 个残留项目，而 Atlas 在记录卸载证据时保存的是 %3$d 个。」两个数字来自不同口径——记录侧 `recordedLeftoverItems` 取 `max(bestItemCount, payload.app.leftoverItems)`（`AtlasAppModel.swift:777,783`，**是同一函数内的相邻两行，同属记录侧一个口径**），当前侧 `refreshedLeftoverItems` 来自重新载入的清单（`:1526`）。
- **代价**：用户看到两个不一致的数字（如 12 vs 3），不知道它们不同口径，会以为「恢复后残留变多了 / Atlas 记错了」，从而不信任计数，或反复点「重新扫描残留」。
- **证据**：zh-Hans `"apps.restore.refresh.refreshed.detail" = "Atlas 在恢复 %@ 后已刷新应用清单。当前清单显示有 %2$d 个残留项目，而 Atlas 在记录卸载证据时保存的是 %3$d 个。"`（zh:501）｜ en:501；`let bestItemCount = snapshotItemCount ?? legacyItemCount`（`AtlasAppModel.swift:777`）；另一个口径 `refreshedLeftoverItems: refreshedApp.leftoverItems`（`:1526`）。

### Settings / About

#### P2-12. Settings 的「排除项」区域没有任何添加入口，用户只能看着空态 【代码】· EPIC-13

- **位置**：Settings → 恢复面板 → 规则与排除项 / `Packages/AtlasFeaturesSettings/Sources/AtlasFeaturesSettings/SettingsFeatureView.swift:193-211`
- **现象**：有数据时只做只读渲染（`ForEach(settings.excludedPaths)` → `AtlasDetailRow`，无删除/编辑按钮）；空态是 `AtlasEmptyState`「还没有配置排除项」。整个区块没有任何「添加排除路径」的按钮，视图的初始化参数里也没有排除项的写回调（只有 `onSetLanguage` / `onSetTheme` / `onSetRecoveryRetention` / `onToggleNotifications`）。实机确认当前 `excludedPaths` 已有 2 条（`~/Movies/Exports`、`~/Projects/ActiveClientWork`），走的是只读列表分支。
- **代价**：用户读到副标题「这些路径不会出现在扫描结果和清理计划里」，会想添加自己的重要目录——这是普通用户最本能的保护动作——却发现无处可点。
- **证据**：`ForEach(settings.excludedPaths, id: \.self) { path in AtlasDetailRow(...) }`（`SettingsFeatureView.swift:202-208`）；zh-Hans `"settings.exclusions.empty.detail" = "在后续迭代前，Atlas 会先使用默认覆盖范围进行扫描。";`（zh:714）。
- **未实机复核**：Settings 屏在审查期间无法用自动化抵达（见 P1-18），本条为代码 + 状态文件证据。

#### P2-13. About 首屏是作者履历与社交二维码，版本号不在这里 【实机】· EPIC-02

- **位置**：About → 首屏 / `Packages/AtlasFeaturesAbout/Sources/AtlasFeaturesAbout/AboutFeatureView.swift:14-49`
- **现象**：实机确认页面第一张卡是开发者卡（头像「Lizi KK」+「前百度 & 阿里技术负责人 · atomstorm.ai 创始人」+ 自我介绍），其下是**两张占满整屏**的二维码卡片（由 `SocialGrid()` 渲染——`:42` 调用、定义自 `:92`；开发者卡本体的范围是 `:14-40`）。`grep -n "version\|appVersion" AboutFeatureView.swift` 零命中——版本号在窗口右上角的工具栏胶囊里（`AboutUpdateToolbarButton.swift:44`），实机显示 `v2.0.0`。
- **代价**：用户点「关于」多半是想找版本号/更新，或确认「这软件靠不靠谱」。首屏被个人履历和二维码占满，他需要滚动才能看到产品信息；而「找版本要去右上角、点关于反而看不到版本」是非技术用户会卡住的常见动作。
- **证据**：实机截图 `/tmp/atlas-14-about.png`；`AtlasInfoCard(title: AtlasL10n.string("about.author.title"))`（`AboutFeatureView.swift:14`）；`Text(AtlasL10n.string("about.author.role"))`（`:29`）；zh-Hans `"about.author.role" = "前百度 & 阿里技术负责人 · atomstorm.ai 创始人";`（zh:755）。

### App Shell

#### P2-14. 任务中心固定只显示最近 5 条，从不说明被截断 【实机】· EPIC-14

- **位置**：App Shell → 任务中心 popover / `TaskCenterView.swift:47`
- **现象**：实机确认 popover 恰好渲染 5 行任务，而同一时刻状态文件里 `taskRuns = 147`。`ForEach(taskRuns.prefix(5))`，整个 popover 无滚动容器，也没有「还有 N 条」提示，底部只有「打开台账」。
- **代价**：用户看到正好 5 条会以为这就是全部。第 6 条起的历史在这个界面彻底不可见且无提示——他无法判断「是不是还有更多」。底部兜底按钮对不知道「台账＝完整任务历史」的用户无效。
- **证据**：实机截图 `/tmp/atlas-13-taskcenter.png`（5 行）；`ForEach(taskRuns.prefix(5)) { taskRun in`（`TaskCenterView.swift:47`）；zh-Hans `"taskcenter.openLedger" = "打开台账";`（zh:238）。

#### P2-15. 任务中心空态同时说「没有匹配」和「还没有」，还让用户去换搜索词——而这里没有搜索框 【代码】· EPIC-14

- **位置**：App Shell → 任务中心 popover → 空态 / `Apps/AtlasApp/Sources/AtlasApp/TaskCenterView.swift:29-44`
- **现象**：同一个 `taskRuns.isEmpty` 条件下同时渲染两个卡片：上方 `AtlasCallout` 标题「当前没有匹配的任务活动」（zh:230），下方 `AtlasEmptyState` 标题「还没有任务」（zh:234）；detail 又给出第三种说法「**试试新的搜索词**，或者运行一次智能清理扫描来填充任务时间线。」（zh:235）。`TaskCenterView.swift` 全文无 `searchable` / `searchText`。
- **代价**：「没有匹配」暗示存在过滤，「还没有任务」暗示从未跑过——用户无法判断自己到底是没搜到还是没跑过。而「试试新的搜索词」指向一个这个 popover 里根本不存在的控件，用户会去找它。
- **证据**：`title: taskRuns.isEmpty ? AtlasL10n.string("taskcenter.callout.empty.title") : ...`（`TaskCenterView.swift:30`）；`if taskRuns.isEmpty { AtlasEmptyState(title: AtlasL10n.string("taskcenter.empty.title"), detail: AtlasL10n.string("taskcenter.empty.detail"), ...) }`（`:38-44`）；zh-Hans 三条原文见 zh:230 / 234 / 235。
- **未实机复核**：当前状态有 147 条任务，空态不可达；以上为代码证据。

#### P2-16. 工具栏凭空出现一个 `#331B`，不可点、无解释入口 【实机】· EPIC-14

- **位置**：App Shell → 详情页工具栏「扫描回执 chip」 / `AppShellView.swift:575`、`:585`
- **现象**：实机确认工具栏右侧出现 `#331B`（形如 `#XXXX` 的十六进制串），唯一解释是一个 hover tooltip「当前模块最近一次扫描的回执编号」（zh:240）。chip 本身不可点、无点击展开。**补充**：chip 的显隐本身是正确的——无回执时整块不渲染（实机对照：同一会话刷新计划前工具栏无 chip，刷新后出现 `#331B`），符合 `Docs/IA.md` 的「hidden when no receipt exists」。
- **代价**：普通用户看到工具栏右上角凭空出现 `#331B`，既不认识也不理解要拿它做什么。tooltip 需要悬停（Mac 上非习惯动作），且解释本身仍是「回执编号」这个陌生概念。纯认知噪音，用户会怀疑是不是错误码。
- **证据**：实机截图 `/tmp/atlas-08-sc-updated.png`（有 chip，读数 `#331B`）与 `/tmp/atlas-07-smartclean.png`（无 chip）对照；`Text("#\(code)")`（`AppShellView.swift:575`）；`.help(AtlasL10n.string("toolbar.receipt.help"))`（`:585`）；zh-Hans `"toolbar.receipt.help" = "当前模块最近一次扫描的回执编号";`（zh:240）。

---

## 复核中被推翻 / 修订的结论

实机复核推翻了初次分析中的两条，记录在此以免后续重复提出：

### 已推翻：「promise 在窄窗口下退化成图标」

初次分析据 `AtlasActionBar.swift:72` 的 `contentWidth < AtlasLayout.actionBarCompactBreakpoint (740)` 推断窄窗口会让 `fileorganizer.promise.dryRun`（「预演不实际移动文件」）退化成图标，用户因而无法区分 ② 预演与 ③ 执行。

实机复核**不成立**：

- 窗口最小宽度被硬性钉在 **980**（`Apps/AtlasApp/Sources/AtlasApp/AtlasApp.swift:22` 的 `window.minSize = NSSize(width: 980, height: 640)`，配合 `.frame(minWidth: 980, minHeight: 640)`）。实测请求 800×600 被系统回弹为 `980, 678`。
- 在 980 宽度下抓的 action bar 高清裁剪显示 promise **完整渲染**：`⛨ 22/23 项可恢复 · 保留 7 天 · 全程录入台账`。
- 结论：`AtlasLayout.actionBarCompactBreakpoint = 740` 的 `.icon` 分支在运行时**不可达**，属死代码。这不是用户会遇到的摩擦，故不计入 finding。（可作为代码健康度备注保留。）

### 已修订：权限页的重启提示并未「埋在折叠区」

初次分析称「必须重启 Atlas」的提示只藏在 `permissions.evidence.toggle` 折叠面板深处。实机复核**推翻**该子论断——Permissions「下一步」卡片直接渲染了完整提示（见 P1-5 证据），无需展开任何折叠区。

因此原条目降级为 P1-6，只保留「跳转系统设置后无回执、无二次引导」这一部分（该部分代码证据成立）。

---

## 已跟踪、本次不重复报

- `ATL-271` — Ledger 导出不遵循筛选芯片。实机复核确认了成因：`saveReport()` 用的是 `filteredTaskRuns` / `filteredRecoveryItems`（仅受路由搜索词过滤，`AtlasSnapshotFilter.swift:58-68`），不含 `LedgerFilter` 芯片；而面板文案 `ledger.export.panel.detail`（zh:596）自称「把当前可见的台账条目导出」。**已在 Backlog 跟踪，不新增。**
- `ATL-272` — ledger rename 遗留的 6 个 `history.*` 孤儿键。已跟踪，跳过。

## 覆盖过但未发现问题的区域

避免重复劳动，以下为审查中确认无摩擦的部分：

- **Smart Clean**：阶段条不可点进未来阶段；回看只读 banner 文案诚实；重扫确认文案明确；失败回执不虚报释放量；证据面板空态有引导；抽屉可 Esc / 点外部 / 44pt 按钮关闭；promise 三态（full/partial/absent）fail-closed。
- **File Organizer**：规则删除有二次确认；缩略图加载失败有占位图标；「仅残留」筛选不清空选中。
- **Ledger**：恢复承诺 fail-closed（无真实可恢复项时不渲染信任声明）；导出写盘失败弹 NSAlert 不静默；过期项恢复按钮确实禁用；证据区路径不截断且可选中复制。
- **Permissions**：三段式证据文案完整，含具体系统设置路径（「系统设置 › 隐私与安全性 › 完全磁盘访问」）。
- **恢复窗口四态**（available / fileBacked / stateOnly / expiring / expired）在 zh 侧逐条区分了「能回磁盘」与「只在 Atlas 内恢复」——本批文案里做得最干净的一组。
- **文案对称性**：zh-Hans 与 en 各 1117 键，键集合完全一致；全部占位符零不对称。
- **快捷键**：⌘1–⌘6 与 ⌘7 实测生效；「关于 Atlas」在 appInfo 位置符合 macOS 惯例。

## 本次复核未覆盖的部分

- **Settings 屏**（P2-5 / P2-12）只能用代码 + 状态文件佐证：审查期间无法用自动化抵达（侧边栏行的合成点击只改变焦点不触发导航，且该路由无菜单/快捷键，见 P1-18）。
- **Smart Clean ③ 执行中 / ④ 回执**（P1-8 / P1-9）未实机复核：走到该阶段需要执行一次真实清理，属破坏性操作，审查期间未执行。
- **任务中心空态**（P2-15）：当前状态有 147 条任务，空态不可达。
- **File Organizer ③/⑤**（P1-13 / P1-14）：需要完成一次扫描→预演，扫描在 P1-3 的 TCC 弹窗处停止（未代答该系统授权）。

## 复核期间的环境副作用

- **未执行任何破坏性操作**：`findings` 23、`taskRuns` 147 均未变；`~/Organized` 不存在（文件整理一步未执行）；Smart Clean 只跑了只读的「更新计划」。
- app 自身正常持久化导致的唯一变化：过期恢复项被 prune（1 → 0，即 P1-16 的当场证据）+ 健康快照刷新。
- 原始状态文件备份在 `/tmp/atlas-workspace-state.backup.json`。**不建议还原**——被 prune 的那条恢复项指向两个月前就已过期的映射，还原只会制造一条点了没用的僵尸记录。
- `xcodegen generate` 未弄脏仓库（`Atlas.xcodeproj` 无改动）；构建产物在 `.build/atlas-native/`，未覆盖 `dist/native`。

## 审校记录（2026-09-14）

落盘后对本文档做了一次逐引用核验，不假设任何一条引用正确：

- 全量解析 **113 处** `文件:行号` 引用（去重 94 处），逐条比对所引行的实际内容
- 校验全部 strings key 在 zh-Hans / en 两侧的值与行号
- 校验全部 EPIC 编号在 `Docs/Backlog.md` 中有定义
- 校验每条 finding 的四项字段（位置 / 现象 / 代价 / 证据）齐全

### 更正 3 处

| # | 条目 | 原值 | 更正为 |
|---|------|------|--------|
| 1 | P1-13 证据 | `FileOrganizerStageViews.swift:284` | **`:282`** —— 284 行是 `var parts = [entry.proposedDestination]`，即非冲突分支。同一 key 亦渲染于 `FileOrganizerEvidenceBuilder.swift:245`，已补入 |
| 2 | P2-16 现象 / 代价 | 工具栏 chip 读数 `#5138` | **`#331B`** —— 原值由缩略截图误读，已按原始分辨率裁剪更正；同时补充 chip 显隐本身正确（无回执时整块不渲染） |
| 3 | P0-3 位置 | 未标目录的裸文件名 + 行号 746（无法唯一解析） | `zh-Hans.lproj/Localizable.strings:746`（补全目录，消除歧义） |

### 改写 1 处

- **P1-12**：「配置区默认收起」实为 `iterations/REQ-ui-ux-overhaul/requirement.md` P2-3 明确指定的既定设计且已作为 DONE 交付，原文把它当成问题上报，与「已完成的不再报」冲突。已改写为只针对两个残留点：折叠标题借用了 Smart Clean 的文案、折叠态不透出当前去向。

### 补充 1 处

- **P1-18** 补记它与 `REQ-ui-ux-overhaul` P1-3 的关系：该 REQ 把「⌘,: 打开 Settings」列为已完成项，而代码中不存在该绑定——本条属「标记 DONE 却未交付」，不是重复上报已完成项。

---

## 二次核验（2026-09-14 · 规格设计阶段回源）

独立于上一轮审校，规格设计阶段用**普通用户视角的实现规格**再做了一遍逐引用回源（抽验 44 处）。审计整体质量高，但仍有 **4 处引用不成立或只能部分支撑、1 处证据方式不成立、1 条漏报**。以下各项均已**就地更正正文**。

### 更正 4 处

| # | 条目 | 原值 | 更正为 |
|---|------|------|--------|
| 1 | P1-15 现象 | 两处 `return .archived` 在「**同一段 switch** 里」 | **不成立**——分属两个重载：`status(for run: TaskRun)` @ `LedgerTimelineView.swift:156`、`status(for item: RecoveryItem, now:)` @ `:167`。**问题实质仍成立**（「已归档」一词兼指两个状态），但措辞不可照抄 |
| 2 | P1-12 位置 | `FileOrganizerSupportViews.swift:227-238` | **`:227-239`**——`var body` @227 到闭括号 @239，原值漏掉末行。标题与 `defaultExpanded: false` 的相对位置（`:229-230`）原本就正确，未动 |
| 3 | P2-11 现象 | 「两个数字来自不同口径（`AtlasAppModel.swift:777,783`）」 | `:777`/`:783` 是**同一函数的两行**，只产出 `recordedLeftoverItems` 一个口径；另一口径 `refreshedLeftoverItems` 实际在 `:1526`。结论成立，**原引用只能支撑一半** |
| 4 | P2-13 现象 | About 首屏卡片由 `:14-49` 直接渲染 | **部分证实**——`:14-49` 内是开发者卡（本体 `:14-40`）；二维码卡在 `SocialGrid()`（`:42` 调用、定义自 `:92`） |

### 证据方式修正 1 处

- **P2-8**：原以「FO 包内 `permission|权限` 零命中」作证。**该 zero-hit 单独不构成证据**——对照组 SmartClean 包内**同样为 0**（那条文案住在 app 层，不在 feature 包）。已改用**接线对比**：`fileOrganizerPlanIssue` 的赋值点只有 `nil` 与 `error.localizedDescription`（`AtlasAppModel.swift:1123/1128/1195/1215/1327`），**无权限分支**；而 `smartCleanPlanIssue` 有一条（`:390`）。

### 补报 1 条：`NEW-1`

- **`NEW-1`**（已写入 P1 · Smart Clean 小节）：受限模式的**非阻断**软提示被渲染成 `AtlasErrorState` 的失败标题（`AtlasAppModel.swift:387-390` 赋值 → `SmartCleanStageViews.swift:45-50` 渲染）。
- **为什么上一轮没发现**：`P1-3` 把这句文案当作（相对 File Organizer 的）正面「铺垫」引用，评价了它「好在有」，但没回源它**挂在哪**。
- **教训**：审计的**评价性引用**（正面/负面）与被引用对象本身一样需要回源。「已被审计覆盖」不等于「已被审计看穿」。

### 回源确认无误

- 全部 EPIC 编号（02 / 07 / 11 / 12 / 13 / 14 / 15）在 `Docs/Backlog.md` 均有定义
- 「覆盖过但未发现问题」一节中可证伪的四条已回源确认：promise 三态 fail-closed（`SmartCleanEvidenceBuilder.swift:113-116` 的 `guard totalCount > 0, recoverableCount > 0 else { return nil }`）、阶段条不可点进未来阶段（同名文件 `:104-106` 的 `Set(0..<max(currentStage, effectiveStage))`）、规则删除有二次确认（`FileOrganizerRuleEditorView.swift:81-98` 的 `.alert` + `role: .destructive`）、`recordedLeftoverItems` 取 max（`AtlasAppModel.swift:783`）
- 实机读数类断言全部按原始分辨率复核，含 P1-3 的扫描进度 `10%`（`/tmp/atlas-06-fo-scan2.png`）与 P1-5 承诺原文 `22/23 项可恢复 · 保留 7 天 · 全程录入台账`
