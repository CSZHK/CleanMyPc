#!/usr/bin/env python3
"""Atlas 文案门禁（copy gate）。

判据源：`iterations/REQ-copy-plain-language/terminology-baseline.md`。
设计纪律（来自 iteration-governance 的 Validation Gate）：
  - 命令必须区分「跳过」与「通过」。本脚本在前置不满足时**不返回 0**。
  - 完成判据客观：全绿即全绿，红清单条目数 = 待办数。

阻断维（全部为零才 PASS）：
  C1 术语禁用表         —— zh / en 两侧各自的黑名单，命中即红
  C2 屏幕副标题宽度     —— route.*.subtitle 与 *.screen.subtitle 的显示宽度上限
  C3 屏幕副标题规格句式 —— 禁「而不是 / 前提下 / 只突出 …」这类写给评审者的话
  C4 术语映射一致性     —— zh 用了 A，en 必须用 B（双向）
  C6 占位符对称         —— 同一 key 的 zh / en 占位符序列必须一致
  C7 键集合 parity      —— 两份文件的 key 集合必须相等
  C9 Swift 字面量残留   —— Swift 源码字符串字面量里的禁用词/字形（`№` 这类漏网的根因）
  C10 解析完整性        —— 每一行都真的被解析了（防 LINE_RE 静默丢行使规则绕过）

报告维（**非阻断**，随门禁打印，不参与退出码）：
  C5 孤儿键             —— strings 里存在、Swift 里零引用。归 `ATL-272` 跟踪；
                            本 REQ 不吸收（删除死键是另一类工作，且已由 Docs Agent 署名在案）
  C8 长句               —— 显示宽度 > 96 的文案值，排除法定 / 诊断文案

  ⚠️ 维度分离的理由（iteration-governance 的 Validation Gate）：
     「任一维 100% 覆盖不构成其他维也覆盖的证据」。把 C5 并进阻断维，
     会让本 REQ 的验收判据混入一个不属于它的工作流。
"""

import argparse
import inspect
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

STRINGS = {
    "zh": "Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings",
    "en": "Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings",
}

# ---- 规则参数 ----------------------------------------------------------------

# C1：术语禁用表。定稿见 terminology-baseline.md §1。
# en 侧只扫「文案值」，不扫键名 —— 键名是内部标识，不对用户可见。
BANNED = {
    "zh": ["台账", "回执", "足迹", "证据", "发现项", "入账", "作废", "主流程", "保留窗口", "№"],
    # `No. %d`：P-7 要求编号统一用 `#`。en 侧曾与 zh 不一致（zh 已 `#`、en 仍 `No.`），
    # 故把带占位符的形态也纳入黑名单，防止只改一侧的回潮。
    "en": ["Ledger", "Receipt", "Footprint", "Evidence", "№", "No. %d"],
}
# C1 的 en 侧**大小写不敏感**：`Docs/COPY_GUIDELINES.md` §5 把 `finding(s)` 列为内部工程词，
# 但门禁此前只列了「首字母大写」形态 —— `ledger` / `receipt` / `app footprint` / `evidence`
# 全部漏网（实测）。zh 侧无大小写概念，逐字比对即可。
# 例外：`No. %d` 必须逐字匹配（`no.` 小写在英文里是正常词）。
BANNED_EN_VERBATIM = {"No. %d"}

# C1b：**变形维**。字面表（BANNED）漏掉语序/名词化/搭配变体 ——
# 实测漏网例：`"%d 项发现待处理"` 不含「发现项」三连字，字面表匹配不到；
#             `Refresh App Storages` 把 Storage 当可数名词，字面表也无从表达。
# 故把「同一个概念的变形形态」写成正则。**每发现一次漏网就补一条**。
BANNED_REGEX = {
    "zh": [
        (r"(项|个|组|条)发现(?!项)", "「发现」的名词化用法（该概念已退役为「清理项」）"),
        # 词根而非固定搭配：此前只列「审计轨迹|可审计」，实测「审计记录」「安全审计」全部漏网。
        (r"审计", "「审计」是内部工程词"),
    ],
    "en": [
        (r"\bStorages\b", "Storage 不可数；复数形态是搭配错误（大小写不敏感）"),
        (r"not-removed set", "「set」是实现词，面向用户应说「will not be removed」"),
        # `finding(s)` 在 COPY_GUIDELINES §5 已列为硬约束，但从未被翻译成规则（契约与实现脱节）。
        (r"\bfindings?\b", "`finding(s)` 是内部工程词，已退役为 item(s)"),
    ],
}

