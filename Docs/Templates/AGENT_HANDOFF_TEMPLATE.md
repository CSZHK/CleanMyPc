# Agent Handoff Template

委派有**两个方向**，不要混：

| 方向 | 谁写 | 权威定义 |
|---|---|---|
| **派单**（delegation） | 委派方 → 子代理 | `.claude/skills/iteration-governance/SKILL.md` 的「子代理委派模板」六项 |
| **回传**（handback） | 子代理 → 委派方 | 本模板；对应六项中的 `Handback Format` |

**本文档只承载「回传」方向，是指针不是副本。** 派单的六项（`Objective` / `Read Scope` / `Write Scope` / `Acceptance Slice` / `Stop Condition` / `Handback Format`）以 skill 为准，不要在这里重新定义 —— 否则下次协议演进时会二次分叉。

## 回传笔记（可复制）

```
### Objective
<委派时给定的 Objective；实际完成到什么程度>

### Acceptance Slice
<验收协议中的哪一片被验证了；未覆盖的部分显式列出>

### Write Scope（实际）
<实际写入了哪些路径；任何超出委派范围的写入必须在此说明>

### Stop Condition
<是否因某条停止条件而停下；是哪一条>

### Open Questions / Risks
<留给下一步的未决问题与已知风险>

### 建议的下一步
<接手者应立刻做什么>
```

## 旧五节 ↔ 现行位置

| 旧节 | 现状 |
|---|---|
| `Completed` | 拆入 `Objective` + `Acceptance Slice` |
| `Changed Artifacts` | 改名 `Write Scope（实际）` —— 强调它是**实际**写入，要与派单时给定的范围对账 |
| `Open Questions` | 保留 |
| `Risks and Blockers` | 保留 |
| `Recommended Next Step` | 改名「建议的下一步」 |

## Retro 提案（可选）

仅当命中 `.claude/skills/iteration-governance/SKILL.md` 的 T1–T4 触发条件时才写；未命中写「无」。

- 触发条件编号（T1 被控制器打回 / T2 Stop Condition 触发 / T3 同类失败第二次 / T4 既有约束不够）
- **事件发生日期**（`YYYY-MM-DD`）
- 现象 + `文件:行号` 证据
- 建议改动：改哪份文件的哪一节
- **是否改变任何约束**（加/减工具、扩/收 Write Scope、增/删 Stop Condition、改 `model:`）—— 任一项都标「需人审」
