#!/usr/bin/env python3
"""CHG-2026-10-copy-plain-language-round2 — 两份 Localizable.strings 的键级迁移。

每个键断言恰好匹配一次；失败即抛异常整体不落盘（先改内存，最后统一写回）。
键级（而非值级）替换：锚点是 `"key" = "...";` 整行，避免值内特殊字符误匹配。
"""
import re
import sys

STRINGS = {
    "zh": "Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings",
    "en": "Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings",
}

DELETES = [
    "route.history.title", "route.history.subtitle", "sidebar.history.dynamic",
    "smartclean.primary.scan.title", "smartclean.primary.scan.detail",
    "smartclean.primary.refresh.title", "smartclean.primary.refresh.detail",
    "smartclean.primary.execute.title", "smartclean.primary.execute.detail",
    "settings.panel.title", "settings.panel.subtitle",
]

ZH_EDITS = {
    "overview.snapshot.subtitle": "重要的健康数据和优先处理建议。",
    "overview.snapshot.memory.detail": "内存吃紧时，这里会先看出来。",
    "overview.snapshot.uptime.detail": "开机太久时，提醒你考虑重启。",
    "overview.snapshot.callout.ok.detail": "先看下面的建议，需要时再去智能清理。",
    "overview.metric.findings.detail": "执行前会先分成安全、待复核、高级三类。",
    "overview.recommend.disk.headline": "磁盘空间紧张，建议先清理一轮",
    "smartclean.status.executing": "正在执行已复核的清理计划",
    "smartclean.loading.scan": "正在扫描可清理的内容",
    "smartclean.status.scanning": "正在扫描可清理的内容",
    "smartclean.section.safe": "大多能安全清理，通常也能恢复。",
    "smartclean.section.advanced": "可能影响系统运作，删除前仔细确认。",
    "apps.list.subtitle": "查看占用、残留数量和卸载操作。",
    "apps.metric.listed.detail": "Atlas 能检查的应用数量。",
    "apps.detail.callout.ready.title": "已生成卸载计划，复核后可执行。",
    "apps.evidence.residualEstimate": "预计残留",
    "apps.evidence.why.ready": "%@ 的卸载计划已就绪。下面是占用与残留明细，检查后再执行。",
    "apps.evidence.why.idle": "%@ 的占用与残留文件。先复核卸载计划，再逐项确认可恢复步骤。",
    "apps.detail.callout.building.title": "正在生成卸载计划",
    "apps.evidence.bundlePath": "应用位置",
    "permissions.metric.tracked.title": "权限总数",
    "permissions.metric.tracked.detail": "当前版本会检查的全部权限。",
    "settings.callout.title": "数据保存在本机，重要改动都有记录。",
    "settings.trust.destructive.title": "改动系统的操作",
    "settings.trust.destructive.subtitle": "改前留恢复点，改后可查记录。",
    "settings.retention.detail": "可恢复的结果会保留这么久。",
    "settings.recoveryPanel.subtitle": "恢复内容保留多久，哪些位置不扫描。",
    "settings.exclusions.empty.detail": "还没有排除项，Atlas 按默认范围扫描。",
    "fileorganizer.action.preview": "预演计划",
    "fileorganizer.action.dryRun": "预演",
    "fileorganizer.dryRun.success.one": "预演完成：%1$@ 个文件可安全移动（%2$@）",
    "fileorganizer.dryRun.success.other": "预演完成：%1$@ 个文件可安全移动（%2$@）",
    "fileorganizer.dryRun.error": "预演失败：%@",
    "fileorganizer.preview.empty.detail": "先扫描并分类文件，再预演移动计划。",
    "fileorganizer.error.stalePlan": "文件整理计划已过期，请重新预演。",
    "fileorganizer.evidence.empty.detail": "选中文件后，这里显示归类依据和移动目标。",
    "fileorganizer.ruleeditor.subtitle": "自定义归类规则：按类型或文件名。",
    "application.error.executionUnavailable": "Atlas 现在无法执行这项操作：%@",
    "application.error.helperUnavailable": "Atlas 无法完成这项操作，需要的系统组件不可用：%@",
    "application.error.workerRejected": "这项操作没有被处理（%@）：%@",
    "infrastructure.execute.summary.clean.review.one": "有 1 个仅供复核的项，本次未处理。",
    "infrastructure.execute.summary.clean.review.other": "有 %d 个仅供复核的项，本次未处理。",
    "infrastructure.restore.summary.state.one": "已在 Atlas 中恢复 1 项；没有可用的恢复路径，磁盘文件未移动。",
    "infrastructure.restore.summary.state.other": "已在 Atlas 中恢复 %d 项；没有可用的恢复路径，磁盘文件未移动。",
}

ZH_GLOSSARY = """
"glossary.containers.term" = "容器";
"glossary.containers.definition" = "macOS 给应用隔离数据用的系统目录，名字与系统路径一致，方便对照排查。";
"glossary.groupcontainers.term" = "群组容器";
"glossary.groupcontainers.definition" = "同一开发者的多个应用共享数据的系统目录。";
"glossary.savedstate.term" = "保存状态";
"glossary.savedstate.definition" = "应用用来记住上次窗口和页面位置的系统文件。";
"""

