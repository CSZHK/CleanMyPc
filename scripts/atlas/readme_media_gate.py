#!/usr/bin/env python3
"""README 媒体资产门禁 —— 六维机检。

为什么存在
----------
本仓的 README 媒体资产此前**没有任何机检**：发版链不碰它们，`prepare-release.sh`
只改版本号与 CHANGELOG，两份 README 引的是同一批英文截图（中文读者看到英文界面），
而 `fig01-cover.png` 曾经是一张 **98.5% 纯色**的渲染失败产物、躺了很久没人发现。

六维
----
1. `existence`  —— manifest 列的资产在盘上
2. `dimensions` —— 实际像素与 manifest 记录一致
3. `liveness`   —— 像素健康：光有文件不够，得是一张**画出来的**图
4. `references` —— 两份 README 的引用都存在，且**语言对上**（en 引 en、zh 引 zh）
5. `drift`      —— 渲染输入指纹未变（变了 = 代码改了但截图没重导）
6. `orphans`    —— 目录里没有无人引用的资产

退出码（沿用 `copy_gate.py` 的语义，见迭代治理「门禁卫生规则」）
---------------------------------------------------------------
* ``0`` = PASS
* ``1`` = FAIL（红条目数见哨兵 ``ATLAS_README_MEDIA_GATE=FAIL:N``）
* ``2`` = NOT_RUN —— 前置条件缺失。**这不是通过。**

依赖
----
纯标准库。PNG 解码是手写的（`_decode_png`），因为 GitHub 托管 runner 不保证有
Pillow，而一个「没装依赖就跳过」的门禁等于没有门禁。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import struct
import sys
import zlib

import readme_media_fingerprint as fingerprint

# --------------------------------------------------------------------------
# 契约常量
# --------------------------------------------------------------------------

#: 导出器应产出的截图：主干 → 该图对应的路由是否属于 Screens 网格。
#:
#: ⚠️ 本表是**独立于 Swift 的载体**。`ReadmeAssetExporter.screenshotRoutes` 与这里
#: 分开维护，是**故意的**：同源的话，导出器漏掉一个路由时两边一起忘掉，门禁形同
#: 自证。分开写，漏一个就会响。
EXPECTED_SCREENSHOTS: tuple[str, ...] = ("overview", "smart-clean", "apps", "ledger")

#: 截图语言 —— 与 `AtlasLanguage.rawValue` 一致。
EXPECTED_LANGUAGES: tuple[str, ...] = ("en", "zh-Hans")

#: 导出器产出的图标（单份，无语言）。
EXPECTED_ICON = "atlas-icon.png"

#: 不由导出器产出、但同样被 README 展示的资产。
#: `fig01-cover.png` 的源是 `cover.html`（Chrome 无头渲染，已纳入第 5 维指纹范围）。
SHARED_ASSETS: tuple[str, ...] = ("fig01-cover.png", "atlas-prerelease-warning.png")

#: **刻意归档**的资产：不服务 README，但当初是有意留下的。
#:
#: 这里是白名单，所以每一条都必须写明理由与出处 —— 否则它会变成「什么都能塞」的
#: 垃圾桶，第 6 维也就废了。新增条目 = 一次显式的保留决定，不是顺手免红。
#:
#: 判据来源：`git log -- Docs/Media/README/<file>`。**不是**「我看着像没用」。
ARCHIVED_ASSETS: dict[str, str] = {
    "final_with_cover.mp4": "2fd28f0 docs(readme): archive cover-frame promo video for reference",
    "atlas-promo-cover.mp4": "bde228a docs(readme): add hero promo video（成片，README 现改用 GitHub user-attachments 托管）",
}

MANIFEST_NAME = "manifest.json"

#: 每类资产的期望像素尺寸。**不能对整份 manifest 用同一个尺寸** ——
#: 图标是 1024×1024，第一版门禁就是这么误报的。
EXPECTED_PIXEL_SIZE = {
    "screenshot": (2880, 1800),   # 1440×900 pt @2×
    "icon": (1024, 1024),
    "shared": {
        "fig01-cover.png": (3000, 1720),
        # 截的是 macOS 弹窗，尺寸**确实随系统变** —— 把它钉死是刻意的：
        # 换台机器重截后尺寸会变，门禁报红正是要你确认那次替换，
        # 而不是让它悄悄换掉。改这个常数 = 一次显式的替换决定。
        "atlas-prerelease-warning.png": (964, 338),
    },
}

#: 第 3 维阈值。**按实测基线定，不是拍的。**
#:
#: 2026-09-15 实测（本模块自身的解码器，与 Pillow 逐位交叉验证过）：
#:
#:   资产                              unique   主色占比
#:   atlas-prerelease-warning.png         281     51.5%   ← 合法最低 unique / 最高主色
#:   atlas-apps-zh-Hans.png              1819     45.9%   ← 合法，但已接近上限
#:   atlas-apps-en.png                   1791     45.7%
#:   atlas-icon.png                      3843     26.2%
#:   atlas-ledger-zh-Hans.png            2141     15.5%
#:   atlas-ledger-en.png                 2016     14.7%
#:   atlas-overview-en.png               2114     11.5%
#:   atlas-overview-zh-Hans.png          2188     11.4%
#:   atlas-smart-clean-en.png            2303     11.4%
#:   atlas-smart-clean-zh-Hans.png       2161     11.4%
#:   fig01-cover.png                     2125      9.8%
#:   （已知烂图 fig01-cover.png 曾为）       —     98.5%   ← 要抓住的就是这个
#:
#: 阈值取在「合法极值」与「已知烂图」之间：unique 侧 64 对合法最低 281 有 4.4× 余量，
#: 主色侧 0.75 对合法最高 0.515 有 1.46× 余量、对烂图 0.985 有 1.3× 余量。
#:
#: ⚠️ 主色侧余量只有 1.46×，是两档里更紧的。`atlas-apps-*.png` 的图标网格占了大片
#: 纯色，主色占比天生高。若将来 UI 变得更「平」，先复核这里的基线再调阈值。
#:
#: ⚠️ 上表是**某一次渲染**的读数。导出器当前**不可复现**（fixture 用 `Date()`，
#: 截图里烘焙了墙钟时间，见 `Docs/design/2026-09-15-readme-media-lifecycle.md`），
#: 重导后 unique 会有个位数漂移 —— 所以阈值取的是量级余量，不是精确边界。
#:
#: 注意 unique 单看**抓不住部分渲染**（只画出侧栏也会有几百种颜色）——那一类靠第 5 维
#: 的漂移指纹与 `verify.md` 里的人工确认兜。本维只负责「整张是空白/纯色」。
MIN_UNIQUE_COLORS = 64
MAX_DOMINANT_FRACTION = 0.75

#: 像素统计的采样上限（避免对 2880×1800 逐像素）。
SAMPLE_MAX_DIMENSION = 200

#: IHDR 声明尺寸的 sanity 上界。真实资产最大 3000×1720 ≈ 5.2M 像素，取 40M 留 7× 余量。
#: 用途：畸形头（声明宽 2^31-1）会让 `stride = width * channels` 进内存分配路径。
MAX_DECLARED_PIXELS = 40_000_000

README_FILES: dict[str, str] = {
    "README.md": "en",
    "README.zh-CN.md": "zh-Hans",
}

REFERENCE_PATTERN = re.compile(r"Docs/Media/README/([A-Za-z0-9._-]+)")
LANGUAGE_SUFFIX_PATTERN = re.compile(r"^atlas-(?P<stem>.+)-(?P<lang>zh-Hans|en)\.png$")

#: 媒体目录内互引用的写法（`cover.html` 用裸文件名，不带 `Docs/Media/README/` 前缀）。
BARE_ASSET_PATTERN = re.compile(r"([A-Za-z0-9][A-Za-z0-9._-]*\.(?:png|jpg|jpeg|mp4|gif|webp))")

#: 扫描「谁引用了这个文件名」时要看的扩展名。
REFERENCE_SCAN_SUFFIXES = (
    ".md", ".sh", ".yml", ".yaml", ".html", ".swift", ".py", ".json", ".txt",
)

#: 第 6 维只审这些扩展名 —— `cover.html` / `manifest.json` 是源与元数据，不是资产。
ASSET_SUFFIXES = (".png", ".jpg", ".jpeg", ".mp4", ".gif", ".webp")


class GateNotRun(RuntimeError):
    """前置条件缺失。**不得**计为通过。"""


# --------------------------------------------------------------------------
# PNG 读取（纯标准库）
# --------------------------------------------------------------------------


class PngError(RuntimeError):
    pass


def _read_png_chunks(path: str) -> tuple[int, int, int, int, bytes]:
    """返回 (width, height, bit_depth, color_type, idat_bytes)。"""
    with open(path, "rb") as handle:
        blob = handle.read()

    if len(blob) < 8 or blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise PngError(f"不是 PNG：{os.path.basename(path)}")

    position = 8
    width = height = bit_depth = color_type = None
    idat_parts: list[bytes] = []

    while position + 8 <= len(blob):
        (length,) = struct.unpack(">I", blob[position:position + 4])
        chunk_type = blob[position + 4:position + 8]
        body = blob[position + 8:position + 8 + length]
        position += 12 + length  # 4 长度 + 4 类型 + body + 4 CRC

        if chunk_type == b"IHDR":
            # 长度先判再 unpack：截断的 IHDR 会让 `struct.unpack` 抛裸 `struct.error`，
            # 而各维度只捕 `PngError`，于是它一路穿到 `run_checks` 的泛化兜底，
            # 报出一条**没有文件上下文**的红条目（对抗审查实测）。
            if len(body) < 13:
                raise PngError(f"IHDR 长度不足（{len(body)} 字节）：{os.path.basename(path)}")
            width, height, bit_depth, color_type = struct.unpack(">IIBB", body[:10])
            interlace = body[12]
            if interlace != 0:
                raise PngError(f"不支持隔行扫描 PNG：{os.path.basename(path)}")
            # 声明尺寸的 sanity 上界 —— 防止「声明 2^31-1 宽」的畸形头把
            # `stride = width * channels` 推进内存分配路径。真实资产最大
            # 3000×1720 ≈ 5.2M 像素，40M 有 7× 余量。
            if width <= 0 or height <= 0 or width * height > MAX_DECLARED_PIXELS:
                raise PngError(
                    f"IHDR 声明尺寸不合理（{width}×{height}）：{os.path.basename(path)}"
                )
        elif chunk_type == b"IDAT":
            idat_parts.append(body)
        elif chunk_type == b"IEND":
            break

    if width is None:
        raise PngError(f"PNG 缺 IHDR：{os.path.basename(path)}")

    return width, height, bit_depth, color_type, b"".join(idat_parts)


#: 读/解码 PNG 时**所有**可能的异常。
#:
#: 别在三处各写各的：首版 `_check_liveness` 只捕 `(PngError, zlib.error)`，
#: 而截断 IHDR 真正抛的是裸 `struct.error` —— 收错类型，异常一路穿到
#: `run_checks` 的泛化兜底，报出一条丢失文件上下文的红条目（对抗审查实测）。
PNG_ERRORS = (PngError, zlib.error, struct.error)

CHANNELS_BY_COLOR_TYPE = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def _unfilter(raw: bytes, width: int, height: int, bit_depth: int, color_type: int) -> list[bytearray]:
    """还原 PNG 扫描线。"""
    if bit_depth != 8:
        raise PngError(f"只支持 8 位深，实际 {bit_depth}")

    channels = CHANNELS_BY_COLOR_TYPE.get(color_type)
    if channels is None:
        raise PngError(f"不支持的 color type：{color_type}")

    stride = width * channels
    rows: list[bytearray] = []
    previous = bytearray(stride)
    position = 0

    for _ in range(height):
        if position >= len(raw):
            raise PngError("IDAT 数据提前结束")
        filter_type = raw[position]
        position += 1
        row = bytearray(raw[position:position + stride])
        if len(row) < stride:
            raise PngError("IDAT 行数据不完整")
        position += stride

        if filter_type == 0:
            pass
        elif filter_type == 1:
            for index in range(channels, stride):
                row[index] = (row[index] + row[index - channels]) & 0xFF
        elif filter_type == 2:
            for index in range(stride):
                row[index] = (row[index] + previous[index]) & 0xFF
        elif filter_type == 3:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + ((left + previous[index]) >> 1)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                up = previous[index]
                up_left = previous[index - channels] if index >= channels else 0
                estimate = left + up - up_left
                distance_left = abs(estimate - left)
                distance_up = abs(estimate - up)
                distance_up_left = abs(estimate - up_left)
                if distance_left <= distance_up and distance_left <= distance_up_left:
                    predictor = left
                elif distance_up <= distance_up_left:
                    predictor = up
                else:
                    predictor = up_left
                row[index] = (row[index] + predictor) & 0xFF
        else:
            raise PngError(f"未知 PNG 过滤器类型：{filter_type}")

        rows.append(row)
        previous = row

    return rows


def _sample_pixels(path: str) -> list[tuple[int, int, int]]:
    """解出 PNG 并返回采样后的像素（RGB，已合成到白底）。"""
    width, height, bit_depth, color_type, idat = _read_png_chunks(path)
    if not idat:
        raise PngError(f"PNG 无 IDAT：{os.path.basename(path)}")

    rows = _unfilter(zlib.decompress(idat), width, height, bit_depth, color_type)
    channels = CHANNELS_BY_COLOR_TYPE[color_type]

    step_x = max(1, width // SAMPLE_MAX_DIMENSION)
    step_y = max(1, height // SAMPLE_MAX_DIMENSION)

    pixels: list[tuple[int, int, int]] = []

    for row_index, y in enumerate(range(0, height, step_y)):
        row = rows[y]
        # **每行错开相位**。固定格点采样是个可被精确对齐的靶子：只在
        # `x % step_x == 0 且 y % step_y == 0` 处放噪声的纯白图能骗过本维
        # （对抗审查实测构造过）。相位错开后该构造不再对齐。
        # 用固定质数而不是随机数 —— 判定必须可复现。
        offset = (row_index * 6151) % step_x
        for x in range(offset, width, step_x):
            offset = x * channels
            if color_type == 0:      # 灰度
                value = row[offset]
                pixels.append((value, value, value))
            elif color_type == 4:    # 灰度 + alpha
                value, alpha = row[offset], row[offset + 1]
                pixels.append(_over_white(value, value, value, alpha))
            elif color_type == 2:    # RGB
                pixels.append((row[offset], row[offset + 1], row[offset + 2]))
            elif color_type == 6:    # RGBA
                pixels.append(_over_white(row[offset], row[offset + 1], row[offset + 2], row[offset + 3]))
            else:                    # 调色板 —— 本仓不产出，解不了就明确报错
                raise PngError(f"暂不支持调色板 PNG：{os.path.basename(path)}")

    return pixels


def _over_white(red: int, green: int, blue: int, alpha: int) -> tuple[int, int, int]:
    """合成到白底 —— 透明边缘按白底计，否则阴影会被算成一种"颜色"而虚高。"""
    inverse = 255 - alpha
    return (
        (red * alpha + 255 * inverse) // 255,
        (green * alpha + 255 * inverse) // 255,
        (blue * alpha + 255 * inverse) // 255,
    )


def pixel_stats(path: str) -> dict:
    """返回 sampled / unique / dominant_fraction。"""
    pixels = _sample_pixels(path)
    if not pixels:
        raise PngError(f"PNG 解出 0 个像素：{os.path.basename(path)}")

    counts: dict[tuple[int, int, int], int] = {}
    for pixel in pixels:
        counts[pixel] = counts.get(pixel, 0) + 1

    total = len(pixels)
    return {
        "sampled": total,
        "unique": len(counts),
        "dominant_fraction": max(counts.values()) / total,
    }


def png_dimensions(path: str) -> tuple[int, int]:
    width, height, _, _, _ = _read_png_chunks(path)
    return width, height


def sha256_of_file(path: str) -> str:
    hasher = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


# --------------------------------------------------------------------------
# 路径与清单
# --------------------------------------------------------------------------


def media_directory(root: str) -> str:
    return os.path.join(root, "Docs", "Media", "README")


def manifest_path(root: str) -> str:
    return os.path.join(media_directory(root), MANIFEST_NAME)


def expected_asset_names() -> list[str]:
    """导出器**应当**产出的全部文件名。"""
    names = [
        f"atlas-{stem}-{language}.png"
        for stem in EXPECTED_SCREENSHOTS
        for language in EXPECTED_LANGUAGES
    ]
    names.append(EXPECTED_ICON)
    return names


def build_manifest(root: str) -> dict:
    """导出后重建 `manifest.json`（由 `export-readme-assets.sh` 调用）。

    独立预期：先断言盘上就是那 9 个导出资产（4 路由 × 2 语言 + 图标）加 2 个共享
    资产，再写清单。导出器若静默漏产一张，这里就炸 —— 而不是把残缺当成"本次产出"
    照单全收。

    **共享资产（封面 / 系统弹窗截图）也进清单**。它们不由导出器产出，但同样被
    README 展示，同样需要内容摘要 —— 否则「同尺寸换一张图」能完全溜过门禁
    （对抗审查实测：换掉 `fig01-cover.png` 后门禁仍然 PASS）。
    """
    directory = media_directory(root)
    if not os.path.isdir(directory):
        raise GateNotRun(f"媒体目录不存在：{directory}")

    missing = [name for name in expected_asset_names() if not os.path.isfile(os.path.join(directory, name))]
    if missing:
        raise GateNotRun(
            "导出器未产出全部资产，拒绝写清单（缺：" + "、".join(sorted(missing)) + "）。"
            "清单若照单全收残缺产出，第 1 维就永远发现不了丢图。"
        )

    missing_shared = [name for name in SHARED_ASSETS if not os.path.isfile(os.path.join(directory, name))]
    if missing_shared:
        raise GateNotRun(
            "README 展示的共享资产缺失，拒绝写清单（缺：" + "、".join(sorted(missing_shared)) + "）。"
        )

    assets = []
    for name in expected_asset_names() + list(SHARED_ASSETS):
        path = os.path.join(directory, name)
        width, height = png_dimensions(path)
        match = LANGUAGE_SUFFIX_PATTERN.match(name)
        assets.append({
            "file": name,
            "width": width,
            "height": height,
            "language": match.group("lang") if match else None,
            # `exported` = 由导出器产出；`shared` = 手工维护但同受门禁约束。
            "source": "exported" if name in expected_asset_names() else "shared",
            "sha256": sha256_of_file(path),
        })

    manifest = {
        "generator": "scripts/atlas/export-readme-assets.sh",
        "assets": assets,
        "sourceFingerprint": fingerprint.compute(root),
    }

    with open(manifest_path(root), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")

    return manifest


def load_manifest(root: str) -> dict:
    path = manifest_path(root)
    if not os.path.isfile(path):
        raise GateNotRun(
            f"清单缺失：{path}\n"
            "  先跑 ./scripts/atlas/export-readme-assets.sh 生成截图与清单。"
        )
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise GateNotRun(f"清单读不了或不是合法 JSON：{path}（{error}）") from error


# --------------------------------------------------------------------------
# 六维
# --------------------------------------------------------------------------


def _check_existence(root: str, manifest: dict) -> list[str]:
    directory = media_directory(root)
    failures = []

    listed = {asset.get("file") for asset in manifest.get("assets", [])}
    for name in expected_asset_names():
        if name not in listed:
            failures.append(f"manifest 漏记应产出的资产：{name}")

    for asset in manifest.get("assets", []):
        name = asset.get("file")
        if name and not os.path.isfile(os.path.join(directory, name)):
            failures.append(f"manifest 列了但盘上没有：{name}")

    for name in SHARED_ASSETS:
        if not os.path.isfile(os.path.join(directory, name)):
            failures.append(f"README 展示的共享资产缺失：{name}")

    return failures


def _expected_size_for(name: str) -> tuple[int, int] | None:
    """按资产**类别**取期望尺寸。截图 / 图标 / 共享资产各不相同。"""
    if name == EXPECTED_ICON:
        return EXPECTED_PIXEL_SIZE["icon"]
    if LANGUAGE_SUFFIX_PATTERN.match(name):
        return EXPECTED_PIXEL_SIZE["screenshot"]
    return EXPECTED_PIXEL_SIZE["shared"].get(name)


def _check_dimensions(root: str, manifest: dict) -> list[str]:
    directory = media_directory(root)
    failures = []

    for asset in manifest.get("assets", []):
        name = asset.get("file")
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue  # 第 1 维已经报过
        try:
            actual = png_dimensions(path)
        except PNG_ERRORS as error:
            failures.append(f"{name}：{error}")
            continue

        expected = _expected_size_for(name)
        if expected is not None and actual != expected:
            failures.append(f"{name} 尺寸 {actual[0]}×{actual[1]}，期望 {expected[0]}×{expected[1]}")

        recorded = (asset.get("width"), asset.get("height"))
        if recorded != actual:
            failures.append(f"{name} 尺寸与 manifest 记录不符：盘上 {actual}，清单 {recorded}")

        # 内容摘要比对 —— 抓「有人换了图但没重建 manifest」。
        # 只比尺寸抓不住这一条：一张别的 2880×1800 图照样过。
        recorded_digest = asset.get("sha256")
        if recorded_digest and sha256_of_file(path) != recorded_digest:
            failures.append(
                f"{name} 内容与 manifest 记录不符（摘要不一致）—— "
                "有人改了截图却没重建清单，跑 ./scripts/atlas/export-readme-assets.sh"
            )

    # 共享资产现在也进 manifest（含 sha256），主循环已覆盖。
    # 这里只兜「清单是旧版、还没记共享资产」的情形，避免漏检与重复报同一件事。
    listed = {asset.get("file") for asset in manifest.get("assets", [])}
    for name in SHARED_ASSETS:
        if name in listed:
            continue
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue
        expected = _expected_size_for(name)
        if expected is None:
            continue  # 该共享资产未登记期望尺寸 —— 只记盘上事实，不臆断
        try:
            actual = png_dimensions(path)
        except PNG_ERRORS as error:
            failures.append(f"{name}：{error}")
            continue
        if actual != expected:
            failures.append(f"{name} 尺寸 {actual[0]}×{actual[1]}，期望 {expected[0]}×{expected[1]}")

    return failures


def _check_liveness(root: str, manifest: dict) -> list[str]:
    """像素健康 —— 光有文件不够，得是一张**画出来的**图。

    这是唯一能防住「渲染静默失败产出纯色图」的一维。历史事故：
    `fig01-cover.png` 曾以 98.5% 纯色的样子在 README 顶部挂了很久。
    """
    directory = media_directory(root)
    failures = []

    # 共享资产现在也进 manifest，直接 extend 会让每条被检查两遍、同一缺陷报两次红，
    # 把 `FAIL:N` 这个哨兵的定量意义搞坏（质量审查实测：0 字节封面报出 FAIL:3，
    # 其中 liveness 重复两条）。用去重后的有序集合。
    targets = list(dict.fromkeys(
        [asset.get("file") for asset in manifest.get("assets", [])] + list(SHARED_ASSETS)
    ))

    for name in targets:
        if not name:
            continue
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue  # 第 1 维已经报过
        try:
            stats = pixel_stats(path)
        except PNG_ERRORS as error:
            failures.append(f"{name}：像素统计失败 —— {error}")
            continue

        if stats["unique"] < MIN_UNIQUE_COLORS:
            failures.append(
                f"{name} 只解出 {stats['unique']} 种颜色（阈值 ≥{MIN_UNIQUE_COLORS}）"
                f"，疑似渲染失败产出的空白/纯色图"
            )
        if stats["dominant_fraction"] > MAX_DOMINANT_FRACTION:
            failures.append(
                f"{name} 主色占比 {stats['dominant_fraction']:.1%}（阈值 ≤{MAX_DOMINANT_FRACTION:.0%}）"
                f"，疑似渲染失败产出的纯色图"
            )

    return failures


#: 围栏代码块。**必须同时认 ``` 与 ~~~** —— GitHub 上两者等价，且都不可见。
#:
#: 首版只写 ```，对抗审查实测：把 README 里所有图片引用包进 `~~~` 围栏后，
#: 六维**全绿**，而 README 在 GitHub 上一张图都看不见。这属于「假绿」，
#: 比漏报更糟 —— 门禁说没事，人就真的不看了。
#:
#: 用**反向引用**（`(?P=fence)`）而不是固定三连字符：4 个反引号的围栏里可以合法
#: 出现 3 个反引号的行，固定长度会让 `.*?` 提前在内层收尾，块内引用被当成可见。
_FENCE_PATTERN = re.compile(
    r"^[ \t]*(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^[ \t]*(?P=fence)[ \t]*$",
    re.S | re.M,
)


#: 落单的围栏起始行（没有配对的结束围栏）。
_FENCE_OPENER_PATTERN = re.compile(r"^[ \t]*(?:`{3,}|~{3,})[^\n]*$", re.M)


def _strip_non_visible(content: str) -> str:
    """去掉**在 GitHub 上不可见**的区域：HTML 注释与围栏代码块。

    被 `<!-- -->` 包住的引用不会渲染成图片，围栏代码块（``` 或 ~~~）里的路径
    也只是示例文本 —— 三者都不能算「已展示」。

    未闭合的围栏也要处理：GitHub 会把**其后全部内容**按代码渲染，所以从落单的
    起始围栏起截断。不这样做的话，门禁会把它后面的引用误判成「可见」（实测偏宽松）。
    """
    content = re.sub(r"<!--.*?-->", "", content, flags=re.S)
    content = _FENCE_PATTERN.sub("", content)

    dangling = _FENCE_OPENER_PATTERN.search(content)
    if dangling:
        content = content[: dangling.start()]
    return content


def _readme_paths(root: str) -> dict[str, str]:
    paths: dict[str, str] = {}
    for name in README_FILES:
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            raise GateNotRun(f"README 缺失：{path}")
        paths[name] = path
    return paths


def _references_in_file(path: str) -> list[str]:
    """读一个文本文件并取出其中**可见**的媒体引用。

    非法 UTF-8 时用 `errors="replace"` 兜住，**不把整个二进制塞进报错文本** ——
    实测那样会刷屏几千字符（`repr(UnicodeDecodeError)` 会把出错位置的字节整段带出来），
    把一条真正的红淹没掉。编码合法性由 `_check_references` 单独判，见下。
    """
    try:
        with open(path, encoding="utf-8") as handle:
            content = handle.read()
    except UnicodeDecodeError:
        with open(path, encoding="utf-8", errors="replace") as handle:
            content = handle.read()
    return REFERENCE_PATTERN.findall(_strip_non_visible(content))


def _readme_references(root: str) -> dict[str, list[str]]:
    return {
        name: _references_in_file(path)
        for name, path in _readme_paths(root).items()
    }


def _check_references(root: str, manifest: dict) -> list[str]:
    """引用存在 + **语言对上** + **README 本身是合法 UTF-8**。

    语言这一条是本次改动的核心：此前两份 README 引同一批英文图，
    中文读者打开 README 看到的是英文界面。
    """
    directory = media_directory(root)
    failures: list[str] = []
    readme_paths = _readme_paths(root)
    # 精确名清单，一次取好。
    #
    # **不能用 `os.path.isfile` 判存在**：macOS/APFS 默认大小写不敏感，
    # `Docs/Media/README/Atlas-Apps-en.png` 会被判成「存在」，而 GitHub 的路径
    # 解析是大小写敏感的 —— 于是「引用写成错的大小写、线上 404」既过了存在性检查，
    # 又因为 `LANGUAGE_SUFFIX_PATTERN`（大小写敏感）不匹配而**静默跳过语言检查**。
    # 判据必须与载体同敏感度：这里用目录清单里的精确名比对。
    try:
        exact_entries = set(os.listdir(directory))
    except OSError as error:
        raise GateNotRun(f"媒体目录读不了：{directory}（{error}）") from error

    for readme_name, expected_language in README_FILES.items():
        path = readme_paths[readme_name]

        # 编码合法性单独判：坏编码会让引用扫描退化（用 `errors="replace"` 读下去可能
        # 得出「引用都在」的假象），所以不能只靠宽容读取，得显式报一条。
        try:
            with open(path, encoding="utf-8") as handle:
                handle.read()
        except UnicodeDecodeError as error:
            failures.append(
                f"{readme_name} 不是合法 UTF-8（首处错在字节 {error.start}）—— "
                "坏编码会让引用扫描失真，先修编码"
            )
            continue

        for referenced in _references_in_file(path):
            if referenced not in exact_entries:
                if os.path.isfile(os.path.join(directory, referenced)):
                    failures.append(
                        f"{readme_name} 引用的文件名大小写对不上：{referenced}"
                        "（本机文件系统不区分大小写所以能找到，GitHub 上会 404）"
                    )
                else:
                    failures.append(f"{readme_name} 引用了不存在的文件：{referenced}")
                continue

            match = LANGUAGE_SUFFIX_PATTERN.match(referenced)
            if match is None:
                continue  # 共享资产（封面/系统弹窗）无语言后缀，两份 README 共用

            if match.group("lang") != expected_language:
                failures.append(
                    f"{readme_name} 引用的是 {match.group('lang')} 截图：{referenced}"
                    f"（该 README 应引用 {expected_language}）"
                )

    return failures



    return failures


def _check_drift(root: str, manifest: dict) -> list[str]:
    """渲染输入指纹比对 —— 「代码改了但截图没重导」的唯一检出手段。"""
    recorded = manifest.get("sourceFingerprint") or {}
    recorded_value = recorded.get("value")
    if not recorded_value:
        return ["manifest 里没有 sourceFingerprint.value —— 清单是残缺的"]

    try:
        current = fingerprint.compute(root)
    except fingerprint.FingerprintError as error:
        raise GateNotRun(f"指纹算不出来：{error}") from error

    if current["value"] == recorded_value:
        return []

    recorded_files = set(recorded.get("files") or [])
    recorded_digests = recorded.get("digests") or {}
    current_digests = current.get("digests") or {}
    current_files = set(current["files"])

    # 逐文件比对：报错要能指名道姓。只存聚合值的话报错只能说「有东西变了」，
    # 而本仓的教训正是「不可定位的报错等于没有报错」。
    changed = sorted(
        name for name, digest in current_digests.items()
        if name in recorded_files and recorded_digests.get(name) not in (None, digest)
    )
    # 清单来自旧版（尚无 digests 字段）时退化为「文件名单变了没」。
    if not recorded_digests:
        changed = []

    added = sorted(current_files - recorded_files)
    removed = sorted(recorded_files - current_files)

    detail = []
    if changed:
        detail.append("内容变了：" + "、".join(changed[:8]) + ("（等）" if len(changed) > 8 else ""))
    if added:
        detail.append("新进范围：" + "、".join(added[:8]))
    if removed:
        detail.append("移出范围：" + "、".join(removed[:8]))
    if not detail:
        detail.append("逐文件摘要无法定位（清单缺 digests 字段，可能是旧版清单）")

    return [
        "截图与代码已脱节（渲染输入指纹变化）——" + "；".join(detail) + "。"
        "跑 ./scripts/atlas/export-readme-assets.sh 重导，并提交新的截图与 manifest.json"
    ]


def _check_orphans(root: str, manifest: dict) -> list[str]:
    """目录里不得有 README 体系用不上的资产；导出器产出的截图必须真被用上。

    「引用面」**只认 README 体系**：manifest ∪ 两份 README ∪ 媒体目录内的源文件
    （`cover.html` 引用 `atlas-logo.png`）。**故意不认**历史设计文档里的提及 ——
    `Docs/design/*` 里「`atlas-history.png` → `atlas-ledger.png`」这类句子是在
    叙述一次已发生的改名，不是活的依赖；把历史叙述算作「有人引用」会让这个维度
    永远抓不到真孤儿（本仓此前正是这么躺了 15 个）。
    """
    directory = media_directory(root)
    failures: list[str] = []

    readme_refs = _readme_references(root)

    referenced: set[str] = {asset.get("file") for asset in manifest.get("assets", [])}
    for name in README_FILES:
        referenced.update(readme_refs[name])
    referenced.update(_references_within(directory))

    # (a) 目录里不该躺着 README 体系用不上的资产
    for entry in sorted(os.listdir(directory)):
        if entry.startswith("."):
            continue  # `.DS_Store` 之流：macOS 随时重造，不是资产治理问题
        if not entry.lower().endswith(ASSET_SUFFIXES):
            continue
        if not os.path.isfile(os.path.join(directory, entry)):
            continue
        if entry in referenced or entry in ARCHIVED_ASSETS:
            continue
        failures.append(f"孤儿资产（README 体系无人引用，也不在 ARCHIVED_ASSETS 里）：{entry}")

    # (b) 导出器产出的截图必须真的出现在对应语言的 README 里。
    #     否则它是「白占仓库的哑资产」—— 没人看，但每次改文案都要重导一遍。
    #
    #     共享资产同样要在场：它们**只**出现在 manifest 里，因此 (a) 永远抓不到
    #     「README 不再展示封面」。实测：把所有图片引用包进 HTML 注释后，
    #     (a) 全部通过（清单里算「已引用」），只有这里的 (b) 能报出来。
    for readme_name, language in README_FILES.items():
        shown = set(readme_refs[readme_name])
        for stem in EXPECTED_SCREENSHOTS:
            name = f"atlas-{stem}-{language}.png"
            if name not in shown:
                failures.append(f"导出器产出了 {name}，但 {readme_name} 没有展示它")
        for name in SHARED_ASSETS:
            if name not in shown:
                failures.append(f"{name} 是 README 展示的共享资产，但 {readme_name} 没有展示它")

    return failures


def _references_within(directory: str) -> set[str]:
    """媒体目录内非资产文件（`cover.html`、`manifest.json`）按裸文件名引用的资产。

    同样只认**可见**引用 —— `cover.html` 顶部那段说明性注释里提到过
    `atlas-icon.png` / `atlas-overview.png`，那是文档，不是引用。
    """
    names: set[str] = set()

    for entry in os.listdir(directory):
        if entry.startswith(".") or entry.lower().endswith(ASSET_SUFFIXES):
            continue
        path = os.path.join(directory, entry)
        if not os.path.isfile(path) or not entry.endswith(REFERENCE_SCAN_SUFFIXES):
            continue
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                content = handle.read()
        except OSError:
            continue
        names.update(BARE_ASSET_PATTERN.findall(_strip_non_visible(content)))

    return names


# --------------------------------------------------------------------------
# 驱动
# --------------------------------------------------------------------------

DIMENSIONS = (
    ("existence", "存在性", _check_existence),
    ("dimensions", "尺寸", _check_dimensions),
    ("liveness", "像素健康", _check_liveness),
    ("references", "引用完整性", _check_references),
    ("drift", "漂移指纹", _check_drift),
    ("orphans", "零孤儿", _check_orphans),
)


def run_checks(root: str) -> int:
    manifest = load_manifest(root)

    failures: list[str] = []
    for key, label, check in DIMENSIONS:
        try:
            found = check(root, manifest)
        except GateNotRun:
            raise
        except Exception as error:  # noqa: BLE001 —— 门禁自身出错必须显式变红，不能静默
            found = [f"{label} 维度自身出错（这是门禁缺陷，不是资产缺陷）：{error!r}"]
        for item in found:
            failures.append(f"[{key}] {item}")

    if failures:
        print(f"ATLAS_README_MEDIA_GATE=FAIL:{len(failures)}")
        for line in failures:
            print(f"  ✗ {line}")
        return 1

    print("ATLAS_README_MEDIA_GATE=PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Atlas README 媒体资产门禁")
    parser.add_argument("--root", default=None, help="仓库根（默认按本文件位置推断）")
    parser.add_argument(
        "--build-manifest",
        action="store_true",
        help="导出后重建 manifest.json（供 export-readme-assets.sh 调用）",
    )
    arguments = parser.parse_args(argv)

    root = os.path.abspath(arguments.root or fingerprint.default_root())

    try:
        if arguments.build_manifest:
            manifest = build_manifest(root)
            print(f"manifest 已写出：{manifest_path(root)}（{len(manifest['assets'])} 条资产）")
            return 0
        return run_checks(root)
    except GateNotRun as error:
        print("ATLAS_README_MEDIA_GATE=NOT_RUN")
        print(f"  ✗ {error}")
        print("  NOT_RUN 不是通过 —— 前置条件缺失属于配置缺陷（见迭代治理「门禁卫生规则」）。")
        return 2


if __name__ == "__main__":
    sys.exit(main())
