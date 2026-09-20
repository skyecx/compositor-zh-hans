#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 zh-Hans.lproj/Localizable.strings 生成 docs/术语对照表.md。

用法：
    python3 tools/gen-glossary.py

修改翻译后重新运行本脚本即可刷新对照表。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "zh-Hans.lproj", "Localizable.strings")
OUT = os.path.join(ROOT, "docs", "术语对照表.md")

# "key" = "value";
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
# /* ===== 分组名 ===== */  或  /* --- 分组名 --- */
SECTION = re.compile(r'^\s*/\*\s*[=\-]{3,}\s*(.+?)\s*[=\-]{3,}\s*\*/\s*$')


def unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\\\", "\\")


def parse(path):
    entries, section = [], None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = SECTION.match(line)
            if m:
                name = m.group(1).strip()
                # 去掉历史批次前缀，让对照表保持整洁
                name = re.sub(r'^第[一二三四五六七八九十]+轮补充：', '', name)
                section = name
                continue
            m = ENTRY.match(line.rstrip("\n"))
            if m:
                entries.append((section or "未分组", unescape(m.group(1)), unescape(m.group(2))))
    return entries


def main() -> int:
    if not os.path.exists(SRC):
        print(f"找不到 {SRC}", file=sys.stderr)
        return 1
    entries = parse(SRC)
    if not entries:
        print("未解析到任何词条，请检查 .strings 格式", file=sys.stderr)
        return 1

    dedup, seen = [], set()
    for sec, en, zh in entries:
        if en in seen:
            continue
        seen.add(en)
        dedup.append((sec, en, zh))

    out = [
        "# 术语对照表",
        "",
        f"本文件由 `tools/gen-glossary.py` 从 `zh-Hans.lproj/Localizable.strings` 自动生成，"
        f"共 **{len(dedup)}** 条。",
        "",
        "术语统一遵循 **Adobe Photoshop / Affinity Photo 简体中文版** 的用词习惯。",
        "",
        "> 修改翻译请编辑 `zh-Hans.lproj/Localizable.strings`，然后重新运行 `python3 tools/gen-glossary.py`。",
        "",
    ]
    current = object()
    for sec, en, zh in dedup:
        if sec != current:
            out += ["", f"## {sec}", "", "| 英文原文 | 简体中文 |", "|---|---|"]
            current = sec
        out.append("| `%s` | %s |" % (en.replace("|", "\\|"), zh.replace("|", "\\|")))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")

    print(f"✅ 已写入 {os.path.relpath(OUT, ROOT)}：{len(dedup)} 条 / {len(out)} 行")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