# C1 例外：显式豁免的键（当前为空 —— 保留结构，使豁免必须写下来而不是靠改规则绕过）。
BANNED_EXEMPT_KEYS = set()

# C2：**副标题**显示宽度上限（CJK 记 2，其余记 1）。
# 范围说明：原正则只覆盖 `route.*.subtitle` 与 `*.screen.subtitle` 共 18 键，
# 而仓库实有 50 个 `.subtitle` 键 —— 分节副标题（`*.controls.subtitle` /
# `*.optionalSection.subtitle` 等）同样常驻可见，却整体在射程外。
# 实测该缺口下曾有 3 条超宽 + 1 条规格句在悬空。已扩为全部 `.subtitle` 键。
SCREEN_SUBTITLE_MAX_WIDTH = 48
# en 侧此前**完全没有宽度约束** —— 实测 51 个 `.subtitle` 键里 4 条超 72 字符（最长 98）。
# 阈值取 72：en 字符数分布 p50=54 / p90=68，72 卡在 p95 之外，只收异常值。
SCREEN_SUBTITLE_MAX_LEN_EN = 72
SCREEN_SUBTITLE_KEY = re.compile(r"^.*\.subtitle$")

# C3：屏幕副标题里不得出现的「规格句式」标记。
SPEC_IDIOMS = ["而不是", "前提下", "留在上下文中", "只突出", "先解释", "帮助用户理解"]

# C4：zh 词 -> en 词，成对出现。
# 刻意收窄：`占用` 单独一条会误伤「磁盘占用 / Disk usage」这类通用说法，
# 故只对「应用占用」这一复合概念建映射（对应 P-3 的 App Footprint 退役）。
TERM_PAIRS = [
    ("历史记录", "history"),
    ("应用占用", "app storage"),
    ("分类依据", "classification reason"),
    ("未删除", "not removed"),
    ("已记录", "recorded"),
]

# C5：允许「零 Swift 引用」的键前缀（运行时拼接构造）。
DYNAMIC_KEY_PREFIXES = ("language.", "glossary.")

# C8：长句阈值与法定/诊断豁免。
LONG_VALUE_MAX_WIDTH = 96
LONG_VALUE_EXEMPT_PREFIXES = ("settings.acknowledgement.", "settings.notices.body", "xpc.error.")

SWIFT_ROOTS = ["Packages", "Apps", "XPC", "Helpers", "Testing"]
SKIP_DIRS = {".build", "node_modules", ".git", "dist", "DerivedData"}

LINE_RE = re.compile(r'^\s*"([^"]+)"\s*=\s*"(.*)";\s*$')
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[@dfs]")


# ---- 工具 --------------------------------------------------------------------

def load_strings(rel_path):
    path = os.path.join(ROOT, rel_path)
    if not os.path.isfile(path):
        return None
    table = {}
    for line in io.open(path, encoding="utf-8"):
        m = LINE_RE.match(line)
        if m:
            table[m.group(1)] = m.group(2)
    return table


def display_width(s):
    return sum(2 if ("一" <= c <= "鿿" or "　" <= c <= "〿" or "＀" <= c <= "￯") else 1
               for c in s)


def placeholders(s):
    return PLACEHOLDER_RE.findall(s)


# ---- 规则实现 ----------------------------------------------------------------

