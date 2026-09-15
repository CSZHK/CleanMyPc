#!/usr/bin/env python3
"""README 媒体资产 —— 渲染输入指纹（唯一实现）。

导出链路（`export-readme-assets.sh`）与门禁（`readme_media_gate.py`）**都**调用本模块。
算法不复制到 Swift，也不复制到门禁里：两份实现必然漂移，而漂移的守卫比没有守卫更糟 ——
它会在错误的地方报红，或者更坏，静默通过。

指纹定义
--------
对范围内每个文件取 sha256，拼成一行 ``<相对路径>:<内容 sha256>``；按路径排序后
对整块文本再取一次 sha256。

路径参与哈希，所以**改名与改内容同样算变化** —— 截图条目按文件名寻址，
改名必须触发重导，否则 README 引用会指向不存在的文件。

用法
----
    python3 scripts/atlas/readme_media_fingerprint.py [--root DIR]

打印一行 JSON：``{"algo": "sha256", "files": [...], "value": "..."}``
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import sys

SCOPE_FILE_NAME = "readme-media-fingerprint-scope.txt"
ALGO = "sha256"


class FingerprintError(RuntimeError):
    """范围不可用 —— 与「指纹算出来了」必须区分开。"""


def _script_dir() -> str:
    return os.path.dirname(os.path.abspath(__file__))


def default_root() -> str:
    """仓库根：本文件位于 ``<root>/scripts/atlas/``。"""
    return os.path.abspath(os.path.join(_script_dir(), "..", ".."))


def scope_file_path(root: str) -> str:
    return os.path.join(root, "scripts", "atlas", SCOPE_FILE_NAME)


def read_patterns(root: str) -> list[str]:
    """读范围文件，返回去重后的 glob 列表（保持文件内首次出现的顺序）。"""
    path = scope_file_path(root)
    if not os.path.isfile(path):
        raise FingerprintError(f"指纹范围文件缺失：{path}")

    patterns: list[str] = []
    seen: set[str] = set()

    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line in seen:
                continue
            seen.add(line)
            patterns.append(line)

    if not patterns:
        raise FingerprintError(f"指纹范围文件里没有任何 glob：{path}")

    return patterns


def resolve_scope(root: str) -> list[str]:
    """展开范围为**相对于 root** 的文件路径，按字典序排序。

    范围解析出空集时**抛错**而不是返回空列表：一个空范围会让指纹退化成常量，
    门禁从此永远通过 —— 正是「空转守卫」。宁可炸掉，也不要假绿。
    """
    matched: set[str] = set()

    for pattern in read_patterns(root):
        absolute = os.path.join(root, pattern)
        for hit in glob.glob(absolute, recursive=True):
            if not os.path.isfile(hit):
                continue
            matched.add(os.path.relpath(hit, root))

    if not matched:
        raise FingerprintError(
            "指纹范围解析出 0 个文件 —— 范围文件里的 glob 已全部失效"
            f"（仓库结构改动？）：{scope_file_path(root)}"
        )

    return sorted(matched)


def _file_digest(root: str, relative_path: str) -> str:
    hasher = hashlib.sha256()
    with open(os.path.join(root, relative_path), "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def compute(root: str | None = None) -> dict:
    """算出 ``{"algo", "files", "digests", "value"}``。

    ``digests`` 留的是逐文件摘要，**不是**冗余：门禁的漂移维度要能指名道姓说
    「是这两个文件变了」。只存聚合值的话，报错只能说「有东西变了」，
    而本仓的教训正是「不可定位的报错等于没有报错」。

    文件读不到时抛 ``FingerprintError``。
    """
    root = os.path.abspath(root or default_root())
    files = resolve_scope(root)

    digests: dict[str, str] = {}
    lines: list[str] = []
    for relative_path in files:
        try:
            digest = _file_digest(root, relative_path)
        except OSError as error:
            raise FingerprintError(f"指纹范围内的文件读不到：{relative_path}（{error}）") from error
        digests[relative_path] = digest
        lines.append(f"{relative_path}:{digest}")

    aggregate = hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()
    return {"algo": ALGO, "files": files, "digests": digests, "value": aggregate}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="README 媒体资产渲染输入指纹")
    parser.add_argument("--root", default=None, help="仓库根（默认按本文件位置推断）")
    arguments = parser.parse_args(argv)

    try:
        result = compute(arguments.root)
    except FingerprintError as error:
        print(f"ATLAS_README_MEDIA_FINGERPRINT=NOT_RUN {error}", file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
