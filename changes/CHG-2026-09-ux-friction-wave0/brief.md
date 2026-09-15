# CHG-2026-09-ux-friction-wave0

- REQ: REQ-ux-friction-remediation
- Task: wave0-terminology
- Scope: 契约四术语基线**定稿**（决策，**无代码**）+ REQ/CHG 追溯包
- Canonical Plan: `Docs/design/2026-09-14-ux-friction-remediation.md` §9 Wave 0 行 + §4 契约四
- Note: 本 CHG **不产出代码**。产出物是 `terminology-baseline.md`（T/S/N/4-A/R 五组）与追溯包骨架。**收口前置 = 产品负责人签字**；签字前不得改任何 P0 文案、不得开工 Wave 1。

## 为什么单独成一个 CHG

§9 波次纪律第 2 条：**Wave 0 只产出决策，不产出代码**。契约四的实现分布在 Wave 1（P0 所需）与 Wave 3（P2 层）。若把 Wave 0 并入 Wave 1，签字点会被混进代码变更里，无法单独拦住。

## 与门禁的关系

本 CHG 无代码改动 → 三条门禁命令**无增量可验**。可脚本化的校验只有维度闭合复算与逐条回源，见 `verify.md`。
