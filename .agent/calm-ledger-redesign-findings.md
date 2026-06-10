# Findings 索引
- 4 agent 评审结论已合入规格 v1.1（commit 26c6776）；原始评审全文见会话记录，关键结论：路由无持久化（改名为编译期清单）、zh serif 需显式 Songti cascade、语义色对比度定稿值已重算、EPIC-D 中断协议落入 §0.3。
- M1 实测待办: 宋体 cascade 观感（降级决策点）、№ U+2116 在 New York 的字形覆盖。
- M3 使用约束（评审实测）: 浅色模式下 AtlasTextTertiary 直接置于 AtlasCanvasTop 仅 4.41:1（<AA）——三级文字不得直接放在画布顶区，必须落在 surface/surfaceSubdued 上；门禁绿不等于「任意文字×任意表面」安全。
- M1 实测结论: 宋体 cascade 解析 family=Songti SC ✓（无需降级方案）；№ U+2116 在 New York 可用（glyphID 1710）✓。注意：cascade descriptor 不带 weight，中文解析为 Songti Regular——M2 若需粗宋体台账标题，给 cascade 追加 face/traits。
- 连带发现（需 M2 计划决策）: SwiftPM CLI 不对 .xcassets 跑 actool——`swift run --package-path Apps AtlasApp` 开发路径下全部 32 个 colorset 运行时解析 nil（v2 时代已对 Brand/Accent 两色潜伏，发布路径 build-native.sh/xcodebuild 不受影响）。候选方案：生成器从同一 manifest 额外产出 Swift 回退色表（保持单一真相源）/ dev 路径改走 xcodebuild。colorset 守卫测试已适配双分支（编译目录命中 或 原始 payload 存在）。
- 遗留（不入本 REQ，建议单独 CHG）: Apps 测试目标 pre-existing 编译失败——AtlasAppModelTests.swift:1088/1103 的 E2E 测试替身缺 `scanFolders(_:destinationBasePath:recursive:)` 签名（协议 AtlasApplication.swift:752），先于本分支存在（父 commit 9093995 可复现）。REQ acceptance 含「Apps 29 测试」，且 trace 的 M3 验证行已要求 `swift test --package-path Apps`——**M3 验收前必须修**（建议排入 M2 窗口的独立小 CHG）。
- M2/M3 计划必须包含的规格遗项（token 层无法表达）: ① `screenTitle` tracking −0.3 是 Text modifier 层能力，落在 M2 AtlasScreen 标题槽；② 字号钳制上限（screenTitle 34 / dataHero 48 / dataMetric 30 / ledgerTitle 24）在 M2/M3 组件与屏幕层实现；③ bannerGradient 实际角度需 M2 AtlasNextActionBanner 显式决策（规格写 135°，topLeading→bottomTrailing 仅在方形帧下等于 135°，宽横幅会更平缓——接受对角线或用 UnitPoint 计算，二选一写进组件）。
