#!/usr/bin/env bash
# README 媒体门禁 —— 变异自检。
#
# 为什么需要它
# ------------
# 迭代治理「门禁卫生规则」第三条：**新增守卫必须做变异检验**。守卫「跑一遍是绿的」
# 不构成验证 —— 必须先把它该抓的东西改坏，确认它**真的变红**，再恢复确认回绿。
#
# 本仓两次栽在同一处（`REQ-ux-friction-remediation` 4 条空转守卫、
# `REQ-copy-plain-language` 覆盖面残缺），所以这条不是形式。
#
# 为什么在**临时副本**上做，而不是就地改
# --------------------------------------
# 第一版是就地改写工作树（备份 → 改 → 还原）。它有两个真实缺陷，实测都撞上了：
#
#   1. **不能并发** —— 变异注入在盘上是可见的。任何并发读（跑一次门禁、另一个
#      自检实例、编辑器索引）都会读到半途状态。实测中它与我派出的对抗审查子代理
#      互相踩，双方都读到对方注入的 `selftest.drift.probe` / `DOES-NOT-EXIST`。
#   2. **中途被杀就留脏树** —— 变异残留会伪装成「真的坏了」，污染后续取证。
#
# 改为：把门禁需要读的那部分（指纹范围解析出的全部源文件 + 媒体目录 + 两份 README）
# 复制到一个临时根，在那里做变异，用 `--root` 指过去。真实工作树**一次都不碰**，
# 被杀也只是留下一个临时目录。
#
# ⚠️ 「可以任意并发」的**确切范围**（质量审查要求写清）：
#   ✓ 自检 × 自检 —— 各自 `mktemp -d`，无共享路径
#   ✓ 自检 × 门禁只读运行 —— stage 隔离
#   ✗ 自检 × `export-readme-assets.sh` —— **不行**：收尾那步会对**真实工作树**做
#     只读复核（`REAL_GATE` 不带 `--root`），导出写到一半时它会读到半成品而误报红。
#     脚本内无互斥，跑之前先确认没有导出在跑。
#
# ⚠️ 复制清单是**硬编码的三类**（指纹范围文件 / 媒体目录 / 两份 README），而门禁的
# 读取面会随新维度扩张 —— 这正是本仓 T3 点名的「逐项点名 = 黑名单穷举」。
# 当前三类就是全部，但不保证将来。泄漏的症状已做区分：`expect_red` 把 exit=2 单独
# 报成「隔离副本不完整（自检搭台问题）」，而不是含混的「期望 exit=1」。
#
# 用法
# ----
#     ./scripts/atlas/readme-media-gate-selftest.sh
#
# 退出码：0 = 全部变异都被抓住；1 = 有变异没被抓住（门禁有洞）。
set -uo pipefail   # 故意不加 -e：这里的常态就是「命令要失败」

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/atlas-media-selftest.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT INT TERM

failures=0
mutation_count=15

echo "搭建隔离副本（只复制门禁要读的部分）..."
python3 - "$ROOT_DIR" "$STAGE" <<'PY' || { echo "✗ 隔离副本搭建失败" >&2; exit 1; }
import os, shutil, sys

sys.path.insert(0, os.path.join(sys.argv[1], "scripts", "atlas"))
import readme_media_fingerprint as fp

root, stage = sys.argv[1], sys.argv[2]

# 门禁要读的东西一共三类：指纹范围解析出的源文件、媒体目录、两份 README。
sources = fp.resolve_scope(root)
for relative in sources:
    source = os.path.join(root, relative)
    target = os.path.join(stage, relative)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copy2(source, target)

# `dirs_exist_ok=True`：`cover.html` 本身在指纹范围内，上面那轮已经建出了
# `Docs/Media/README/`，直接 copytree 会撞目录。
shutil.copytree(
    os.path.join(root, "Docs", "Media", "README"),
    os.path.join(stage, "Docs", "Media", "README"),
    dirs_exist_ok=True,
)
for name in ("README.md", "README.zh-CN.md"):
    shutil.copy2(os.path.join(root, name), os.path.join(stage, name))

# 指纹范围文件本身也要在，否则 `--root` 下的指纹算不出来。
scope_target = os.path.join(stage, "scripts", "atlas", fp.SCOPE_FILE_NAME)
os.makedirs(os.path.dirname(scope_target), exist_ok=True)
shutil.copy2(fp.scope_file_path(root), scope_target)

print(f"  复制 {len(sources)} 个源文件 + 媒体目录 + 2 份 README")
PY

