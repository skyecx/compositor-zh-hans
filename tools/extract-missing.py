#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""扫描 Compositor 源码，找出语言包里还没有的新词条（以及可能已经失效的旧词条）。

上游更新版本后，跑一次本脚本就能拿到「本次需要补翻译的字符串」清单。

用法：
    git clone --depth 1 https://github.com/robbietilton/Compositor /tmp/Compositor
    python3 tools/extract-missing.py /tmp/Compositor

输出（都在仓库根目录，已加入 .gitignore）：
    missing.txt      —— 高置信度：来自 Text("…") / Label("…") 等明确的本地化调用点，
                        语言包里没有，**就是需要补翻译的词条**
    candidates.txt   —— 低置信度：其它字符串字面量，需要人工挑一遍
    stale.txt        —— 语言包里有、源码里找不到：可以删掉（留着也无害）

关于插值：源码里的 `Text("Expand by \\(n) px")` 对应语言包里的 key
`"Expand by %lld px"`。本脚本会自动把插值 pattern-match 到已有的 %@ / %lld
等占位符上，因此不会把这类已经翻译过的词条误报成缺失。
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "zh-Hans.lproj", "Localizable.strings")

ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def find_interps(s):
    """找出所有 \\(...) 插值的区间 [(start, end)]，支持任意层嵌套括号。"""
    spans, i = [], 0
    while True:
        j = s.find('\\(', i)
        if j < 0:
            break
        depth, k = 0, j + 1
        while k < len(s):
            if s[k] == '(':
                depth += 1
            elif s[k] == ')':
                depth -= 1
                if depth == 0:
                    break
            k += 1
        if k >= len(s):
            break
        spans.append((j, k + 1))
        i = k + 1
    return spans


def hint_of(literal):
    """把插值换成占位符，便于直接粘进 Localizable.strings 改成 key。"""
    out, last = [], 0
    for a, b in find_interps(literal):
        out.append(literal[last:a])
        out.append('%@')
        last = b
    out.append(literal[last:])
    return "".join(out)
PLACEHOLDER = r'%(?:\d+\$)?[-+ #0]*(?:\d+)?(?:\.\d+)?(?:hh|h|ll|l|q|L|z|j|t)?[@diouxXeEfgGaAcsp](?![A-Za-z0-9_])'
PH_RE = re.compile(PLACEHOLDER)
VERBATIM = re.compile(r'verbatim\s*:\s*"')

SKIP_DIRS = {".git", ".build", "DerivedData", "CompositorTests", "CompositorUITests", "Pods"}

# 明确的本地化调用点（SwiftUI 会把字面量当 LocalizedStringKey）
UI_CALL = re.compile(
    r'(?:^|[^\w.])(?:Text|Label|Button|Toggle|Picker|Menu|Link|TextField|SecureField'
    r'|Section|Stepper|DatePicker|GroupBox|CommandMenu|CommandGroup)\s*\(\s*"'
)
UI_MODIFIER = re.compile(
    r'\.(?:navigationTitle|navigationSubtitle|help|alert|confirmationDialog'
    r'|accessibilityLabel|accessibilityHint)\s*\(\s*"'
)

# 不是 UI 文案
NOT_UI = re.compile(
    r'^(CI[A-Z]\w*|NS[A-Z]\w*|CG[A-Z]\w*|UTType\w*|kCG\w*|AX\w+)$'
    r'|^[\W\d_]+$'
    r'|^[\w.-]+\.(swift|png|jpg|jpeg|json|plist|comp|xml|txt|strings)$'
    r'|^\w+\.\w+'
)
# 代码里的标识符（accessibilityIdentifier、UserDefaults key 等），不是给人看的文案
IDENTIFIER = re.compile(r'^[a-z][a-zA-Z0-9_]*$|^[a-z][a-zA-Z0-9]*\.[a-zA-Z0-9.]+$')
NOISE_LINE = re.compile(
    r'accessibilityIdentifier|#Preview|UserDefaults|Notification\.Name'
    r'|\.init\(|stringValue|bundleIdentifier|identifier:|imageName|systemName'
)


def load_keys():
    return [m.group(1) for m in (
        ENTRY.match(l.rstrip("\n")) for l in open(STRINGS, encoding="utf-8")
    ) if m]


