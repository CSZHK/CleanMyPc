#!/usr/bin/env bash
# 重导 Atlas README 媒体资产（双语截图 + 图标 + 封面 + 清单）。
#
# 产物落在 Docs/Media/README/：
#   atlas-{overview,smart-clean,apps,ledger}-{en,zh-Hans}.png   8 张截图（Swift 渲染）
#   atlas-icon.png
#   fig01-cover.png                                             封面（Chrome 渲染 cover.html）
#   manifest.json                                               资产摘要 + 渲染输入指纹
#
# **一条命令重导全部** —— 媒体门禁报红时给你的解药就是这一条。
# 跑完自动过一遍门禁（六维）。门禁红 = 这次导出没产出可用的资产。
#
# 只在**本机**跑：渲染需要真图形环境。CI 上跑的是门禁，不是导出。
#
# ⚠️ 目标目录**固定**，不再收自定义输出目录参数。
# 原先收 `$1` 当输出目录，但 manifest 与门禁都锚在仓库根的 `Docs/Media/README/`
# （指纹也是相对仓库根算的）—— 传了自定义目录就会「渲染到 A、清单建在 B」，
# 静默错位。既然无调用方传参，索性去掉这个半坏的口子。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/Docs/Media/README"

CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
COVER_SIZE="3000,1720"

mkdir -p "$OUTPUT_DIR"

# 同一个 debug 二进制的两个实例会互相打架（后一个抢渲染上下文），
# 所以先请走路上的那个。`-x` 是精确进程名匹配，不会误伤别的 swift 进程。
if pgrep -x AtlasApp >/dev/null 2>&1; then
    echo "发现正在运行的 AtlasApp，先结束它（两个实例会抢渲染上下文）..."
    pkill -x AtlasApp || true
    sleep 1
fi

echo "[1/3] Swift 渲染（4 路由 × 2 语言 + 图标）..."
ATLAS_EXPORT_README_ASSETS_DIR="$OUTPUT_DIR" \
    swift run --package-path "$ROOT_DIR/Apps" AtlasApp

echo "[2/3] 渲染封面 fig01-cover.png（源：cover.html）..."
# 封面**必须**在这里渲染，不能只更新 cover.html 了事：封面源在指纹范围内，
# 若只改源不重渲，指纹会更新而封面还是旧的 —— 门禁照样绿，封面静默烂掉。
if [[ ! -x "$CHROME_BIN" ]]; then
    echo "✗ 找不到 Chrome：$CHROME_BIN" >&2
    echo "  封面渲染是本次导出的一部分，缺它就不算导出完成。" >&2
    echo "  装 Chrome，或改用封面源 cover.html 注释里记录的等价命令。" >&2
    exit 1
fi

# 渲染前确认封面的**输入**齐了。
#
# 为什么必须显式查：Chrome 在「页面加载了但内嵌图 404」时**照样 exit 0**，
# 并且写出一张尺寸正确、像素健康的退化封面 —— 随后 `--build-manifest` 会把这张
# 坏图**照单记入清单**，于是「渲染退化 ⇒ 重建清单 ⇒ 摘要自洽 ⇒ 六维全绿」。
# 质量审查实测构造过：健康封面 unique=2125，退化封面 unique=1041，两者都在阈值内。
# 尺寸检查救不了（退化图尺寸是对的），只能在这里挡住。
for required in cover.html atlas-logo.png atlas-overview-en.png; do
    if [[ ! -f "$OUTPUT_DIR/$required" ]]; then
        echo "✗ 封面渲染缺少输入：$OUTPUT_DIR/$required" >&2
        echo "  Chrome 对缺失的内嵌图**不会**报错，只会渲染出一张退化的封面，" >&2
        echo "  然后被写进 manifest —— 门禁将无法分辨。故在此硬失败。" >&2
        exit 1
    fi
done

(
    cd "$OUTPUT_DIR"
    "$CHROME_BIN" \
        --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
        --force-device-scale-factor=1 --window-size="$COVER_SIZE" \
        --screenshot=fig01-cover.png "file://$(pwd)/cover.html"
)

echo "[3/3] 重建 manifest.json..."
python3 "$ROOT_DIR/scripts/atlas/readme_media_gate.py" --build-manifest --root "$ROOT_DIR"

echo "README assets exported to: $OUTPUT_DIR"
echo "过一遍媒体门禁..."

# 门禁是本脚本的最后一道自检：导出产出的东西必须立刻能过六维。
# 退出码原样透传（0/1/2），不吞。
exec "$ROOT_DIR/scripts/atlas/readme-media-gate.sh" --root "$ROOT_DIR"
