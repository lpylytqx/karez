#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 pipeline 下各脚本里写死的 `D:\\坎儿井` 换成从 _root 解析。

机械替换很容易埋雷，所以规则收得很紧，并且**每改一个都做语法检查**：
  py_compile 通过才落盘，否则保持原样并报告。

规则：
  1. `ROOT = Path(r"D:\\坎儿井")`  → `from _root import ROOT`（并插入 sys.path）
  2. 其余 `"D:\\坎儿井\\xxx"` 字面量 → `ROOT / "xxx"`（斜杠统一成 /）
  已改过的脚本跳过（幂等）。
"""
from __future__ import annotations

import py_compile
import re
import sys
import tempfile
from pathlib import Path

PIPE = Path(__file__).resolve().parent

HEADER = (
    "import sys as _sys\n"
    "from pathlib import Path as _Path\n"
    "_sys.path.insert(0, str(_Path(__file__).resolve().parent))\n"
    "from _root import ROOT  # 路径唯一解析处，不再写死盘符\n"
)

ROOT_RE = re.compile(r'^ROOT\s*=\s*Path\(r?"D:\\\\坎儿井"\)\s*$', re.M)
LIT_RE = re.compile(r'r?"D:\\\\坎儿井((?:\\\\[^"]*)?)"')


def main() -> None:
    changed, kept, skipped = [], [], []
    for p in sorted(PIPE.glob("*.py")):
        if p.name == "_root.py":
            continue
        src = p.read_text(encoding="utf-8")
        if "from _root import" in src:
            skipped.append(p.name)
            continue
        if "坎儿井" not in src:
            skipped.append(p.name)
            continue

        out = src
        if ROOT_RE.search(out):
            out = ROOT_RE.sub("", out, count=1)
            # 放在 docstring 之后的第一处 import 前
            lines = out.splitlines(True)
            ins = 0
            for i, ln in enumerate(lines):
                if ln.startswith(("import ", "from ")):
                    ins = i
                    break
            lines.insert(ins, HEADER)
            out = "".join(lines)

        def _sub(m: re.Match) -> str:
            tail = (m.group(1) or "").strip("\\")
            return ('ROOT / "%s"' % tail.replace("\\", "/")) if tail else "ROOT"

        out = LIT_RE.sub(_sub, out)

        if out == src:
            kept.append(p.name)
            continue
        # 先语法检查，过了才落盘
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False,
                                             encoding="utf-8") as f:
                f.write(out)
                tmp = f.name
            py_compile.compile(tmp, doraise=True)
            p.write_text(out, encoding="utf-8")
            changed.append(p.name)
        except py_compile.PyCompileError as e:
            kept.append("%s（语法不过，未改）" % p.name)
            print("    ! %s: %s" % (p.name, str(e).splitlines()[-1][:90]))

    print("  已改 %d 个：" % len(changed))
    for n in changed:
        print("    " + n)
    print("  未改 %d 个（无写死路径或语法不过）" % len(kept))
    print("  跳过 %d 个（已改过）" % len(skipped))


if __name__ == "__main__":
    sys.exit(main())