def pattern_for(literal):
    parts, last = [], 0
    for a, b in find_interps(literal):
        # 字面量里的 % 在 format string 里会被转义成 %%，两种都接受
        parts.append(re.escape(literal[last:a]).replace('%', '(?:%|%%)'))
        parts.append(PLACEHOLDER)
        last = b
    parts.append(re.escape(literal[last:]))
    return re.compile("^" + "".join(parts) + "$")


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    return "\n".join(line.split("//", 1)[0] for line in text.split("\n"))


def scan(src_root):
    """返回 {literal: (位置, 是否高置信度)}"""
    found = {}
    for dirpath, dirnames, filenames in os.walk(src_root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if dirpath.endswith("Tests"):
            continue
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, src_root)
            try:
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for lineno, line in enumerate(strip_comments(text).split("\n"), 1):
                s = line.strip()
                if not s or VERBATIM.search(line):
                    continue
                # 去掉 accessibilityIdentifier("…") —— 那是给测试用的标识符，不是文案
                line = re.sub(
                    r'accessibilityIdentifier\s*\(\s*"(?:[^"\\]|\\.)*"\s*\)', ' ', line
                )
                # systemImage: "plus" / imageName: "x" 之类的资源名也不是文案
                line = re.sub(
                    r'(?:systemImage|imageName|systemName)\s*:\s*"(?:[^"\\]|\\.)*"', ' ', line
                )
                noisy = bool(NOISE_LINE.search(line))
                high = bool(UI_CALL.search(line) or UI_MODIFIER.search(line))
                for lit in LITERAL.findall(line):
                    lit = lit.replace('\\"', '"')
                    if len(lit.strip()) < 2 or not re.search(r'[A-Za-z]', lit):
                        continue
                    if NOT_UI.match(lit.strip()):
                        continue
                    if noisy and not high:
                        continue
                    if IDENTIFIER.match(lit) and not high:
                        continue
                    where = f"{rel}:{lineno}"
                    if lit not in found or (high and not found[lit][1]):
                        found[lit] = (where, high)
    return found


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src_root = sys.argv[1]
    if not os.path.isdir(src_root):
        print(f"❌ 不是目录：{src_root}", file=sys.stderr)
        return 1

    keys = load_keys()
    key_set = set(keys)
    found = scan(src_root)

    plain = {k for k in key_set if not PH_RE.search(k)}
    covered, missing_hi, missing_lo = set(), [], []

    for lit, (where, high) in sorted(found.items(), key=lambda kv: kv[1][0]):
        if lit in plain:
            covered.add(lit)
            continue
        if find_interps(lit):
            rx = pattern_for(lit)
            hit = next((k for k in keys if rx.match(k)), None)
            if hit:
                covered.add(hit)
                continue
        (missing_hi if high else missing_lo).append((lit, where))

    # 已被 missing_hi 的插值模式覆盖的 key，不算失效
    hi_patterns = [pattern_for(l) for l, _ in missing_hi if find_interps(l)]
    stale = [k for k in keys
             if k not in covered and not any(rx.match(k) for rx in hi_patterns)]

    def write(name, rows, hint=True):
        with open(os.path.join(ROOT, name), "w", encoding="utf-8") as fh:
            for lit, where in rows:
                k = hint_of(lit) if hint else lit
                fh.write(f'"{k}" = "";   // {where}\n')

    write("missing.txt", missing_hi)
    write("candidates.txt", missing_lo)
    write("stale.txt", [(k, "语言包") for k in stale], hint=False)

    print(f"源码中扫到字符串字面量：{len(found)} 条（其中高置信度 "
          f"{sum(1 for _, h in found.values() if h)} 条）")
    print(f"语言包已有：{len(keys)} 条")
    print(f"❗ 待翻译（高置信度 UI 文案）：{len(missing_hi)} 条  ->  missing.txt")
    print(f"❔ 待人工确认的候选：{len(missing_lo)} 条  ->  candidates.txt")
    print(f"🧹 疑似失效：{len(stale)} 条  ->  stale.txt")
    if missing_hi:
        print("\n待翻译清单：")
        for lit, where in missing_hi[:30]:
            print(f"  {lit}    ({where})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