GATE=(python3 scripts/atlas/readme_media_gate.py --root "$STAGE")
MEDIA="$STAGE/Docs/Media/README"
README_EN="$STAGE/README.md"
STRINGS_EN="$STAGE/Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings"
EXPORTER="$STAGE/Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift"
ATLAS_RENDER_CLOCK="$STAGE/Packages/AtlasDomain/Sources/AtlasDomain/AtlasRenderClock.swift"

# 断言门禁**变红**，且**红在指定维度上**。
# 「变红」与「红对地方」是两件事 —— 只断言前者的话，一个把尺寸写错、导致所有图
# 都报 existence 的门禁也能骗过自检。
expect_red() {
    local label="$1" dimension="$2"
    local output status

    output="$("${GATE[@]}" 2>&1)"
    status=$?

    # exit=2 是 **NOT_RUN**，不是「门禁没变红」。必须分开报 —— 两者根因完全不同：
    #   exit=2 → 隔离副本（stage）缺东西，是**自检搭台**的问题，去查复制清单
    #   exit=0 → 门禁确实放过了这次变异，是**门禁**的洞，去加规则
    # 混成一句「期望 exit=1，实际 exit=2」会把人引向前者不成立的后者。
    # 质量审查实测构造过这个场景（删掉 stage 里的 scope 文件 / README）。
    if [[ $status -eq 2 ]]; then
        printf '  ✗ %-44s 隔离副本不完整（NOT_RUN）—— 这是自检搭台的问题，不是门禁的洞\n' "$label"
        printf '%s\n' "$output" | sed 's/^/      /'
        printf '      检查阶段搭建逻辑：门禁新增了读取面，而复制清单没跟上？\n'
        failures=$((failures + 1))
        return
    fi

    if [[ $status -ne 1 ]]; then
        printf '  ✗ %-44s 期望 exit=1，实际 exit=%s\n' "$label" "$status"
        printf '%s\n' "$output" | sed 's/^/      /'
        failures=$((failures + 1))
        return
    fi

    if ! grep -q "\[$dimension\]" <<<"$output"; then
        printf '  ✗ %-44s 变红了，但不在 [%s] 维度\n' "$label" "$dimension"
        printf '%s\n' "$output" | sed 's/^/      /'
        failures=$((failures + 1))
        return
    fi

    printf '  ✓ %-44s → [%s]\n' "$label" "$dimension"
}

expect_green() {
    local label="$1"
    local output status

    output="$("${GATE[@]}" 2>&1)"
    status=$?

    if [[ $status -ne 0 ]]; then
        printf '  ✗ %-44s 期望 exit=0，实际 exit=%s\n' "$label" "$status"
        printf '%s\n' "$output" | sed 's/^/      /'
        failures=$((failures + 1))
        return
    fi

    printf '  ✓ %-44s → PASS\n' "$label"
}

# 造一张指定尺寸的 PNG：`solid` 时整张同色（模拟渲染失败），否则逐像素变化。
make_png() {
    local path="$1" width="$2" height="$3" solid="${4:-0}"
    python3 - "$path" "$width" "$height" "$solid" <<'PY'
import struct, sys, zlib

path, width, height, solid = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] == "1"

def chunk(tag, body):
    return (struct.pack(">I", len(body)) + tag + body
            + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF))

if solid:
    raw = (bytes([0]) + b"\xc8\xc8\xc8" * width) * height
else:
    raw = b"".join(
        bytes([0]) + bytes([(x * 13 + y * 29) % 256 for x in range(width * 3)])
        for y in range(height)
    )

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
open(path, "wb").write(png)
PY
}

echo "[0/$mutation_count] 基线 —— 未改动的副本必须是绿的，否则后面全无意义"
expect_green "未改动的仓库"

# 每次变异后从**原件**还原，而不是「反向修回去」——反向 sed 一旦写错就会累积漂移，
# 而累积出来的偏差会被后续 expect_red 误判成「变异没被抓住」。
#
# ⚠️ 每条变异**必须**在跑之前把上一条还原干净。这个脚本自己踩过两次：
# 第一版把多个载体累积改在同一沙箱，「范围外」那项拿到的是前几项遗留的红，
# 结论完全无效。
ORIGINALS="$STAGE/.originals"
mkdir -p "$ORIGINALS"
restore_asset() { cp -p "$ORIGINALS/$(basename "$1")" "$1"; }

for name in atlas-apps-en.png fig01-cover.png; do
    cp -p "$MEDIA/$name" "$ORIGINALS/$name"
