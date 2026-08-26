# O1 工具页上线分发计划（O1.3 准备）

> 目标：让「Mac 可回收空间估算器」/zh/tools/mac-space-calculator（+ /en）靠自重 + 分发攒到 **≥1 个编辑型（非目录）referring domain**。研究结论：链接**不是被动来**（Ahrefs 自家 36 编辑链 27 条来自 515 封邮件），必须配分发；编辑器最引的是「反直觉发现 + 一个落进趋势的数字」。

## 前提（先完成）
1. 合并 PR #2 → main → GitHub Pages 发布（`Apps/LandingSite/` 部署）。
2. 确认页面可访问 + sitemap 收录（build 已确认 5 页）；canonical 已规范（分享 URL 不重复）。
3. 重跑 `geo-refresh` 拿上线前基线（当前 0%）。

## 渠道与序列（按 ROI / 可自助度排序）

| 期 | 渠道 | 动作 | 期望 |
|---|---|---|---|
| 第 0 天 | **GH Releases / README** | 在 CleanMyPc Release Body + README 加工具页链接（自带） | 工具页自链、被 app 用户看到 |
| 第 0–3 天 | **Product Hunt** | 以「Atlas + 免费空间计算器」提交 launch | 曝光 + 引荐流量 + 可能被编辑收进 |
| 第 3–7 天 | **/r/mac、/r/macapps、/r/selfhosted** | 发「发现：Mac 空间真凶计算器（开源 Atlas）」帖 | 社区引用/书签 |
| 第 3–7 天 | **HN Show** | `Show HN: Atlas – explainable Mac cleaner + space calculator` | 开发者关注 |
| 第 7–14 天 | **Mac 垂类博客 pitch**（编辑型） | 给 Mac 周报/工具站编辑发 pitch：提供数据角度 | **≥1 编辑型链接（KR 目标）** |
| 持续 | **应用目录收录** | Feedback/AlternativeTo/MacUpdate/Setapp 列表 | 权威外链 |

## 编辑型 pitch 草稿（<150 字，首行个性化，只催一次）
**hook 用"发现"开头，不是"我们公司"**：
> "Found: the median Mac holds ~X GB of reclaimable caches/logs — and most owners never clear it. We built Atlas (open-source, recovery-first) and a free calculator so users can estimate before acting. Happy to share the methodology + a data angle for your [Mac] roundup."

## 数据角度备选（喂编辑型引用；需 >50K 扫描后再披露）
- "平均每台 Mac 藏多少隐形垃圾"（CleanMyMac 已用 1M 用户包走，须换新角度）
- 新角度候选：M 系 vs Intel 垃圾差值、某 macOS 版本/某 app 膨胀增长、实测启动开销、"哪些 app 真拖慢 Mac"

## 口径
- "预估"非"实测"（页上已注明）；真实扫描数 app 侧积累到 >50K 才发"数据研究"，否则只发"计算器 + 方法框"。
- 不为拿链接编造数据；编辑型链接靠真实方法框 + 分享结果（页已内置 URL 分享）。