def check_banned(zh, en):
    """C1 字面维 + C1b 变形维。两者都不为零才算这一维干净。"""
    hits = []
    for lang, table in (("zh", zh), ("en", en)):
        for key in sorted(table):
            if key in BANNED_EXEMPT_KEYS:
                continue
            value = table[key]
            haystack = value if lang == "zh" else value.lower()
            for word in BANNED[lang]:
                needle = word if (lang == "zh" or word in BANNED_EN_VERBATIM) else word.lower()
                if needle in haystack:
                    hits.append({"key": key, "lang": lang, "term": word, "value": value})
            for pattern, why in BANNED_REGEX[lang]:
                m = re.search(pattern, value, re.IGNORECASE if lang == "en" else 0)
                if m:
                    hits.append({"key": key, "lang": lang,
                                 "term": "%s（变形：%s）" % (m.group(0), why),
                                 "value": value})
    return hits


def check_subtitle_width(zh, en):
    """副标题宽度：zh 按显示宽度（CJK=2）、en 按字符数。两侧都要卡。"""
    hits = []
    for key in sorted(zh):
        if not SCREEN_SUBTITLE_KEY.match(key):
            continue
        w = display_width(zh[key])
        if w > SCREEN_SUBTITLE_MAX_WIDTH:
            hits.append({"key": key, "width": w, "limit": SCREEN_SUBTITLE_MAX_WIDTH,
                         "lang": "zh", "value": zh[key]})
        if key in en and len(en[key]) > SCREEN_SUBTITLE_MAX_LEN_EN:
            hits.append({"key": key, "width": len(en[key]), "limit": SCREEN_SUBTITLE_MAX_LEN_EN,
                         "lang": "en", "value": en[key]})
    return hits


def check_spec_idioms(zh):
    hits = []
    for key in sorted(zh):
        if SCREEN_SUBTITLE_KEY.match(key):
            for idiom in SPEC_IDIOMS:
                if idiom in zh[key]:
                    hits.append({"key": key, "idiom": idiom, "value": zh[key]})
    return hits


def check_term_pairs(zh, en):
    hits = []
    for key in sorted(set(zh) & set(en)):
        for zh_word, en_word in TERM_PAIRS:
            if zh_word in zh[key] and en_word not in en[key].lower():
                hits.append({"key": key, "zh_term": zh_word, "en_expected": en_word,
                             "en_value": en[key]})
    return hits


def swift_source_index():
    chunks = []
    for root in SWIFT_ROOTS:
        base = os.path.join(ROOT, root)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in filenames:
                if name.endswith(".swift"):
                    try:
                        chunks.append(io.open(os.path.join(dirpath, name),
                                              encoding="utf-8", errors="ignore").read())
                    except OSError:
                        pass
    return "\n".join(chunks)


def check_orphans(zh, source):
    return [key for key in sorted(zh)
            if not key.startswith(DYNAMIC_KEY_PREFIXES)
            and '"%s"' % key not in source]


def check_placeholders(zh, en):
    hits = []
    for key in sorted(set(zh) & set(en)):
        if placeholders(zh[key]) != placeholders(en[key]):
            hits.append({"key": key, "zh": zh[key], "en": en[key]})
    return hits


def check_parity(zh, en):
    return sorted(set(zh) ^ set(en))


