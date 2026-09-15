# Gate Review Template

归档位置：`Docs/Execution/<主题>-Gate-Review-<YYYY-MM-DD>.md`（`Beta-Gate-Review.md` 是早期遗留，无日期后缀）。

本模板有 **必需核心**（5 节）+ **两组二选一的扩展**。两组不是任选装饰，而是两种评审形态 —— 先选形态，再按该组补齐。

| 节 | 6 份实文件中的出现次数 |
|---|---|
| `Gate` / `Readiness Checklist` / `Evidence Reviewed` / `Decision` / `Follow-up Actions` | 6 / 6 —— **必需** |
| `Blockers` | 4 / 6 —— 形态 A 必需，形态 B 可选 |
| `What Changed` | 3 / 6 —— 形态 A |
| `Review Date` / `Scope Reviewed` / `Automated Validation Summary` / `<X> Assessment` / `Conditions` | 3 / 6 —— 形态 B |
| `Remaining Limits` | 2 / 6 —— 形态 B 内可选 |

> 2026-09-14 校正：本模板此前停留在 `Week 1/2/3` 档位，而全部实文件在 EPIC 化后已改填 EPIC/ATL 编号或主题名，且新增了多个节 —— 模板从未回写。现按实际用法重写，上表由 6 份实文件逐节统计得来。

---

## 必需核心

### Gate

被门对象的标识。两种形态二选一：

- **Slice 门** —— EPIC 编号 + 覆盖的 ATL 清单：
  - `EPIC-A` / `ATL-251` / `ATL-252` / `ATL-253` / `ATL-254` / `ATL-255`
  - 部分覆盖时标注，例：`EPIC-B` / `ATL-256` / `ATL-258` / partial `ATL-259`
- **主题门** —— 主题名，例：`Recovery Credibility` / `Smart Clean Execution Credibility` / `Beta Candidate`

> `Week 1` / `Week 2` / `Week 3` / `Feature Complete` 已废弃 —— EPIC 化后不再使用，仅 `Beta Candidate` 仍是有效主题名。

### Readiness Checklist

- [ ] Slice 门：改写为「Required `<EPIC-x>` implementation slice is complete in repo」；主题门：「Required P0 tasks complete」
- [ ] Docs updated
- [ ] Risks reviewed
- [ ] Open questions are bounded
- [ ] Next-stage inputs are available

### Evidence Reviewed

列出门所依据的证据：测试计数、脚本、产物、审查记录。每条附可得证的出处。

### Decision

- `Pass`
- `Pass with Conditions`
- `Fail`

### Follow-up Actions

---

## 扩展 A — Slice Review（EPIC/ATL 落地门）

用于单个 epic / slice 的落地门。实文件：`Apps-Evidence-`、`Smart-Clean-Safe-Coverage-`、`Smart-Clean-Boundary-Metadata-Gate-Review-2026-03-24.md`。

### What Changed

本次 slice 实际改了什么。

### Blockers

区分两类：**本 slice 的阻塞**，与**属于其他轨道的阻塞**（例：签名材料缺失属 release 轨，不是 slice 的产品路径阻塞）。不要混为一谈。

---

## 扩展 B — Credibility Gate（对用户承诺的核查门）

用于核查对外承诺是否站得住。实文件：`Beta-`、`Execution-Credibility-2026-03-12`、`Recovery-Credibility-2026-03-13.md`。

### Review Date

- `YYYY-MM-DD`

### Scope Reviewed

逐条列出被核查的 ATL 及其标题。

### Automated Validation Summary

自动化门禁的实测数字（测试计数 / 对比度 / 构建 verdict）。

### `<X>` Assessment

**节名随主题走** —— 实文件用的是 `## Gate Assessment`（Execution-Credibility / Recovery-Credibility）与 `## Beta Assessment`（Beta）。不存在字面的 `## Assessment` 节。

按 ATL 逐条分节，每条给「做了什么 + 证据」：

```
### ATL-221 Physical Restore Surface
- <结论>
- <证据>
```

主题门（非 ATL 驱动）时按主题分节，例 `### Truthfulness Check`。

### Remaining Limits

仍未覆盖或仍未证实的边界（实文件中仅 Execution-Credibility 与 Recovery-Credibility 用了本节）。

**建议**：当核查发现「证据不足以支撑承诺」时保留本节 —— 它和 `Conditions` 一起构成诚实降级。此为本模板的建议，非既有实文件的一致做法。

### Conditions

**仅当** `Decision` = `Pass with Conditions` 时出现。写清放行的前提条件。

### Blockers（形态 B 可选）

形态 B 中仅 `Beta-Gate-Review.md` 用了本节。核查对象横跨多个轨道时建议保留 —— 用来把「本门的阻塞」与「属于其他轨道的阻塞」分开。
