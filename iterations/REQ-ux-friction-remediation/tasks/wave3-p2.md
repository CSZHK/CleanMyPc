# Wave 3（P2）—— 契约五余项 + 契约六余项 + 契约四余项

## Objective
按规格 §9 Wave 3 行交付 P2 层收口，含术语表回写与产品内术语入口。

## 范围（§9）
- **契约五余项（P2 层）**：`P2-6` `P2-7` `P2-10` `P2-11` `P2-13` `P2-14` `P2-15` `P2-16`
- **契约六余项**：`P2-9`（重复文件徽章）· `P2-12`（Settings 排除项添加入口）
- **契约四余项**：P2 层改词 + **双语术语表回写 `Docs/COPY_GUIDELINES.md` §Glossary** + **产品内术语入口**

## 硬门禁
- `P2-12` 需新增写回调并接入 `AtlasAppModel`（非 CONTRACT，但触模型公开 API，须同步调用点与测试 fixture）
- `P2-9` 按规格 §6.2(4) **推荐案**（诚实改名「同名同大小」+ 筛选/聚合入口）；**真·内容比对不采纳**（附录 B）

## 本波覆盖的不变量
| # | 不变量 | 守卫载体 | 备注 |
|---|---|---|---|
| I-9 | 被截断的列表必须同屏说明截断 | `AtlasAppUITests` | `taskRuns.count > 5` 时断言存在「还有 N 条」 |
| I-10 | 估算值与实测值不得在同一事实组内等权渲染 | `AtlasAppUITests` | 估算值须渲染在**带稳定 `accessibilityIdentifier` 的独立分组容器**内 —— **该标识属契约五 §5.2 第 3 条的交付物，不是实现细节** |
| I-12 | 徽章/标签须有对应动作，或明确说明其只是分类 | `AtlasAppUITests` + strings 断言 | 与 Wave 1 的 I-12 部分合并收口 |

## 交付物：术语入口（§4.2(2)，只回写文档不算达标）
- `Docs/COPY_GUIDELINES.md` §Glossary 扩为 **zh/en 双语**
- 产品内**可读入口**：首次遇见解释 + 可查术语表
- 四个体系词（残留/足迹/台账/证据）**保留** + 补解释（解释文字见 `terminology-baseline.md` §S-10，**不得自造**）

## Verify（三条缺一不可）
```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/run-ui-automation.sh
```
外加：L10n 键 parity（zh/en 键集合一致、占位符零不对称）—— 委派 `l10n-parity`。

## Stop Condition
- 命中 `UC / INV / CONTRACT / infra` → 停下来升级给人
- 守卫基座缺失 → 该不变量记 `NOT RUN`，不得报 `Pass`
