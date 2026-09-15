# Wave 0 — 契约四术语基线与签字

## Objective
产出 zh/en 双语术语基线（范围 = 全规格涉及的全部新词与拆词），交产品负责人签字。**决策，无代码。**

## 前置
—

## Deliverables
- `iterations/REQ-ux-friction-remediation/terminology-baseline.md` —— 19 条核心术语（T-01..T-19）+ 10 条拆词/改词（S-1..S-10）+ 10 条新词（N-1..N-10）+ 落点对齐清单（4-A，8 条）+ 开放项（R-1..R-6）
- 本文 + `requirement.md` 的 `## Contract Unfreeze Record`

## 硬门禁
- **产出后停止**，交产品负责人签字；**签字前不得改任何 P0 文案**（`apps.confirm.uninstall.message` / `fileorganizer.confirm.execute.message` / `smartclean.confirm.execute.message`）
- **范围不足即失败**：若 Wave 2 的 P1 改词（`P1-4` `P1-13` `P1-15`）在本文中无词可用，实现者会就地自造词——**那就绕过了本契约的 CONTRACT 签字**（§9 Wave 0 行的明文理由）

## Verify
- 逐条回源：本文每条结论的 `文件:行号` 或 strings key 与实际一致
- 计数：T=19 / S=10 / N=10 / 4-A=8 / R=6，与 §4.1 的 8 条 finding（`P1-4` `P1-13` `P1-15` `P2-1` `P2-2` `P2-3` `P2-4` `P2-5`）全覆盖、零遗漏
- `terminology-baseline.md` 占位符 0

## 签名
- [ ] 产品负责人：`Wave 0 术语基线通过，准予开 Wave 1`（含 §5 D-012 显式确认与 R-1–R-6 逐项裁决）