done
cp -p "$README_EN" "$ORIGINALS/README.md"
cp -p "$STRINGS_EN" "$ORIGINALS/en.strings"
cp -p "$EXPORTER" "$ORIGINALS/ReadmeAssetExporter.swift"
cp -p "$ATLAS_RENDER_CLOCK" "$ORIGINALS/AtlasRenderClock.swift"

echo "[1/$mutation_count] 维 1 existence · 删掉 manifest 列出的资产"
rm -f "$MEDIA/atlas-apps-en.png"
expect_red "删除 atlas-apps-en.png" "existence"
restore_asset "$MEDIA/atlas-apps-en.png"

echo "[2/$mutation_count] 维 2 dimensions · 换一张尺寸不对的图"
make_png "$MEDIA/atlas-apps-en.png" 100 100
expect_red "换成 100×100 的图" "dimensions"
restore_asset "$MEDIA/atlas-apps-en.png"

echo "[3/$mutation_count] 维 2 dimensions · 同尺寸但内容对不上清单（摘要比对）"
make_png "$MEDIA/atlas-apps-en.png" 2880 1800
expect_red "换成另一张 2880×1800 图" "dimensions"
restore_asset "$MEDIA/atlas-apps-en.png"

# 这条来自对抗审查的证伪：共享资产原先只比尺寸、无内容摘要，同尺寸换图能全过。
echo "[4/$mutation_count] 维 2 dimensions · 共享资产（封面）同尺寸换内容"
make_png "$MEDIA/fig01-cover.png" 3000 1720
expect_red "换掉 fig01-cover.png（尺寸不变）" "dimensions"
restore_asset "$MEDIA/fig01-cover.png"

echo "[5/$mutation_count] 维 3 liveness · 换一张纯色图（复现 98.5% 纯色那起事故）"
make_png "$MEDIA/atlas-apps-en.png" 2880 1800 1
expect_red "换成 2880×1800 纯色图" "liveness"
restore_asset "$MEDIA/atlas-apps-en.png"

echo "[6/$mutation_count] 维 4 references · README 引用不存在的文件"
sed -i '' 's|atlas-overview-en\.png|atlas-overview-DOES-NOT-EXIST.png|' "$README_EN"
expect_red "README.md 引用不存在的文件" "references"
cp -p "$ORIGINALS/README.md" "$README_EN"

echo "[7/$mutation_count] 维 4 references · 英文 README 引了中文图"
sed -i '' 's|atlas-overview-en\.png|atlas-overview-zh-Hans.png|' "$README_EN"
expect_red "README.md 引用 zh-Hans 截图" "references"
cp -p "$ORIGINALS/README.md" "$README_EN"

# 这条来自对抗审查的证伪：注释掉的引用原先仍被当成「已展示」。
#
# ⚠️ 它红在 **orphans** 而不是 references —— 首版断言写的是 references，自检把它
# 抓了出来。原因：剥离注释后 dim 4 已无引用可查，真正报出来的是 dim 6 的
# 「产出但未展示」。这正是「断言要红在对的维度」那条规矩的又一次收益。
echo "[8/$mutation_count] 维 6 orphans · 引用被注释掉（GitHub 上不可见）"
python3 - "$README_EN" <<'PY'
import re, sys
path = sys.argv[1]
content = open(path, encoding="utf-8").read()
content = re.sub(r'(!\[[^\]]*\]\(Docs/Media/README/[^)]+\))', r'<!-- \1 -->', content)
open(path, "w", encoding="utf-8").write(content)
PY
expect_red "README.md 全部引用包进 HTML 注释" "orphans"
cp -p "$ORIGINALS/README.md" "$README_EN"

# 这条来自对抗审查的收尾项：坏编码原先会让引用扫描静默退化（宽容读取可能得出
# 「引用都在」的假象），且 repr(UnicodeDecodeError) 会把整个二进制刷进报错文本。
# 这条来自质量审查的 P0 证伪：首版只认 ``` 围栏，`~~~` 是 GitHub 上等价的合法围栏
# —— 把全部引用藏进 `~~~` 块，六维曾**全绿**而 README 上一张图都看不见。
echo "[9/$mutation_count] 维 6 orphans · 引用藏进 ~~~ 围栏（GitHub 合法的另一种围栏）"
python3 - "$README_EN" <<'PY'
import re, sys
path = sys.argv[1]
content = open(path, encoding="utf-8").read()
refs = re.findall(r"!\[[^\]]*\]\(Docs/Media/README/[^)]+\)", content)
content = re.sub(r"(!\[[^\]]*\]\(Docs/Media/README/[^)]+\))", "", content)
content = content.replace("## Screens", "## Screens\n\n~~~markdown\n" + "\n".join(refs) + "\n~~~\n")
open(path, "w", encoding="utf-8").write(content)
PY
expect_red "README.md 全部引用藏进 ~~~ 围栏" "orphans"
cp -p "$ORIGINALS/README.md" "$README_EN"

