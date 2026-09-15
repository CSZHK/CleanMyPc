# Issue #8: 上游一个红步骤会永久掩盖它后面的一切

**修复日期**: 2026-09-15
**类别**: 其他（构建/CI）
**关联模块**: `.github/workflows/atlas-acceptance.yml` · `scripts/atlas/full-acceptance.sh`
**严重等级**: P1（已上线的门禁实际处于未生效状态，且无人察觉）

---

## 问题本质 (≤3行)
新接入的 README 媒体门禁（第 [5/13] 步）**在 CI 上从未执行过**，却无人知晓。
触发条件：第 [1/13] 步先失败，`set -e` 使后续步骤一律不执行 —— 管线红，但红在第 1 步。

## 根因分析 (≤5行)
`atlas-acceptance.yml` 自建成起**从未成功过**（20+ 次全 failure，全部停在第 [1/13] 步），所以第 5 步之后的一切都没人见过。
修掉第 1 层后立刻露出第 2 层：`AtlasAppModel.swift:371` 在 CI 的 toolchain（构建目标 `macos14.0`）上
触发 `error: the compiler is unable to type-check this expression in reasonable time`，
而本地（Swift 6.2.4 / `macosx15.0`）清缓存重建 10s 即过 —— 换 toolchain 才复现。
**两层都不是新引入的，只是被上游的红挡住了。**

## 解决方案 (≤5行)
逐层拆开：`b8b3e36` 按编译器建议拆表达式 —— 显式标注闭包签名 + 把重复的时间偏移提为 `startedAt` 局部量（语义逐字等价，7 个 index 实测比对确认）。
- 关键代码: `AtlasAppModel.swift:364-379`
- 结果：`#34984224153` 全 13 步通过，`ATLAS_README_MEDIA_GATE=PASS` —— 该 workflow 的**首次成功**

## 关键决策 (≤3行)
CI-only 的失败**本地无法复现时，不要靠「我本地是过的」结案**，要按编译器/工具给出的建议做**保守等价改写**。
改的是「让类型推断便宜」而非「改语义」—— 所以能安心把等价性用独立脚本验证，而不是靠 CI 兜。

## 预防措施 (≤2行)
**接入新门禁前先查该 workflow 的历史状态**：一个红的 CI 与一个不存在的 CI，在「有没有在保护你」这件事上等价。
判据是 `gh run list --workflow=<name>` 的结论分布，不是「文件里写了这一步」。

---
**相关链接**: 提交 `b8b3e36` · 首次成功运行 `#34984224153` · `AGENTS.md` 的 README 媒体门禁节
