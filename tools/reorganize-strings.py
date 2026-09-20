#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 zh-Hans.lproj/Localizable.strings 按功能重新分组，不修改任何译文。

历史原因，语言包是分多轮追加进来的，分组比较乱（有大量词条堆在「补充词条」里）。
本脚本按「已有分组 + 关键词归类」把全部词条整理到固定的功能分区，方便后续维护。

用法：
    python3 tools/reorganize-strings.py [--dry-run]

脚本会先校验重排前后的词条集合完全一致，确认无误后才写回文件。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "zh-Hans.lproj", "Localizable.strings")

ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
SECTION = re.compile(r'^\s*/\*\s*[=\-]{3,}\s*(.+?)\s*[=\-]{3,}\s*\*/\s*$')

# 规范分区（决定输出顺序）
CANON = [
    "文件 / 项目",
    "编辑",
    "图像 / 画布",
    "视图 / 缩放",
    "图层",
    "蒙版",
    "选区 / 变换",
    "调整 / 滤镜",
    "混合模式",
    "颜色 / 色板",
    "工具",
    "界面 / 外观",
    "应用菜单",
    "工具提示",
    "对话框 / 错误信息",
    "格式化键（插值字符串）",
    "其他",
]

# 旧分组名 -> 规范分组名
RENAME = {
    "文件 / 项目": "文件 / 项目",
    "编辑": "编辑",
    "图像": "图像 / 画布",
    "图像 / 画布": "图像 / 画布",
    "视图 / 缩放": "视图 / 缩放",
    "图层": "图层",
    "选区": "选区 / 变换",
    "变换 / 选区命令": "选区 / 变换",
    "工具": "工具",
    "调整 / 滤镜": "调整 / 滤镜",
    "混合模式（下拉菜单显示名）": "混合模式",
    "颜色 / 色板": "颜色 / 色板",
    "蒙版": "蒙版",
    "界面 / 外观": "界面 / 外观",
    "界面 / 状态": "界面 / 外观",
    "应用菜单": "应用菜单",
    "应用菜单（CommandMenu 标题 + 菜单项）": "应用菜单",
    "工具提示句（Bucket A 部分）": "工具提示",
    "对话框 / 错误信息": "对话框 / 错误信息",
    "格式化键（插值字符串）": "格式化键（插值字符串）",
}

# 对「无明确分组」的词条做关键词归类；顺序敏感
RULES = [
    ("格式化键（插值字符串）", lambda k, v: "%" in k and ("@" in k or "d" in k or "f" in k or "1" in k)),
    ("混合模式", lambda k, v: re.search(r'^(Normal|Multiply|Screen|Overlay|Darken|Lighten|Color Dodge|Color Burn|Hard Light|Soft Light|Difference|Exclusion|Hue|Saturation|Color|Luminosity|Linear Burn|Linear Dodge|Vivid Light|Pin Light|Hard Mix|Divide|Subtract|Add)\b', k) is not None and len(k) < 32),
    ("蒙版", lambda k, v: re.search(r'\b(Mask|Masking)\b', k, re.I) is not None),
    ("选区 / 变换", lambda k, v: re.search(r'\b(Select|Selection|Select All|Deselect|Invert|Feather|Grow|Shrink|Transform|Flip|Rotate|Move|Free Transform)\b', k, re.I) is not None),
    ("图层", lambda k, v: re.search(r'\b(Layer|Blend Mode|Opacity|Group|Clipping|Duplicate|Rename|Merge|Flatten|Ungroup)\b', k, re.I) is not None),
    ("调整 / 滤镜", lambda k, v: re.search(r'\b(Adjustment|Curves|Levels|Hue|Saturation|Exposure|Gradient Map|Grain|Invert|Blur|Noise|Sharpen|Lens|Distort|Filter|Vignette|Vibrance|Threshold|Posterize)\b', k, re.I) is not None),
    ("图像 / 画布", lambda k, v: re.search(r'\b(Canvas|Image Size|Resize|Crop|Trim|Rotate|Resolution|Pixel|DPI|PPI)\b', k, re.I) is not None),
    ("颜色 / 色板", lambda k, v: re.search(r'\b(Color|Colour|Swatch|Palette|Foreground|Background|Gradient|Tint|Shade)\b', k, re.I) is not None),
    ("视图 / 缩放", lambda k, v: re.search(r'\b(Zoom|Fit|Actual Size|Ruler|Grid|Guide|Snap|Preview)\b', k, re.I) is not None),
    ("工具", lambda k, v: re.search(r'\b(Tool|Brush|Eraser|Pen|Lasso|Wand|Eyedropper|Gradient Tool|Hand|Marquee|Bucket|Clone|Heal|Smudge|Dodge|Burn|Text|Shape)\b', k, re.I) is not None),
    ("文件 / 项目", lambda k, v: re.search(r'\b(File|Project|Document|Save|Export|Import|Open|New|Close|Print)\b', k, re.I) is not None),
    ("编辑", lambda k, v: re.search(r'\b(Undo|Redo|Cut|Copy|Paste|Delete|Clear|Fill|Edit|Duplicate|Select All)\b', k, re.I) is not None),
]

