# AGENTS.md

Atlas for Mac — 原生 macOS 维护工作区（explainable, recovery-first）。

## 构建与运行

本仓库有 5 个独立 SPM 根包（`Apps` / `Packages` / `XPC` / `Helpers` / `Testing`），Swift 命令必须带 `--package-path`，否则从仓库根跑不起来：

```bash
swift run --package-path Apps AtlasApp                        # 直接跑 App
swift test --package-path Packages                            # 共享库测试
swift test --package-path Apps                                # App 层测试
swift test --package-path Packages --filter AtlasDomainTests  # 单个测试
make                                                          # Go analyze/status 二进制
xcodegen generate && open Atlas.xcodeproj                     # 生成 Xcode 工程
./scripts/atlas/build-native.sh                               # 构建 .app bundle
./scripts/atlas/package-native.sh                             # 打 .zip / .dmg / .pkg
```

**测试边界（易踩）**：`./scripts/test.sh` 只跑遗留 Mole 的 shell/Go 套件（shellcheck + bats + go test + 安装测试），**不含任何 Swift 覆盖**。Swift 改动只能靠 `swift test` 验证，不要拿 `test.sh` 当代替。

**文案门禁**：改 `Localizable.strings` 后跑 `./scripts/atlas/copy-gate.sh`（已接入 `full-acceptance.sh` 第 [4/12] 步）。判据源是 `Docs/COPY_GUIDELINES.md`，**不是**建议。十条规则里八条阻断（C1 术语禁用表 / C2 副标题超宽 / C3 副标题规格句式 / C4 术语映射不一致 / C6 占位符对称 / C7 键集合 parity / C9 Swift 字面量残留 / C10 解析完整性），两条只报告（C5 孤儿键归 `ATL-272` / C8 长句）——清单以 `copy_gate.py` 的 `BLOCKING` / `REPORTED` 常量为准。**退出码 2 = 文案源缺失，不是通过。**

**UI 门禁（易踩）**：`./scripts/atlas/run-ui-automation.sh` 在 AX 未授权时**仍** `exit 0`（退出码本身看不出跳过），但现在会同时发出**机器可读哨兵** `ATLAS_UI_GATE=NOT_RUN`；`full-acceptance.sh` 只认哨兵、**不认那句人类可读英文**（匹配文案的话，改一个词就会静默退回假绿）。

零 UI 覆盖有**三条**路径，一律先于「是否通过」判定，默认**全部判失败**：

| 路径 | 哨兵 | 可否用 `ATLAS_ALLOW_UI_SKIP=1` 豁免 |
|---|---|---|
| AX 未授权（preflight 跳过） | `ATLAS_UI_GATE=NOT_RUN` | ✅ 可 |
| atlas 与独立 repro **双双 timeout** | —（凭 log 判据） | ✅ 可 |
| **`xcodebuild` 收集到 0 个用例却返回 0** | `ATLAS_UI_GATE=ZERO_TESTS` | ❌ **不可**（这是配置缺陷，不是环境限制） |

失败时 log 分别留存在 `${TMPDIR}/atlas-ui-automation-{NOT-RUN,BLOCKED,ZERO-TESTS}.log`。裁定原文见 `Docs/design/2026-09-14-ux-friction-remediation.md` §9；加固过程见 `changes/CHG-2026-09-ux-friction-review-remediation/`。

> ⚠️ **CI 影响（易踩，已裁定）**：`.github/workflows/atlas-acceptance.yml` 直接跑 `full-acceptance.sh`，而 GitHub 托管 runner 没有 Accessibility 授权 ⇒ 必然走跳过路径 ⇒ 第 [10/12] 步失败 ⇒ **job 红**。
>
> **裁定（2026-09-15）**：该 workflow 的 acceptance 步骤已设 `env: ATLAS_ALLOW_UI_SKIP: "1"`，CI 因此在「本机无 AX」这一条上放行。
>
> **关键区分**（别把它当万能开关）：该变量**只**豁免两条**环境限制**路径（AX 未授权 / atlas 与 repro 双 timeout）。它**不**豁免「`xcodebuild` 收集到 0 个用例」——那是配置缺陷，**CI 里照样红**。即：CI 接受「这台 runner 没有 AX」，不接受「UI 用例根本没跑起来」。
>
> **本地与发版候选机不要设它** —— 那里有 AX 授权，UI 层断言应当真实执行。

另两点：`swift test` **跑不到 XCUITest**（需 `xcodebuild test`，该脚本已封装 `-only-testing:AtlasAppUITests`）；各包内的 `*FeatureViewTests` 只断言 view 的初始属性，**无渲染断言能力**——能对渲染结果下断言的只有 `Apps/AtlasAppUITests`。

**两套语言模式**：SPM 清单是 `swift-tools-version: 5.10`，而 `project.yml` 里 `SWIFT_VERSION: 6.0`。也就是说 `swift test` 与 Xcode/xcodegen 构建走的是不同的语言模式（后者严格并发）。两边都要能编过才算改完。

## 约定

- **本地化**：默认 `zh-Hans`。新增文案须同时改 `en.lproj` 与 `zh-Hans.lproj` 两份 `Localizable.strings`（在 `Packages/AtlasDomain/Sources/AtlasDomain/Resources/`），经 `AtlasL10n` 访问。
- **XcodeGen**：改动 `project.yml` 后必须重跑 `xcodegen generate`，否则 Xcode 工程与包定义脱节。
- **Landing site**：`Apps/LandingSite/` 是独立 Astro 站点，自带 `package.json` / `pnpm-lock.yaml`，与 Swift 应用工具链互不相干，用 pnpm 命令操作。
- **设计系统**：共享 token 与组件在 `Packages/AtlasDesignSystem`（`AtlasColor` / `AtlasTypography` / `AtlasSpacing` / `AtlasRadius`）；视觉规格以 `Docs/DESIGN_SPEC.md` 为准。

## 环境变量

- `ATLAS_PREFER_XPC_WORKER=1` — 走 XPC worker 而非直接 worker
- `ATLAS_EXPORT_README_ASSETS_DIR` — 导出 README 截图的目标目录

## Attribution

部分构建于开源 Mole 项目（MIT）。发版涉及上游派生代码时，同步更新 `Docs/ATTRIBUTION.md` 与 `Docs/THIRD_PARTY_NOTICES.md`。