echo "[10/$mutation_count] 维 4 references · README 不是合法 UTF-8"
python3 - "$README_EN" <<'PY'
import sys
path = sys.argv[1]
data = open(path, "rb").read()
open(path, "wb").write(data[:2000] + b"\xff\xfe\x80\x81" * 50 + data[2000:])
PY
expect_red "README.md 塞入非法 UTF-8 字节" "references"
cp -p "$ORIGINALS/README.md" "$README_EN"

echo "[11/$mutation_count] 维 5 drift · 改一条被渲染的文案"
printf '\n"selftest.drift.probe" = "drift probe";\n' >> "$STRINGS_EN"
expect_red "向 en Localizable.strings 追加一条" "drift"
cp -p "$ORIGINALS/en.strings" "$STRINGS_EN"

# 这条来自对抗审查的证伪（最严重）：真正被渲染的 shell 与画布尺寸定义在导出器里，
# 而指纹范围起初只登记了 AppShellView.swift —— 改画布尺寸截图会变、门禁却全绿。
echo "[12/$mutation_count] 维 5 drift · 改导出器的画布尺寸（真正被渲染的那份）"
sed -i '' 's|CGSize(width: 1440, height: 900)|CGSize(width: 1280, height: 800)|' "$EXPORTER"
expect_red "导出器 screenshotSize 1440×900 → 1280×800" "drift"
cp -p "$ORIGINALS/ReadmeAssetExporter.swift" "$EXPORTER"

# 这条守的是「范围取整目录」这个决定本身。`AtlasRenderClock.swift` 是为修「截图不可
# 复现」新增的文件，它影响渲染；而范围当时是逐文件点名的，**立刻漏了它**。
# 本变异改的正是这个新文件 —— 若有人把范围改回点名式，它会变绿。
echo "[13/$mutation_count] 维 5 drift · 改 AtlasDomain 里**新增**的文件（守「范围取整目录」）"
python3 - "$ATLAS_RENDER_CLOCK" <<'PY'
import sys
path = sys.argv[1]
with open(path, "a", encoding="utf-8") as handle:
    handle.write("\n// selftest mutation\n")
PY
expect_red "改 AtlasRenderClock.swift（AtlasDomain 新增文件）" "drift"
cp -p "$ORIGINALS/AtlasRenderClock.swift" "$ATLAS_RENDER_CLOCK"

echo "[14/$mutation_count] 维 6 orphans · 塞一个无人引用的资产"
make_png "$MEDIA/atlas-zzz-orphan.png" 2880 1800
expect_red "塞入 atlas-zzz-orphan.png" "orphans"
rm -f "$MEDIA/atlas-zzz-orphan.png"

echo "[15/$mutation_count] 维 6 orphans · 导出器产出了却没人展示"
# 注意：README 的 Screens 表里 apps 与 ledger 在**同一行**，所以这里删掉的是
# 两个引用。标签按实际写的（曾写成只删一个，名实不符）。
sed -i '' '/atlas-ledger-en\.png/d' "$README_EN"
expect_red "README.md 去掉含两张截图的整行" "orphans"
cp -p "$ORIGINALS/README.md" "$README_EN"

echo
echo "[收尾] 隔离副本丢弃；真实工作树自始至终未被触碰"
cleanup
trap - EXIT INT TERM

# 对**真实仓库**做一次只读复核：自检不该改变任何东西。
REAL_GATE=(python3 scripts/atlas/readme_media_gate.py)
if "${REAL_GATE[@]}" >/dev/null 2>&1; then
    echo "  ✓ 真实工作树                                       → PASS"
else
    printf '  ✗ %-44s 真实工作树未通过（自检不该改它，或仓库本就有红）\n' "真实工作树"
    "${REAL_GATE[@]}"
    failures=$((failures + 1))
fi

if [[ $failures -gt 0 ]]; then
    echo "ATLAS_README_MEDIA_GATE_SELFTEST=FAIL:$failures"
    exit 1
fi

echo "ATLAS_README_MEDIA_GATE_SELFTEST=PASS"
echo "$mutation_count 条变异全部被抓住，且每条都红在正确的维度上。"
