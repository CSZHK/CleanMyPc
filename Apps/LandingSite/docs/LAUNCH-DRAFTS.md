# Launch drafts（Day 3-7 渠道物料 · 只起草不代发）

> 配套 `TOOL-LAUNCH-PLAN.md`。发帖动作需你的浏览器身份/账号，本文件只备料。
> 通用纪律：首句是「发现」不是「我们公司」；只投一轮，不刷；被质疑时引用方法论页而不是辩解。

## Show HN（Day 3-7）

**Title**: `Show HN: Atlas – explainable, recovery-first Mac cleaner`
（副带工具：正文里给 https://atlas.atomstorm.ai/en/tools/mac-space-calculator/ ，标题不塞工具——HN 对 landing 页工具更敏感，产品本体更有讨论纵深）

**First comment 模板**：

> Hi HN! We're a tiny team behind Atlas, an open-source macOS maintenance tool. Most cleaners do things silently; we built the opposite: scan → plan you approve → ledger with restore points → restore anything during retention.
>
> The interesting technical bit: everything is explainable. Each action shows evidence (which files, why they're reclaimable, size bands) before you confirm, and creates a numbered receipt you can undo from.
>
> Alongside it we shipped a free web estimator (no signup): answer 4 questions to get an estimate of reclaimable space before installing anything — <link>. It's explicitly an *estimate*; methodology and sample limits are on the page.
>
> From our early scan data one counterintuitive finding: most "junk" on dev machines isn't junk from apps — it's Xcode/simulator caches (~85% of reclaimable space on ours). Curious what your machines look like.
>
> MIT licensed: <repo link>. Ask us anything.

要点：①以可恢复性为技术钩子(HN 吃架构叙事)；②估算器只在正文出现；③结尾抛反直觉数据引讨论。

## Reddit /r/macapps（Day 3-7）

**Title**: `Found while building our cleaner: ~85% of reclaimable space on a dev MacBook was Xcode caches — made a free calculator to estimate yours`

**Body 草稿**:

> Not selling anything here — the calculator is free and has no signup: <link>
>
> Context: we build Atlas (open-source, recovery-first Mac maintenance). While dogfooding we scanned a M-series dev machine: 35.3 GB reclaimable, of which Xcode + simulators ≈ 30 GB. Most people never touch these because Apple buries them.
>
> So we made a no-signup web calculator: answer 4 questions → estimated reclaimable range. It's an estimate (methodology + limits stated on-page); for a real scan there's always Atlas, but the calculator works standalone.
>
> Happy to answer questions about what's actually safe to delete on dev machines.

要点：r/macapps 自我推销规则严格，免注册+开源+不卖东西这三点要显式说；数据做钩子。

## Product Hunt(Day 0-3,需准备)

前置：maker 账号有 PH 历史(新号首发易被压)；产品名用 **Atlas**(主品)，tagline 一句话里带 free space calculator;gallery 至少 1 张 1270×760;first comment 用 HN 版删减到 150 词。ph 频道对「双语」敏感可放 second link。
提交后：请求既有用户(TinyLaunch #19513 留下的联系渠道)当天 upvote,前 4 小时动量关键。

## 垂类编辑 pitch（Day 7-14,KR 目标）— 直接复用 TOOL-LAUNCH-PLAN.md §pitch

首行个性化变量:`[Mac] roundup` / `[yearly] state-of-mac-tools` 等，逐刊改第一句。附方法框链接(估算器页)而非首页。

## 口径提醒(从 OKR/plan 继承)

- 不为拿链编数据;≥1 编辑型 RD 才算 O1.3 达成，目录/自链不算数
- 数据角度(M 系 vs Intel 差值等)留到 >50K 扫描后再对外披露
