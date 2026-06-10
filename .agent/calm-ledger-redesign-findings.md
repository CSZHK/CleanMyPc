# Findings 索引
- 4 agent 评审结论已合入规格 v1.1（commit 26c6776）；原始评审全文见会话记录，关键结论：路由无持久化（改名为编译期清单）、zh serif 需显式 Songti cascade、语义色对比度定稿值已重算、EPIC-D 中断协议落入 §0.3。
- M1 实测待办: 宋体 cascade 观感（降级决策点）、№ U+2116 在 New York 的字形覆盖。
- M3 使用约束（评审实测）: 浅色模式下 AtlasTextTertiary 直接置于 AtlasCanvasTop 仅 4.41:1（<AA）——三级文字不得直接放在画布顶区，必须落在 surface/surfaceSubdued 上；门禁绿不等于「任意文字×任意表面」安全。