# C9：Swift 字符串字面量里的禁用**字形/词**。
# 为什么必须有这一维：`№` 是硬编码在 Swift 里的（`Text("№\(n)")`），而 C1 只遍历两份 `.strings`
# 的 value ⇒ 门禁报 PASS 而 № 仍在 5 处渲染。**门禁的输入面必须覆盖被检事实的全部载体。**
# **范围刻意收紧到生产源**：`Tests/` 下的字符串是 XCTest 断言消息与夹具
# （例 `"no two runs share a №"`），进的是测试日志，不是界面。
# 初版把 Tests 一并扫进来，一次报出 22 条里 21 条是这类误报 —— 规则一旦误报就会被绕过，
# 故宁可窄而准。
BANNED_SWIFT_LITERAL = ["№", "台账", "回执", "足迹", "入账", "作废"]
SWIFT_LITERAL_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def check_swift_literals(source):
    hits = []
    # 逐文件扫，便于给出行号级别的定位。
    for root in SWIFT_ROOTS:
        base = os.path.join(ROOT, root)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
            for name in sorted(filenames):
                if not name.endswith(".swift"):
                    continue
                path = os.path.join(dirpath, name)
                if os.sep + "Tests" + os.sep in path:
                    continue          # 测试源码不是面向用户的载体
                try:
                    text = io.open(path, encoding="utf-8", errors="ignore").read()
                except OSError:
                    continue
                for lineno, line in enumerate(text.split("\n"), 1):
                    stripped = line.lstrip()
                    if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
                        continue          # 注释不算面向用户的文案
                    for literal in SWIFT_LITERAL_RE.findall(line):
                        for word in BANNED_SWIFT_LITERAL:
                            if word in literal:
                                hits.append({
                                    "file": os.path.relpath(path, ROOT),
                                    "line": lineno, "term": word, "literal": literal[:60],
                                })
    return hits


def check_parse_integrity(zh_path, en_path):
    """C10：解析完整性守卫。

    `LINE_RE` 只匹配 `"key" = "val";` 这一种形态，**不匹配的行被静默丢弃**。
    后果：一条写成 `"k" = "v" ;` 或带行尾注释的文案可绕过全部 8 条规则，
    而键计数不变 ⇒ C7 parity 也不报警。这与仓库已修过的「零 UI 用例仍 exit 0」
    是同一类**静默空转**。
    """
    hits = []
    for label, path in (("zh", zh_path), ("en", en_path)):
        if not os.path.isfile(path):
            continue
        in_block = False
        for lineno, raw in enumerate(io.open(path, encoding="utf-8"), 1):
            line = raw.strip()
            # 块注释可以跨行（本文件的 header 注释就是），必须带状态逐行判，
            # 只看「行首是不是 *」会把续行当成未解析内容误报。
            if in_block:
                if "*/" in line:
                    in_block = False
                continue
            if line.startswith("/*"):
                if "*/" not in line:
                    in_block = True
                continue
            if not line or line.startswith("//"):
                continue
            if LINE_RE.match(raw):
                continue
            hits.append({"lang": label, "line": lineno, "text": line[:80]})
    return hits


def check_long_values(zh):
    hits = []
    for key in sorted(zh):
        if key.startswith(LONG_VALUE_EXEMPT_PREFIXES):
            continue
        w = display_width(zh[key])
        if w > LONG_VALUE_MAX_WIDTH:
            hits.append({"key": key, "width": w, "value": zh[key]})
    return hits