EN_EDITS = {
    "overview.snapshot.subtitle": "Key health info and what to handle first.",
    "overview.snapshot.memory.detail": "An early signal when memory is running tight.",
    "overview.snapshot.uptime.detail": "A hint that it may be time to restart.",
    "overview.snapshot.callout.ok.detail": "Check the suggestions below, then open Smart Clean when you are ready.",
    "overview.metric.findings.detail": "Sorted into Safe, Needs Review, and Advanced before anything runs.",
    "overview.recommend.disk.headline": "Disk space is tight — a cleanup pass recommended",
    "smartclean.status.executing": "Running the reviewed cleanup plan",
    "smartclean.loading.scan": "Scanning for cleanable items",
    "smartclean.status.scanning": "Scanning for cleanable items",
    "smartclean.section.safe": "Mostly safe to clean, and usually recoverable.",
    "smartclean.section.advanced": "These can affect how your Mac runs — check before removing.",
    "apps.list.subtitle": "See storage, leftover files, and uninstall actions.",
    "apps.metric.listed.detail": "Apps Atlas can inspect.",
    "apps.detail.callout.ready.title": "Uninstall plan ready — review it, then run it.",
    "apps.evidence.residualEstimate": "Estimated leftovers",
    "apps.evidence.why.ready": "Uninstall plan ready for %@. Below is the storage and leftover detail — check it before running.",
    "apps.evidence.why.idle": "Storage and leftovers for %@. Review the uninstall plan first, then check recoverable steps.",
    "apps.detail.callout.building.title": "Building the uninstall plan",
    "apps.evidence.bundlePath": "App location",
    "permissions.metric.tracked.title": "Total Permissions",
    "permissions.metric.tracked.detail": "Everything this version of Atlas checks.",
    "settings.callout.title": "Data stays on this Mac, and important changes keep a record.",
    "settings.trust.destructive.title": "System-changing actions",
    "settings.trust.destructive.subtitle": "A restore point is saved first, and every change is recorded.",
    "settings.retention.detail": "Recoverable results stay available for this long.",
    "settings.recoveryPanel.subtitle": "How long recoveries are kept, and which locations are not scanned.",
    "settings.exclusions.empty.detail": "No exclusions yet — Atlas scans the default coverage.",
    "fileorganizer.action.dryRun": "Preview",
    "fileorganizer.dryRun.success.one": "Preview complete: %1$@ file can be safely moved (%2$@)",
    "fileorganizer.dryRun.success.other": "Preview complete: %1$@ files can be safely moved (%2$@)",
    "fileorganizer.dryRun.error": "Preview failed: %@",
    "fileorganizer.error.stalePlan": "The file organizer plan is out of date. Please preview again.",
    "fileorganizer.evidence.empty.detail": "Select a file to see why it was classified this way and where it will move.",
    "fileorganizer.ruleeditor.subtitle": "Custom classification rules: by file type or name.",
    "application.error.executionUnavailable": "Atlas could not run this action right now: %@",
    "application.error.helperUnavailable": "Atlas could not complete this action because a required system component is unavailable: %@",
    "application.error.workerRejected": "This action was not handled (%@): %@",
    "infrastructure.execute.summary.clean.review.one": "1 review-only item was not handled this time.",
    "infrastructure.execute.summary.clean.review.other": "%d review-only items were not handled this time.",
    "infrastructure.restore.summary.state.one": "Restored 1 item in Atlas. No on-disk restore path was available, so no files were moved.",
    "infrastructure.restore.summary.state.other": "Restored %d items in Atlas. No on-disk restore path was available, so no files were moved.",
}

EN_GLOSSARY = """
"glossary.containers.term" = "Containers";
"glossary.containers.definition" = "System folders macOS gives each app to keep its data isolated. Names match system paths, so you can cross-check them.";
"glossary.groupcontainers.term" = "Group Containers";
"glossary.groupcontainers.definition" = "System folders where apps from the same developer share data.";
"glossary.savedstate.term" = "Saved State";
"glossary.savedstate.definition" = "System files an app uses to remember its last windows and positions.";
"""

ANCHOR = "glossary.restorepoint.definition"


def line_of(key: str) -> str:
    return '"%s" = ' % key


def apply(path: str, edits: dict, glossary_block: str) -> None:
    with open(path, encoding="utf-8") as f:
        src = f.read()

    for key in DELETES:
        pat = re.compile(r'^%s".*";\n' % re.escape(line_of(key)), re.M)
        hits = len(pat.findall(src))
        assert hits == 1, f"{path}: DELETE {key} matched {hits} times (expect 1)"
        src = pat.sub(lambda _m: "", src, count=1)

    for key, value in edits.items():
        pat = re.compile(r'^%s".*";$' % re.escape(line_of(key)), re.M)
        hits = len(pat.findall(src))
        assert hits == 1, f"{path}: EDIT {key} matched {hits} times (expect 1)"
        new_line = '"%s" = "%s";' % (key, value)
        src = pat.sub(lambda _m: new_line, src, count=1)

    anchor_pat = re.compile(r'^(%s".*";\n)' % re.escape(line_of(ANCHOR)), re.M)
    assert len(anchor_pat.findall(src)) == 1, f"{path}: anchor {ANCHOR} not unique"
    src = anchor_pat.sub(lambda m: m.group(1) + glossary_block.lstrip("\n"), src, count=1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print(f"OK {path}: -{len(DELETES)} keys, ~{len(edits)} values, +6 glossary keys")


if __name__ == "__main__":
    apply(STRINGS["zh"], ZH_EDITS, ZH_GLOSSARY)
    apply(STRINGS["en"], EN_EDITS, EN_GLOSSARY)
    print("DONE")
