# P4 —— 文档与治理产物

- **状态**：完成
- **产出**：`Docs/design/2026-09-15-readme-media-lifecycle.md` · 本 REQ 包 · `changes/CHG-2026-09-readme-media-lifecycle/` · `AGENTS.md`

## 文档落点（按 `iteration-governance`「真相存放地」）

| 内容 | 位置 | 权威性 |
|---|---|---|
| 长期产品真相 | `Docs/design/2026-09-15-readme-media-lifecycle.md` | 规范真相源 |
| 需求级长期追溯 | `iterations/REQ-readme-media-lifecycle/` | 规范真相源 |
| 单次执行 | `changes/CHG-2026-09-readme-media-lifecycle/` | 规范真相源 |
| 工作草稿 | `.agent/` | 临时 |
| 工具用法速查 | `AGENTS.md`「README 媒体门禁」段 | 工具无关层 |

## 分层边界遵守

按 `iteration-governance` §「分层边界」：工具无关内容只落 `AGENTS.md`，Claude 专属内容只落 `CLAUDE.md`。本次只写 `AGENTS.md`，未在 `CLAUDE.md` 双写。

## `AGENTS.md` 的写法取舍

写「判据源是设计文档」而非复制六维定义 —— `AGENTS.md` 是速查与易踩点，权威定义在 `Docs/design/`。同时显式写明三件容易踩的事：

1. **改任何一条文案都会报红直到重导** —— 说清楚这是设计要求不是缺陷，否则下一个人会去「修」它。
2. **退出码 2 = 不是通过** —— 沿用文案门禁那条已被两次教训钉下的规矩。
3. **改门禁规则后必须重跑变异自检** —— 否则规则演化后没人知道守卫还活着没有。