BLOCKING = [
    ("C1", "术语禁用表", check_banned),
    ("C2", "副标题超宽", check_subtitle_width),
    ("C3", "副标题规格句式", check_spec_idioms),
    ("C4", "术语映射不一致", check_term_pairs),
    ("C6", "占位符不对称", check_placeholders),
    ("C7", "键集合不 parity", check_parity),
    # C9/C10 是「输入面完整性」两维：前者保证被检事实的**全部载体**都在射程内，
    # 后者保证**解析没静默丢行**。二者都属于仓库既有的「守卫空转」防御。
    ("C9", "Swift 字面量残留", check_swift_literals),
    ("C10", "解析完整性", check_parse_integrity),
]
REPORTED = [
    ("C5", "孤儿键", check_orphans),
    ("C8", "长句", check_long_values),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", "-v", action="store_true", help="打印每一条红的明细")
    ap.add_argument("--json", action="store_true", help="以 JSON 输出（供脚本消费）")
    ap.add_argument("--only", help="只跑某个规则，如 --only C1")
    args = ap.parse_args()

    zh = load_strings(STRINGS["zh"])
    en = load_strings(STRINGS["en"])

    # 前置不满足 = 配置缺陷，不是「跳过」。不得静默返回 0。
    if zh is None or en is None:
        missing = [p for p in STRINGS.values() if not os.path.isfile(os.path.join(ROOT, p))]
        print("ATLAS_COPY_GATE=NOT_RUN")
        print("✗ 找不到文案源文件，门禁未执行：%s" % ", ".join(missing), file=sys.stderr)
        print("  这是配置缺陷，不是环境限制；不得计为通过。", file=sys.stderr)
        return 2

    source = swift_source_index()
    ctx = {"zh": zh, "en": en, "source": source,
           "zh_path": os.path.join(ROOT, STRINGS["zh"]),
           "en_path": os.path.join(ROOT, STRINGS["en"])}

    def run(spec):
        rid, name, fn = spec
        if args.only and args.only.upper() != rid:
            return None
        wanted = inspect.signature(fn).parameters
        return (rid, name, fn(**{k: v for k, v in ctx.items() if k in wanted}))

    blocking = [r for r in (run(s) for s in BLOCKING) if r]
    reported = [r for r in (run(s) for s in REPORTED) if r]

    failed = sum(len(h) for _, _, h in blocking)
    reported_total = sum(len(h) for _, _, h in reported)

    if args.json:
        print(json.dumps({
            "blocking": {rid: {"name": n, "count": len(h), "items": h}
                         for rid, n, h in blocking},
            "reported": {rid: {"name": n, "count": len(h), "items": h}
                         for rid, n, h in reported},
            "failed": failed,
        }, ensure_ascii=False, indent=2))
        return 0 if failed == 0 else 1

    print("Atlas 文案门禁   zh=%d keys  en=%d keys" % (len(zh), len(en)))
    print("-" * 70)
    for rid, name, hits in blocking:
        print("%s %s %-20s %4d" % ("✓" if not hits else "✗", rid, name, len(hits)))
        if hits and args.verbose:
            for h in hits[:300]:
                print("      · %s" % _fmt(rid, h))
            if len(hits) > 300:
                print("      … 另有 %d 条（截断）" % (len(hits) - 300))
    print("-" * 70)
    print("报告维（非阻断）")
    for rid, name, hits in reported:
        note = "  ← 归 ATL-272" if rid == "C5" else ""
        print("  %s %-18s %4d%s" % (rid, name, len(hits), note))
    print("-" * 70)

    if failed == 0:
        print("ATLAS_COPY_GATE=PASS")
        print("阻断维全绿；报告维 %d 条（不参与判定）。" % reported_total)
        return 0

    print("ATLAS_COPY_GATE=FAIL:%d" % failed)
    print("阻断维红清单 %d 条 = 待办 %d 条。" % (failed, failed))
    return 1


def _fmt(rid, h):
    if rid == "C1":
        return "[%s] %s = %s   ← 命中「%s」" % (h["lang"], h["key"], h["value"][:70], h["term"])
    if rid == "C2":
        return "[%s] %s (宽 %d > %d) %s" % (h.get("lang", "zh"), h["key"],
                                            h["width"], h.get("limit", "?"), h["value"])
    if rid == "C3":
        return "%s ← 「%s」  %s" % (h["key"], h["idiom"], h["value"])
    if rid == "C4":
        return "%s ← zh 有「%s」但 en 无「%s」：%s" % (h["key"], h["zh_term"], h["en_expected"],
                                                    h["en_value"][:60])
    if rid == "C6":
        return "%s  zh=%s  en=%s" % (h["key"], h["zh"], h["en"])
    if rid == "C7":
        return h
    if rid == "C9":
        return "%s:%d  ← 字面量含「%s」：\"%s\"" % (h["file"], h["line"], h["term"], h["literal"])
    if rid == "C10":
        return "[%s]:%d 无法解析（会被静默丢弃）：%s" % (h["lang"], h["line"], h["text"])
    return str(h)


if __name__ == "__main__":
    sys.exit(main())