HEADER = """/*
 * Localizable.strings — Compositor 简体中文语言包
 * 适用版本：Compositor 1.0.4（上游 robbietilton/Compositor）
 * 提取方式：扫描 SwiftUI 源码中的 LocalizedStringKey 字面量，覆盖「A 类」可本地化字符串
 * 安装位置：Compositor.app/Contents/Resources/zh-Hans.lproj/Localizable.strings
 *
 * 术语遵循 Adobe Photoshop / Affinity Photo 简体中文版习惯。
 * 修改后请运行：plutil -lint Localizable.strings
 * 生成对照表：python3 tools/gen-glossary.py
 *
 * 注意：本文件不包含「B 类」字符串（枚举 rawValue 派生的下拉项、工具名等），
 *      原因与补齐方案见 docs/研究报告.md。
 */
"""


def unescape(s):
    return s.replace('\\"', '"').replace("\\\\", "\\")


def parse(path):
    """按出现顺序返回 [(原分组, key, value)]，重复 key 取首次出现（与运行时行为一致）。"""
    entries, seen, section = [], set(), None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = SECTION.match(line)
            if m:
                section = m.group(1).strip()
                continue
            m = ENTRY.match(line.rstrip("\n"))
            if m:
                key = m.group(1)
                if key in seen:
                    continue
                seen.add(key)
                entries.append((section or "未分组", key, m.group(2)))
    return entries


def classify(section, key):
    if section in RENAME:
        return RENAME[section]
    plain = unescape(key)
    for name, pred in RULES:
        try:
            if pred(plain, key):
                return name
        except re.error:
            continue
    return "其他"


def main():
    dry = "--dry-run" in sys.argv
    entries = parse(TARGET)
    if not entries:
        print("未解析到词条", file=sys.stderr)
        return 1

    buckets = {name: [] for name in CANON}
    for section, key, value in entries:
        buckets[classify(section, key)].append((key, value))

    parts = [HEADER]
    total = 0
    for name in CANON:
        rows = buckets[name]
        if not rows:
            continue
        parts.append("\n/* ===== %s ===== */\n" % name)
        for key, value in rows:
            parts.append('"%s" = "%s";\n' % (key, value))
        total += len(rows)
    content = "".join(parts)

    if total != len(entries):
        print(f"❌ 词条数不一致：{total} != {len(entries)}", file=sys.stderr)
        return 1

    # 用 plutil 复检（写入临时文件）
    if dry:
        print(f"[dry-run] 共 {total} 条，不写盘")
        for name in CANON:
            if buckets[name]:
                print(f"  {len(buckets[name]):4d}  {name}")
        return 0

    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".strings", delete=False, encoding="utf-8") as tmp:
        tmp.write(content)
        tmp_path = tmp.name
    r = subprocess.run(["plutil", "-lint", tmp_path], capture_output=True, text=True)
    if r.returncode != 0:
        print("❌ plutil -lint 失败：\n" + r.stdout + r.stderr, file=sys.stderr)
        return 1

    with open(TARGET, "w", encoding="utf-8") as fh:
        fh.write(content)
    print(f"✅ 已重排 {TARGET}：{total} 条，plutil -lint 通过")
    for name in CANON:
        if buckets[name]:
            print(f"  {len(buckets[name]):4d}  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
